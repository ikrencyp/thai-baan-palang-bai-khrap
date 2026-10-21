import AppKit
import XCTest
@testable import TBPK

@MainActor
final class StayOpenMenuTests: XCTestCase {
    private let target = SoundPickTarget()
    private var saved: [String: Any] = [:]

    private var alertKeys: [String] { UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix("alert") } }

    override func setUp() {
        saved = UserDefaults.standard.dictionaryRepresentation().filter { $0.key.hasPrefix("alert") }
        alertKeys.forEach(UserDefaults.standard.removeObject(forKey:))
    }

    override func tearDown() {
        alertKeys.forEach(UserDefaults.standard.removeObject(forKey:))
        saved.forEach { UserDefaults.standard.set($0.value, forKey: $0.key) }
    }

    private func soundMenu() throws -> NSMenu { try XCTUnwrap(SoundMenu.item(target: target).submenu) }

    private func rows(in menu: NSMenu) -> [(item: NSMenuItem, row: StayOpenRow)] {
        menu.items.compactMap { item in (item.view as? StayOpenRow).map { (item, $0) } }
    }

    private func submenu(_ menu: NSMenu, _ title: String) throws -> NSMenu {
        try XCTUnwrap(menu.items.first { $0.title == title }?.submenu)
    }

    func testEverySoundChoiceIsARowThatLeavesTheMenuOpen() throws {
        let saved = CustomSoundLibrary.folder
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tbpk-own-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("x.wav"))
        CustomSoundLibrary.folder = folder
        defer { CustomSoundLibrary.folder = saved; try? FileManager.default.removeItem(at: folder) }
        let menu = try soundMenu()
        let own = rows(in: menu)
        XCTAssertEqual(own.count, 1, "the one own sound")
        XCTAssertTrue(own.allSatisfy { $0.item.representedObject is String })
        let mac = rows(in: try submenu(menu, "Mac sounds"))
        XCTAssertTrue(mac.contains { ($0.item.representedObject as? String) == AlertSound.systemAlertName })
        let counts = rows(in: try submenu(menu, "Play how many times"))
        XCTAssertEqual(counts.count, AlertBeepCount.allCases.count + 1, "every count and the same-for-all switch")
    }

    func testTheRowsKeepTheirActionSoTheKeyboardStillWorks() throws {
        for (item, _) in rows(in: try soundMenu()) {
            XCTAssertNotNil(item.action)
            XCTAssertTrue(item.target === target)
        }
    }

    func testPressingARowPicksThatSoundAndMovesTheTickWithoutRebuildingTheMenu() throws {
        let mac = try submenu(try soundMenu(), "Mac sounds")
        let all = rows(in: mac)
        let first = try XCTUnwrap(all.first)
        let other = try XCTUnwrap(all.last { $0.item !== first.item })
        other.row.performPick()
        XCTAssertEqual(AlertSound.stored.name, other.item.representedObject as? String)
        XCTAssertTrue(other.row.isChosen)
        XCTAssertEqual(other.item.state, .on)
        first.row.performPick()
        XCTAssertEqual(AlertSound.stored.name, first.item.representedObject as? String)
        XCTAssertTrue(first.row.isChosen)
        XCTAssertFalse(other.row.isChosen, "the old tick is gone")
        XCTAssertEqual(other.item.state, .off)
        XCTAssertEqual(target.picked.count, 2)
    }

    func testPickingASoundUpdatesTheLinesThatNameIt() throws {
        let menu = try soundMenu()
        let counts = try submenu(menu, "Play how many times")
        let sound = try XCTUnwrap(rows(in: try submenu(menu, "Mac sounds")).first)
        sound.row.performPick()
        XCTAssertEqual(counts.items.first?.title, "For \(AlertSound.stored.displayName)")
    }

    func testPressingACountChangesItInPlaceAndTheSoundRowShowsIt() throws {
        let menu = try soundMenu()
        let sound = try XCTUnwrap(rows(in: try submenu(menu, "Mac sounds")).first)
        sound.row.performPick()
        let counts = rows(in: try submenu(menu, "Play how many times")).filter { $0.item.representedObject is Int }
        let three = try XCTUnwrap(counts.first { ($0.item.representedObject as? Int) == AlertBeepCount.three.rawValue })
        three.row.performPick()
        XCTAssertTrue(three.row.isChosen)
        XCTAssertEqual(counts.filter { $0.row.isChosen }.count, 1)
        XCTAssertEqual(sound.row.currentDetail, AlertBeepCount.three.label, "the count beside the sound follows")
    }

    func testTheSameForEverySoundSwitchTogglesInPlace() throws {
        let counts = rows(in: try submenu(try soundMenu(), "Play how many times"))
        let shared = try XCTUnwrap(counts.first { !($0.item.representedObject is Int) })
        XCTAssertFalse(shared.row.isChosen)
        shared.row.performPick()
        XCTAssertTrue(shared.row.isChosen)
        XCTAssertTrue(AlertBeepCount.isShared())
        shared.row.performPick()
        XCTAssertFalse(shared.row.isChosen)
    }

    func testARowDrawsItsTickTitleAndCountWithoutCrashing() throws {
        let sound = try XCTUnwrap(rows(in: try submenu(try soundMenu(), "Mac sounds")).first)
        sound.row.performPick()
        let size = sound.row.bounds.size
        let image = NSImage(size: size)
        image.lockFocus()
        sound.row.draw(sound.row.bounds)
        image.unlockFocus()
        XCTAssertEqual(size.width, StayOpenRow.width)
        XCTAssertEqual(sound.row.currentTitle, AlertSound.stored.displayName)
    }
}
