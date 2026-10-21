import AppKit
import XCTest
@testable import TBPK

final class LeafShapeTests: XCTestCase {
    private let square = NSRect(x: 0, y: 0, width: 100, height: 100)

    // The leaf lies along the diagonal: turning it upright makes its width the height of the bounds.
    private func width(of path: NSBezierPath) -> CGFloat {
        let turn = AffineTransform(rotationByDegrees: -45)
        let upright = NSBezierPath()
        upright.append(path)
        upright.transform(using: turn)
        return upright.bounds.height
    }

    private func length(of path: NSBezierPath) -> CGFloat {
        let upright = NSBezierPath()
        upright.append(path)
        upright.transform(using: AffineTransform(rotationByDegrees: -45))
        return upright.bounds.width
    }

    func testTheLeafIsWiderThanTheFirstSlimmerShape() {
        let slim = LeafGlyph.silhouette(in: square, fullness: 1, tipFullness: 1)
        let now = LeafGlyph.silhouette(in: square)
        XCTAssertGreaterThan(width(of: now), width(of: slim) * 1.2)
        XCTAssertEqual(length(of: now), length(of: slim), accuracy: 1, "wider, not longer")
    }

    // How far the edge stands off the stem-to-tip line, measured only on the half of the leaf nearest the tip.
    private func upperWidth(of path: NSBezierPath) -> CGFloat {
        let upright = NSBezierPath()
        upright.append(path)
        upright.transform(using: AffineTransform(rotationByDegrees: -45))
        let flat = upright.flattened
        var points = [NSPoint](repeating: .zero, count: 3)
        let all = (0..<flat.elementCount).compactMap { index -> NSPoint? in
            flat.element(at: index, associatedPoints: &points) == .closePath ? nil : points[0]
        }
        let middle = upright.bounds.midX
        let half = all.filter { $0.x > middle }.map { abs($0.y - upright.bounds.midY) }
        return (half.max() ?? 0) * 2
    }

    func testTheUpperHalfOfTheLeafIsBroadNotPointed() {
        let slim = LeafGlyph.silhouette(in: square, fullness: 1, tipFullness: 1)
        let now = LeafGlyph.silhouette(in: square)
        XCTAssertGreaterThan(upperWidth(of: now), upperWidth(of: slim) * 1.4)
    }

    func testTheWiderLeafStillFitsInsideItsIconSquare() {
        let rect = NSRect(x: 0, y: 0, width: LeafGlyph.side, height: LeafGlyph.side).insetBy(dx: 3.6, dy: 3.6)
        let bounds = LeafGlyph.silhouette(in: rect).bounds
        XCTAssertGreaterThanOrEqual(bounds.minX, 0)
        XCTAssertGreaterThanOrEqual(bounds.minY, 0)
        XCTAssertLessThanOrEqual(bounds.maxX, LeafGlyph.side)
        XCTAssertLessThanOrEqual(bounds.maxY, LeafGlyph.side)
    }

    func testTheShapeStaysSymmetricAboutTheDiagonal() {
        let path = LeafGlyph.silhouette(in: square)
        let mirrored = NSBezierPath()
        mirrored.append(path)
        mirrored.transform(using: AffineTransform(m11: 0, m12: 1, m21: 1, m22: 0, tX: 0, tY: 0))
        XCTAssertEqual(mirrored.bounds.minX, path.bounds.minX, accuracy: 0.01)
        XCTAssertEqual(mirrored.bounds.maxY, path.bounds.maxY, accuracy: 0.01)
    }
}
