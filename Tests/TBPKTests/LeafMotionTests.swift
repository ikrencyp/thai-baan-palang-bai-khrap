import AppKit
import XCTest
@testable import TBPK

final class LeafMotionTests: XCTestCase {
    private func settle(_ motion: inout LeafMotion, toward target: Double) -> Int {
        var frames = 0
        while !(motion.fill == target && motion.isSettled), frames < 300 {
            motion.step(toward: target, dt: 1.0 / 30)
            frames += 1
        }
        return frames
    }

    func testTheFillReachesItsTargetInAboutAThirdOfASecond() {
        var motion = LeafMotion(fill: 0)
        let frames = settle(&motion, toward: 1)
        XCTAssertEqual(motion.fill, 1)
        XCTAssertLessThan(frames, 45)
        XCTAssertGreaterThan(frames, 5)
    }

    func testTheFillOvershootsASmallAmountSoTheLeafPops() {
        var motion = LeafMotion(fill: 0)
        var peak = 0.0
        for _ in 0..<60 {
            motion.step(toward: 1, dt: 1.0 / 30)
            peak = max(peak, motion.fill)
        }
        XCTAssertGreaterThan(peak, 1.0)
        XCTAssertGreaterThan(peak, 1.1)
        XCTAssertLessThan(peak, 1.35)
        XCTAssertLessThanOrEqual(motion.drawnFill, 1)
    }

    func testReversingMidwayTurnsAroundFromWhereTheFillIs() {
        var motion = LeafMotion(fill: 0)
        for _ in 0..<2 { motion.step(toward: 1, dt: 1.0 / 30) }
        let midway = motion.fill
        XCTAssertGreaterThan(midway, 0)
        XCTAssertLessThan(midway, 1)
        _ = settle(&motion, toward: 0)
        XCTAssertEqual(motion.fill, 0)
    }

    func testSnapJumpsWithoutMotion() {
        var motion = LeafMotion(fill: 0)
        motion.snap(to: 1)
        XCTAssertEqual(motion.fill, 1)
        XCTAssertTrue(motion.isSettled)
    }

    func testTheHeartbeatIsALubDubThatReturnsToRest() {
        let rest = Heartbeat.scale(at: 0.85)
        XCTAssertEqual(rest, 1, accuracy: 0.01)
        let lub = Heartbeat.scale(at: 0.12 * Heartbeat.period)
        let dub = Heartbeat.scale(at: 0.34 * Heartbeat.period)
        XCTAssertGreaterThan(lub, 1.25)
        XCTAssertGreaterThan(dub, 1.18)
        XCTAssertLessThan(lub, 1.32)
        XCTAssertGreaterThan(lub, dub)
        XCTAssertEqual(Heartbeat.scale(at: 0.3), Heartbeat.scale(at: 0.3 + Heartbeat.period), accuracy: 1e-9)
    }

    private func opaquePixels(_ image: NSImage) -> Int {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 0 }
        let rep = NSBitmapImageRep(cgImage: cg)
        var count = 0
        for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 { count += 1 } }
        return count
    }

    func testTheGlyphGrowsWithFillAndTintingTurnsOffTemplateMode() {
        let empty = LeafGlyph.image(fill: 0, scale: 1, alpha: 1, tint: nil)
        let half = LeafGlyph.image(fill: 0.5, scale: 1, alpha: 1, tint: nil)
        let full = LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: nil)
        XCTAssertTrue(empty.isTemplate)
        XCTAssertFalse(LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: .systemRed).isTemplate)
        XCTAssertLessThan(opaquePixels(empty), opaquePixels(half))
        XCTAssertLessThan(opaquePixels(half), opaquePixels(full))
    }
}

final class LeafColourTests: XCTestCase {
    private func colours(_ image: NSImage) -> (gold: Int, green: Int, red: Int) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return (0, 0, 0) }
        let rep = NSBitmapImageRep(cgImage: cg)
        var found = (gold: 0, green: 0, red: 0)
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.alphaComponent > 0.25,
                      c.saturationComponent > 0.35, c.brightnessComponent > 0.6 else { continue }
                let hue = c.hueComponent
                if (0.09...0.17).contains(hue) { found.gold += 1 }
                if (0.30...0.45).contains(hue) { found.green += 1 }
                if hue < 0.03 || hue > 0.97 { found.red += 1 }
            }
        }
        return found
    }

    func testTheChargingLeafIsGreenInAGoldenFlame() {
        let found = colours(LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: LeafColor.standard.nsColor, glow: 1,
                                            glowColor: StatusIconAnimator.powerGold))
        XCTAssertGreaterThan(found.green, 10, "the leaf")
        XCTAssertGreaterThan(found.gold, 10, "the flame")
        XCTAssertEqual(found.red, 0)
    }

    func testTheLeafOffTheChargerIsRedInTheSameGoldenFlame() {
        let found = colours(LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: .systemRed, glow: 1, glowColor: StatusIconAnimator.powerGold))
        XCTAssertGreaterThan(found.red, 10, "the leaf")
        XCTAssertGreaterThan(found.gold, 10, "the flame")
        XCTAssertEqual(found.green, 0)
    }

    func testWithoutAFlameColourTheFlameTakesTheLeafColour() {
        let found = colours(LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: .systemRed, glow: 1))
        XCTAssertGreaterThan(found.red, 10)
        XCTAssertEqual(found.gold, 0)
    }
}
