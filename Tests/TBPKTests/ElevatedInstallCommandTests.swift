import XCTest
@testable import TBPK

final class ElevatedInstallCommandTests: XCTestCase {
    private let change = "/usr/bin/pmset -a disablesleep 1"

    private func command(user: String = "jane", change: String? = nil) throws -> String {
        try XCTUnwrap(ElevatedInstallCommand.assemble(user: user, change: change))
    }

    func testAssembledCommandIsValidShell() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-n", "-c", try command(change: change)]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testRootWritesTheRuleItselfAndNoFileOfTheUserIsCopiedIn() throws {
        let text = try command()
        XCTAssertTrue(text.contains("printf '%s\\n' 'jane ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1,"))
        XCTAssertFalse(text.contains("/usr/bin/install"), "no copy of a file the user could have swapped")
        XCTAssertFalse(text.contains("/tmp"))
        XCTAssertFalse(text.contains(NSTemporaryDirectory()))
    }

    func testTheDraftIsCheckedBeforeItIsMovedIntoPlaceAndRemovedOnFailure() throws {
        let text = try command()
        let draft = "'/etc/sudoers.d/tbpk-jane.new'"
        let check = try XCTUnwrap(text.range(of: "/usr/sbin/visudo -c -f \(draft)"))
        let move = try XCTUnwrap(text.range(of: "/bin/mv -f \(draft) '/etc/sudoers.d/tbpk-jane'"))
        XCTAssertLessThan(check.lowerBound, move.lowerBound)
        XCTAssertTrue(text.contains("/bin/chmod 0440 \(draft)"))
        XCTAssertTrue(text.contains("/usr/sbin/chown root:wheel \(draft)"))
        XCTAssertTrue(text.contains("|| { /bin/rm -f \(draft); exit 5; }"))
    }

    func testTheMainSudoersFileIsNeverEdited() throws {
        let text = try command()
        XCTAssertFalse(text.contains(">> /etc/sudoers"))
        XCTAssertFalse(text.contains("cp -p /etc/sudoers"))
        XCTAssertTrue(text.contains("does not read /etc/sudoers.d"), "it refuses with a message instead")
    }

    func testTheRequestedChangeComesAfterTheRuleAndWholeConfigIsCheckedLast() throws {
        let text = try command(change: change)
        XCTAssertTrue(text.contains(change))
        XCTAssertLessThan(try XCTUnwrap(text.range(of: "/bin/mv -f")).lowerBound, try XCTUnwrap(text.range(of: change, options: .backwards)).lowerBound)
        XCTAssertTrue(text.hasSuffix("/usr/sbin/visudo -c"))
    }

    func testAnAccountNameThatIsNotPlainIsRefused() {
        for user in ["", "jane doe", "jane;rm", "a'b", "j\"x", "jane\nALL", "$(id)", "jané", "../x"] {
            XCTAssertNil(ElevatedInstallCommand.assemble(user: user, change: nil), user)
        }
        for user in ["jane", "j.doe", "j_doe-2", "A1"] {
            XCTAssertNotNil(ElevatedInstallCommand.assemble(user: user, change: nil), user)
        }
    }

    func testTheRuleGrantsExactlyTheFourCommands() {
        let line = ElevatedInstallCommand.ruleLine(for: "jane")
        XCTAssertEqual(line, "jane ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -b lowpowermode 1, /usr/bin/pmset -b lowpowermode 0\n")
    }

    // Runs the real command text with /etc pointed at a scratch folder and the root-only steps stubbed out.
    private func runInSandbox(include: String?, user: String = "jane") throws -> (status: Int32, folder: URL, rule: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tbpk-sandbox-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("sudoers.d")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let main = root.appendingPathComponent("sudoers")
        try ("root ALL=(ALL) ALL\n" + (include.map { $0 + "\n" } ?? "")).write(to: main, atomically: true, encoding: .utf8)
        var text = try command(user: user)
        // the file operand of grep is the only " /etc/sudoers " with a space on both sides; the pattern keeps its own text
        text = text.replacingOccurrences(of: "/etc/sudoers.d", with: dir.path)
            .replacingOccurrences(of: " /etc/sudoers ", with: " \(main.path) ")
            .replacingOccurrences(of: "/usr/sbin/chown root:wheel", with: "/usr/bin/true")
        XCTAssertTrue(text.hasSuffix(" && /usr/sbin/visudo -c"))
        text = String(text.dropLast(" && /usr/sbin/visudo -c".count))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", text]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return (process.terminationStatus, dir, dir.appendingPathComponent("tbpk-" + user.replacingOccurrences(of: ".", with: "_")))
    }

    func testTheCommandInstallsTheRuleWithModeAndLeavesNoDraft() throws {
        let run = try runInSandbox(include: "@includedir /etc/sudoers.d")
        defer { try? FileManager.default.removeItem(at: run.folder.deletingLastPathComponent()) }
        XCTAssertEqual(run.status, 0)
        XCTAssertEqual(try String(contentsOf: run.rule, encoding: .utf8), ElevatedInstallCommand.ruleLine(for: "jane"))
        let mode = try FileManager.default.attributesOfItem(atPath: run.rule.path)[.posixPermissions] as? Int
        XCTAssertEqual(mode, 0o440)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: run.folder.path), ["tbpk-jane"], "the .new draft is gone")
    }

    func testWithoutTheIncludeLineNothingIsWrittenAndTheMainFileIsUntouched() throws {
        let original = "root ALL=(ALL) ALL\n"
        let run = try runInSandbox(include: nil)
        defer { try? FileManager.default.removeItem(at: run.folder.deletingLastPathComponent()) }
        XCTAssertEqual(run.status, 4)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: run.folder.path), [])
        XCTAssertEqual(try String(contentsOf: run.folder.deletingLastPathComponent().appendingPathComponent("sudoers"), encoding: .utf8), original)
    }

    func testEveryWayAMacWritesTheIncludeLineIsAccepted() throws {
        for line in ["@includedir /etc/sudoers.d", "@includedir /private/etc/sudoers.d", "#includedir /etc/sudoers.d",
                     "#includedir /private/etc/sudoers.d", "@includedir   /private/etc/sudoers.d/"] {
            let run = try runInSandbox(include: line)
            defer { try? FileManager.default.removeItem(at: run.folder.deletingLastPathComponent()) }
            XCTAssertEqual(run.status, 0, line)
            XCTAssertTrue(FileManager.default.fileExists(atPath: run.rule.path), line)
        }
    }

    func testALineThatOnlyLooksLikeTheIncludeIsRefused() throws {
        for line in ["# @includedir /etc/sudoers.d", "@includedir /etc/sudoers.d.bak", "@includedir /usr/etc/sudoers.d",
                     "@include /etc/sudoers.d", "Defaults @includedir /etc/sudoers.d"] {
            let run = try runInSandbox(include: line)
            defer { try? FileManager.default.removeItem(at: run.folder.deletingLastPathComponent()) }
            XCTAssertEqual(run.status, 4, line)
        }
    }

    func testADottedAccountNameGetsADotFreeFileNameAndKeepsItsRealNameInTheRule() throws {
        XCTAssertEqual(ElevatedInstallCommand.passwordlessRulePath(for: "first.last"), "/etc/sudoers.d/tbpk-first_last")
        let run = try runInSandbox(include: "@includedir /etc/sudoers.d", user: "first.last")
        defer { try? FileManager.default.removeItem(at: run.folder.deletingLastPathComponent()) }
        XCTAssertEqual(run.status, 0)
        XCTAssertEqual(run.rule.lastPathComponent, "tbpk-first_last", "sudo would skip a name with a dot")
        XCTAssertEqual(try String(contentsOf: run.rule, encoding: .utf8), ElevatedInstallCommand.ruleLine(for: "first.last"))
    }

    func testTheSudoersKeywordAndOptionLookingNamesAreRefused() {
        for user in ["ALL", "-x", "--help", "-"] { XCTAssertNil(ElevatedInstallCommand.assemble(user: user, change: nil), user) }
        XCTAssertNotNil(ElevatedInstallCommand.assemble(user: "all", change: nil), "lower case is an ordinary name")
    }
}
