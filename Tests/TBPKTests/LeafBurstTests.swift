import AppKit
import XCTest
@testable import TBPK

final class LeafBurstTests: XCTestCase {
    func testPoweringDownDipsBelowRestSoTheLeafDeflates() {
        var motion = LeafMotion(fill: 1)
        var lowest = 1.0
        for _ in 0..<60 {
            motion.step(toward: 0, dt: 1.0 / 30)
            lowest = min(lowest, motion.fill)
        }
        XCTAssertLessThan(lowest, -0.05)
        XCTAssertEqual(motion.drawnFill, 0)
    }

    func testTheBurstRingsDrawOnlyInsideTheSurgeWindow() {
        func pixels(_ burst: Double) -> Int {
            let image = LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: nil, burst: burst)
            let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            let rep = NSBitmapImageRep(cgImage: cg)
            var count = 0
            for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.3 { count += 1 } }
            return count
        }
        XCTAssertGreaterThan(pixels(0.3), pixels(0))
        XCTAssertEqual(pixels(1), pixels(0))
    }
}
