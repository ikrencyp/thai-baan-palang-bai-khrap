import AppKit
import XCTest
@testable import TBPK

final class CustomSoundLibraryTests: XCTestCase {
    private var workspace: URL!
    private var originalFolder: URL!

    override func setUpWithError() throws {
        workspace = FileManager.default.temporaryDirectory.appendingPathComponent("tbpk-sounds-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        originalFolder = CustomSoundLibrary.folder
        CustomSoundLibrary.folder = workspace.appendingPathComponent("library")
    }

    override func tearDownWithError() throws {
        CustomSoundLibrary.folder = originalFolder
        try? FileManager.default.removeItem(at: workspace)
    }

    private func makeWave(named name: String, seconds: Double) throws -> URL {
        let rate = 8000
        let samples = Int(Double(rate) * seconds)
        var data = Data()
        func put<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); put(UInt32(36 + samples)); data.append(contentsOf: Array("WAVEfmt ".utf8))
        put(UInt32(16)); put(UInt16(1)); put(UInt16(1)); put(UInt32(rate)); put(UInt32(rate)); put(UInt16(1)); put(UInt16(8))
        data.append(contentsOf: Array("data".utf8)); put(UInt32(samples))
        data.append(Data(repeating: 128, count: samples))
        let url = workspace.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    func testAValidFileIsCopiedIntoTheLibraryAndListed() throws {
        let source = try makeWave(named: "Door Bell.wav", seconds: 1)
        let sound = try CustomSoundLibrary.add(source)
        XCTAssertTrue(sound.isCustom)
        XCTAssertEqual(sound.displayName, "Door Bell")
        XCTAssertEqual(CustomSoundLibrary.sounds, [sound])
        XCTAssertTrue(FileManager.default.fileExists(atPath: CustomSoundLibrary.folder.appendingPathComponent("Door Bell.wav").path))
        XCTAssertGreaterThan(sound.duration, 0.9)
    }

    func testTheOriginalCanBeDeletedAfterTheCopy() throws {
        let source = try makeWave(named: "keep.wav", seconds: 1)
        _ = try CustomSoundLibrary.add(source)
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(CustomSoundLibrary.sounds.count, 1)
    }

    func testAnUnsupportedTypeIsRefusedWithoutCopying() throws {
        let text = workspace.appendingPathComponent("notes.txt")
        try "hi".write(to: text, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try CustomSoundLibrary.add(text)) { XCTAssertEqual($0 as? CustomSoundError, .unsupportedType("txt")) }
        XCTAssertTrue(CustomSoundLibrary.sounds.isEmpty)
    }

    func testAFileThatIsNotAudioIsRefused() throws {
        let fake = workspace.appendingPathComponent("fake.wav")
        try "not audio".write(to: fake, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try CustomSoundLibrary.add(fake)) { XCTAssertEqual($0 as? CustomSoundError, .unreadable) }
    }

    func testASoundLongerThanTheLimitIsRefused() throws {
        let long = try makeWave(named: "long.wav", seconds: 31)
        XCTAssertThrowsError(try CustomSoundLibrary.add(long)) { XCTAssertEqual($0 as? CustomSoundError, .tooLong(31)) }
    }

    func testACustomSoundCanBeStoredAndIsFoundAgain() throws {
        let sound = try CustomSoundLibrary.add(try makeWave(named: "mine.wav", seconds: 1))
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: AlertSound.storageKey)
        defer { saved.map { defaults.set($0, forKey: AlertSound.storageKey) } ?? defaults.removeObject(forKey: AlertSound.storageKey) }
        sound.store()
        XCTAssertEqual(AlertSound.stored, sound)
        XCTAssertTrue(AlertSound.available.contains(sound))
    }

    func testRemovingTheLibraryFallsBackToTheSystemAlert() throws {
        let sound = try CustomSoundLibrary.add(try makeWave(named: "gone.wav", seconds: 1))
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: AlertSound.storageKey)
        defer { saved.map { defaults.set($0, forKey: AlertSound.storageKey) } ?? defaults.removeObject(forKey: AlertSound.storageKey) }
        sound.store()
        CustomSoundLibrary.removeAll()
        XCTAssertTrue(CustomSoundLibrary.sounds.isEmpty)
        XCTAssertEqual(AlertSound.stored, .systemAlert)
    }

    func testOneSoundCanBeRemovedAndTheOthersStay() throws {
        let keep = try CustomSoundLibrary.add(try makeWave(named: "keep.wav", seconds: 1))
        let drop = try CustomSoundLibrary.add(try makeWave(named: "drop.wav", seconds: 1))
        AlertBeepCount.store(.three, for: drop)
        defer { AlertBeepCount.forget(drop); AlertBeepCount.forget(keep) }
        CustomSoundLibrary.remove(drop)
        XCTAssertEqual(CustomSoundLibrary.sounds, [keep])
        XCTAssertEqual(AlertBeepCount.stored(for: drop), .one)
    }

    func testAddingTheSameFileAgainKeepsOneCopy() throws {
        let source = try makeWave(named: "again.wav", seconds: 1)
        _ = try CustomSoundLibrary.add(source)
        _ = try CustomSoundLibrary.add(source)
        XCTAssertEqual(CustomSoundLibrary.sounds.count, 1)
    }

    func testTheDefaultFolderIsInsideApplicationSupport() {
        XCTAssertTrue(CustomSoundLibrary.defaultFolder.path.hasSuffix("Application Support/Thai Baan Palang Bai Khrap/Sounds"))
    }
}
