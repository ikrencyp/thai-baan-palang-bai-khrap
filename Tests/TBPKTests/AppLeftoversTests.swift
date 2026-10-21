import XCTest
@testable import TBPK

final class AppLeftoversTests: XCTestCase {
    private var workspace: URL!
    private var temporary: URL!
    private var downloads: URL!
    private var log: URL!
    private let now = Date()
    private let uuid = "1A5D81AC-6BBC-4D5A-8DC3-1162B9C3A9F1"

    override func setUpWithError() throws {
        workspace = FileManager.default.temporaryDirectory.appendingPathComponent("leftovers-test-\(UUID().uuidString)")
        temporary = workspace.appendingPathComponent("tmp")
        downloads = workspace.appendingPathComponent("Update")
        log = workspace.appendingPathComponent("update.log")
        for folder in [temporary!, downloads!] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: workspace) }

    @discardableResult
    private func make(_ name: String, in folder: URL, age: TimeInterval, folderEntry: Bool = true) throws -> URL {
        let url = folder.appendingPathComponent(name)
        if folderEntry {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } else {
            try "x".write(to: url, atomically: true, encoding: .utf8)
        }
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-age)], ofItemAtPath: url.path)
        return url
    }

    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    private func sweep(keeping: URL? = nil) -> Int {
        AppLeftovers.sweep(temporary: temporary, downloads: downloads, keeping: keeping, log: log, now: now)
    }

    func testAnOldUpdateCloneInTheTemporaryFolderIsRemoved() throws {
        let clone = try make("tbpk-update-\(uuid)", in: temporary, age: AppLeftovers.staleAfter + 1)
        XCTAssertEqual(sweep(), 1)
        XCTAssertFalse(exists(clone))
    }

    func testAYoungCloneIsLeftAloneBecauseACheckMayBeUsingIt() throws {
        let clone = try make("tbpk-update-\(uuid)", in: temporary, age: 30)
        XCTAssertEqual(sweep(), 0)
        XCTAssertTrue(exists(clone))
    }

    func testOnlyNamesTheAppMakesAreEverRemoved() throws {
        let others = [
            try make("tbpk-update-notauuid", in: temporary, age: 99_999),
            try make("tbpk-update-\(uuid)-extra", in: temporary, age: 99_999),
            try make("other-\(uuid)", in: temporary, age: 99_999),
            try make("com.apple.something", in: temporary, age: 99_999),
        ]
        XCTAssertEqual(sweep(), 0)
        XCTAssertTrue(others.allSatisfy(exists))
    }

    func testAnUnfinishedDownloadIsRemovedButTheRememberedOneIsKept() throws {
        let orphan = try make("tbpk-update-\(uuid)", in: downloads, age: AppLeftovers.staleAfter + 1)
        let kept = try make("tbpk-update-2FE06DA9-471F-453E-AFEC-AA3B7F917A9B", in: downloads, age: 99_999)
        XCTAssertEqual(sweep(keeping: kept), 1)
        XCTAssertFalse(exists(orphan))
        XCTAssertTrue(exists(kept), "a finished download waits however long the person takes to restart")
    }

    func testAYoungUnfinishedDownloadIsLeftAlone() throws {
        let running = try make("tbpk-update-\(uuid)", in: downloads, age: 20)
        XCTAssertEqual(sweep(), 0)
        XCTAssertTrue(exists(running))
    }

    func testAMissingFolderIsNotAnError() throws {
        try FileManager.default.removeItem(at: downloads)
        XCTAssertEqual(sweep(), 0)
    }

    func testALongLogKeepsOnlyItsNewestWholeLines() throws {
        let lines = (0..<20_000).map { "== line \($0) of the update log" }
        try lines.joined(separator: "\n").appending("\n").write(to: log, atomically: true, encoding: .utf8)
        XCTAssertGreaterThan(try Data(contentsOf: log).count, AppLeftovers.logLimit)
        _ = sweep()
        let kept = try String(contentsOf: log, encoding: .utf8)
        XCTAssertLessThanOrEqual(kept.utf8.count, AppLeftovers.logKeep)
        XCTAssertTrue(kept.hasPrefix("== line "), "the cut falls on a line boundary")
        XCTAssertTrue(kept.hasSuffix("== line 19999 of the update log\n"))
    }

    func testAShortLogIsNotTouched() throws {
        try "== 1 install\n".write(to: log, atomically: true, encoding: .utf8)
        _ = sweep()
        XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "== 1 install\n")
    }
}
