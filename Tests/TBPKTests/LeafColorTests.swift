import AppKit
import XCTest
@testable import TBPK

@MainActor
final class LeafColorTests: XCTestCase {
    func testHexInParsesWithOrWithoutHashAndInShortForm() {
        XCTAssertEqual(LeafColor(hex: "#FF8800")?.rgb, 0xFF8800)
        XCTAssertEqual(LeafColor(hex: " ff8800 ")?.rgb, 0xFF8800)
        XCTAssertEqual(LeafColor(hex: "#f80")?.rgb, 0xFF8800)
    }

    func testNonsenseIsNotAColour() {
        for text in ["", "#", "red", "#12345", "#1234567", "#GG0000", "##FF0000"] {
            XCTAssertNil(LeafColor(hex: text), text)
        }
    }

    func testHexOutIsUpperCaseAndRoundTrips() {
        XCTAssertEqual(LeafColor(rgb: 0x0A0B0C).hex, "#0A0B0C")
        XCTAssertEqual(LeafColor(hex: LeafColor(rgb: 0x123456).hex)?.rgb, 0x123456)
    }

    func testNamedChoicesHaveNamesAndCustomOnesShowTheirCode() {
        XCTAssertEqual(LeafColor.standard.name, "Green")
        XCTAssertFalse(LeafColor.standard.isCustom)
        XCTAssertEqual(LeafColor.batteryStandard.name, "Red")
        XCTAssertEqual(LeafColor(rgb: 0x123456).name, "#123456")
        XCTAssertTrue(LeafColor(rgb: 0x123456).isCustom)
        XCTAssertEqual(Set(LeafColor.choices.map(\.color.rgb)).count, LeafColor.choices.count)
    }

    func testEachSlotStoresItsOwnColourAndAnythingBrokenFallsBack() {
        let defaults = scratchDefaults("tbp-leafcolor")
        XCTAssertEqual(LeafColor.stored(.charger, in: defaults), .standard)
        XCTAssertEqual(LeafColor.stored(.battery, in: defaults), .batteryStandard)
        LeafColor(rgb: 0xB06CFF).store(.charger, in: defaults)
        LeafColor(rgb: 0x3FC1FF).store(.battery, in: defaults)
        XCTAssertEqual(LeafColor.stored(.charger, in: defaults).rgb, 0xB06CFF)
        XCTAssertEqual(LeafColor.stored(.battery, in: defaults).rgb, 0x3FC1FF)
        defaults.set("banana", forKey: LeafColor.Slot.charger.storageKey)
        defaults.set("banana", forKey: LeafColor.Slot.battery.storageKey)
        XCTAssertEqual(LeafColor.stored(.charger, in: defaults), .standard)
        XCTAssertEqual(LeafColor.stored(.battery, in: defaults), .batteryStandard)
    }

    func testEachSlotHasItsOwnMenuAndTheyTickTheStoredChoice() throws {
        let parent = LeafColorMenu.item(target: StubMenuTarget(), charger: LeafColor(rgb: 0xB06CFF), battery: .batteryStandard)
        XCTAssertEqual(parent.title, "Leaf colour")
        let slots = try XCTUnwrap(parent.submenu)
        XCTAssertEqual(slots.items.map(\.title).prefix(2), ["On the charger", "On battery"])

        let charger = try XCTUnwrap(slots.items.first { $0.title == "On the charger" }?.submenu)
        XCTAssertEqual(charger.items.filter { $0.state == .on }.map(\.title), ["Purple"])
        XCTAssertTrue(charger.items.contains { $0.title == "Custom colour..." })

        let battery = try XCTUnwrap(slots.items.first { $0.title == "On battery" }?.submenu)
        XCTAssertEqual(battery.items.filter { $0.state == .on }.map(\.title), ["Red"])

        let custom = try XCTUnwrap(LeafColorMenu.item(target: StubMenuTarget(), charger: .standard,
                                                      battery: LeafColor(rgb: 0x123456)).submenu)
        let batteryCustom = try XCTUnwrap(custom.items.first { $0.title == "On battery" }?.submenu)
        XCTAssertEqual(batteryCustom.items.filter { $0.state == .on }.map(\.title), ["Custom #123456..."])
    }

