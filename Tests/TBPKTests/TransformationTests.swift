import AppKit
import XCTest
@testable import TBPK

final class TransformationTests: XCTestCase {
    func testNothingHappensOutsideTheWindow() {
        for progress in [-0.5, 0, 1, 1.5] {
            XCTAssertEqual(Transformation.charge(at: progress), 0)
            XCTAssertEqual(Transformation.shake(at: progress), 0)
            XCTAssertEqual(Transformation.aura(at: progress), 0)
            XCTAssertEqual(Transformation.sparks(at: progress), 0)
        }
    }

    func testTheFlashPeaksOnceAtItsMomentAndIsNarrow() {
        XCTAssertEqual(Transformation.flash(at: Transformation.flashPeak), 1, accuracy: 0.0001)
        XCTAssertEqual(Transformation.flash(at: 0.2), 0)
        XCTAssertEqual(Transformation.flash(at: 0.8), 0)
        let samples = stride(from: 0.0, through: 1.0, by: 0.01).map(Transformation.flash(at:))
        XCTAssertEqual(samples.filter { $0 > 0.99 }.count, 1)
    }

    func testTheLeafHeatsUpBeforeTheFlashAndTheAuraFlaresAfterIt() {
        XCTAssertLessThan(Transformation.charge(at: 0.1), Transformation.charge(at: 0.4))
        XCTAssertEqual(Transformation.charge(at: 0.6), 0, "after the flash the leaf is its own colour")
        XCTAssertGreaterThan(Transformation.aura(at: 0.45), Transformation.aura(at: 0.1))
        XCTAssertGreaterThan(Transformation.aura(at: 0.45), 1, "flares past the steady aura")
        XCTAssertLessThan(Transformation.aura(at: 0.99), 0.1, "and eases back so the steady aura takes over")
    }

    func testTheTrembleGrowsButStaysSmall() {
        let peak = stride(from: 0.0, to: Transformation.flashPeak, by: 0.005).map { abs(Transformation.shake(at: $0)) }.max() ?? 0
        XCTAssertGreaterThan(peak, 0.3)
        XCTAssertLessThanOrEqual(peak, 1, "a point at most: the glyph must not leave its 22 point frame")
    }

    func testSparksRunFromTheFlashToTheEnd() {
        XCTAssertEqual(Transformation.sparks(at: Transformation.flashPeak), 0)
        XCTAssertEqual(Transformation.sparks(at: 0.71), 0.5, accuracy: 0.01)
    }

    func testTheAuraGrowsWithItsStrengthAndIsDeterministic() {
        let rect = NSRect(x: 0, y: 0, width: 15, height: 15)
        XCTAssertGreaterThan(LeafGlyph.aura(in: rect, strength: 1).bounds.width, LeafGlyph.aura(in: rect, strength: 0.2).bounds.width)
        XCTAssertEqual(LeafGlyph.aura(in: rect, strength: 0.7).bounds, LeafGlyph.aura(in: rect, strength: 0.7).bounds)
    }
}
