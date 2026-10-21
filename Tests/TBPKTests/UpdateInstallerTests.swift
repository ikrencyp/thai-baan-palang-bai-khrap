import XCTest
@testable import TBPK

final class UpdateInstallerTests: XCTestCase {
    private var workspace: URL!

    override func setUpWithError() throws {
        workspace = FileManager.default.temporaryDirectory.appendingPathComponent("tbpk-installer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: workspace) }

    private func script(_ name: String, _ body: String) throws -> URL {
        let url = workspace.appendingPathComponent(name)
        try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    // Runs the real waiter against stubs: a process that already quit, a fake install.sh and a fake launcher.
    private func runWaiter(processName: String, launcherBody: String) throws -> (log: String, launches: Int) {
        let quit = Process()
        quit.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try quit.run(); quit.waitUntilExit()
        let install = try script("install.sh", "echo installing")
        let launcher = try script("launcher.sh", "echo x >>\"\(workspace.path)/launches\"\n\(launcherBody)")
        let checkout = workspace.appendingPathComponent("checkout")
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
        let log = workspace.appendingPathComponent("update.log")
        try UpdateInstaller.start(arguments: [String(quit.processIdentifier), install.path, checkout.path, log.path,
                                              launcher.path, processName, "/Applications/Fake.app", "0.05", "2"])
        UpdateInstaller.waitable?.waitUntilExit()
        let launches = (try? String(contentsOf: workspace.appendingPathComponent("launches"), encoding: .utf8))?
            .split(separator: "\n").count ?? 0
        XCTAssertFalse(FileManager.default.fileExists(atPath: checkout.path), "the downloaded copy is deleted")
        return ((try? String(contentsOf: log, encoding: .utf8)) ?? "", launches)
    }

    func testTheAppIsOpenedAgainWhenInstallDidNotLeaveItRunning() throws {
        let result = try runWaiter(processName: "tbpk-no-such-process-\(UUID().uuidString)", launcherBody: "")
        XCTAssertTrue(result.log.contains("installing"))
        XCTAssertEqual(result.launches, 5)
    }

    func testNothingIsOpenedAgainWhenTheAppIsAlreadyRunning() throws {
        let running = Process()
        running.executableURL = URL(fileURLWithPath: "/bin/sleep")
        running.arguments = ["30"]
        try running.run()
        defer { running.terminate() }
        let result = try runWaiter(processName: "sleep", launcherBody: "")
        XCTAssertTrue(result.log.contains("installing"))
        XCTAssertEqual(result.launches, 0)
    }

    func testAnAppThatDoesNotQuitIsNotReplacedAndTheLogSaysSo() throws {
        let alive = Process()
        alive.executableURL = URL(fileURLWithPath: "/bin/sleep")
        alive.arguments = ["30"]
        try alive.run()
        defer { alive.terminate() }
        let install = try script("install.sh", "echo installing >>\"\(workspace.path)/installed\"")
        let checkout = workspace.appendingPathComponent("checkout")
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
        let log = workspace.appendingPathComponent("update.log")
        try UpdateInstaller.start(arguments: [String(alive.processIdentifier), install.path, checkout.path, log.path,
                                              "/usr/bin/true", "x", "/Applications/Fake.app", "0.05", "2"])
        UpdateInstaller.waitable?.waitUntilExit()
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("installed").path))
        XCTAssertTrue(try String(contentsOf: log, encoding: .utf8).contains("did not quit"))
    }

    func testTheLogLivesInsideTheAppDataFolderSoUninstallRemovesIt() {
        XCTAssertTrue(UpdateInstaller.logFile.path.hasSuffix("Application Support/Thai Baan Palang Bai Khrap/update.log"))
    }
}