    func testAColourRowCarriesItsSlotAndColour() throws {
        let parent = LeafColorMenu.item(target: StubMenuTarget(), charger: .standard, battery: .batteryStandard)
        let charger = try XCTUnwrap(parent.submenu?.items.first { $0.title == "On the charger" }?.submenu)
        let row = try XCTUnwrap(charger.items.first { $0.title == "Purple" })
        XCTAssertEqual(row.representedObject as? LeafColor.Pick,
                       LeafColor.Pick(slot: .charger, color: LeafColor(rgb: 0xB06CFF)))
        let custom = try XCTUnwrap(charger.items.first { $0.title == "Custom colour..." })
        XCTAssertEqual(custom.representedObject as? LeafColor.Slot, .charger)
    }

    func testTheLeafTakesTheChosenColour() throws {
        let pink = LeafColor(rgb: 0xFF5FA8)
        let image = LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: pink.nsColor)
        let rep = NSBitmapImageRep(cgImage: try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil)))
        var pinkPixels = 0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.alphaComponent > 0.9 else { continue }
                if c.redComponent > 0.9, abs(c.greenComponent - 0.51) < 0.1, abs(c.blueComponent - 0.71) < 0.1 { pinkPixels += 1 }
            }
        }
        XCTAssertGreaterThan(pinkPixels, 30)
    }

    // On battery the leaf burns like it does on the charger: the gold aura with its lightning, even when it does not beat.
    func testTheAuraAndLightningShowOnBatteryToo() throws {
        func boltPixels(alerting: Bool) throws -> Int {
            var image: NSImage?
            let animator = StatusIconAnimator { image = $0 }
            animator.retarget(IconTarget(awake: true, busy: false, failed: false, alerting: alerting, beating: false), animated: false)
            let rep = NSBitmapImageRep(cgImage: try XCTUnwrap(image?.cgImage(forProposedRect: nil, context: nil, hints: nil)))
            var count = 0
            for x in 0..<rep.pixelsWide {
                for y in 0..<rep.pixelsHigh {
                    guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.alphaComponent > 0.5 else { continue }
                    if c.blueComponent > 0.9, c.redComponent < 0.8 { count += 1 }
                }
            }
            return count
        }
        XCTAssertGreaterThan(try boltPixels(alerting: true), 0, "lightning around the leaf on battery")
        XCTAssertEqual(Double(try boltPixels(alerting: true)), Double(try boltPixels(alerting: false)), accuracy: 4, "same look on the charger")
    }

    func testSettingsHoldsTheLeafColourMenu() throws {
        let settings = try XCTUnwrap(SettingsMenu.item(target: StubMenuTarget()).submenu)
        XCTAssertTrue(settings.items.contains { $0.title == "Leaf colour" })
    }

    // The leaf takes the colour of the power state it is in: the charger colour on the charger, the battery colour
    // while the Mac runs on battery or an alert is showing.
    func testTheIconTakesTheColourOfThePowerStateItIsIn() throws {
        let charger = LeafColor(rgb: 0x2EDB6E)
        let battery = LeafColor(rgb: 0x4C7DFF)

        func drawn(_ alerting: Bool) throws -> (green: Int, blue: Int) {
            var image: NSImage?
            let animator = StatusIconAnimator { image = $0 }
            animator.retarget(IconTarget(awake: true, busy: false, failed: false, alerting: alerting, beating: false,
                                         leaf: charger, batteryLeaf: battery), animated: false)
            let rep = NSBitmapImageRep(cgImage: try XCTUnwrap(image?.cgImage(forProposedRect: nil, context: nil, hints: nil)))
            var green = 0, blue = 0
            for x in 0..<rep.pixelsWide {
                for y in 0..<rep.pixelsHigh {
                    guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.alphaComponent > 0.9 else { continue }
                    if c.greenComponent > c.redComponent + 0.15, c.greenComponent > c.blueComponent + 0.15 { green += 1 }
                    if c.blueComponent > c.redComponent + 0.15, c.blueComponent > c.greenComponent + 0.15 { blue += 1 }
                }
            }
            return (green, blue)
        }

        let onCharger = try drawn(false)
        XCTAssertGreaterThan(onCharger.green, 30)
        XCTAssertEqual(onCharger.blue, 0)
        let onBattery = try drawn(true)
        XCTAssertGreaterThan(onBattery.blue, 30)
        XCTAssertEqual(onBattery.green, 0)
    }
}
