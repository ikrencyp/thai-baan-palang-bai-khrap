import AppKit

enum LeafGlyph {
    static let side: CGFloat = 22
    private static let inset: CGFloat = 3.6

    // How far the two edges bow away from the stem-to-tip diagonal: 1 was the first, slimmer leaf.
    static let fullness: CGFloat = 1.3
    // The same bow for the half of the edge near the tip, so the upper part of the leaf is broad, not pointed.
    static let tipFullness: CGFloat = 1.75

    static func silhouette(in rect: NSRect, fullness: CGFloat = fullness, tipFullness: CGFloat = tipFullness) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: point(0.10, 0.10, rect))
        path.curve(to: point(0.95, 0.95, rect), controlPoint1: bowed(0.00, 0.58, fullness, rect), controlPoint2: bowed(0.55, 0.86, tipFullness, rect))
        path.curve(to: point(0.10, 0.10, rect), controlPoint1: bowed(0.86, 0.55, tipFullness, rect), controlPoint2: bowed(0.58, 0.00, fullness, rect))
        path.close()
        return path
    }

    // Moves a control point away from the diagonal (x = y) along its perpendicular, keeping its place along it.
    private static func bowed(_ x: CGFloat, _ y: CGFloat, _ fullness: CGFloat, _ rect: NSRect) -> NSPoint {
        let along = (x + y) / 2
        return point(along + (x - along) * fullness, along + (y - along) * fullness, rect)
    }

    static func vein(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: point(0.10, 0.10, rect))
        path.curve(to: point(0.70, 0.70, rect), controlPoint1: point(0.30, 0.28, rect), controlPoint2: point(0.52, 0.56, rect))
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        return path
    }

    static func stem(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: point(-0.20, -0.20, rect))
        path.line(to: point(0.12, 0.12, rect))
        path.lineCapStyle = .round
        return path
    }

    // `tint` colours the leaf; `glowColor` colours the flame around it (the leaf colour when nil).
    static func image(fill: Double, scale: Double, alpha: Double, tint: NSColor?, burst: Double = 0, glow: Double = 0,
                      glowColor: NSColor? = nil) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { bounds in
            draw(in: bounds, fill: fill, scale: scale, alpha: alpha, color: tint ?? .black, flame: glowColor ?? tint ?? .black,
                 burst: burst, glow: tint == nil ? 0 : glow)
            return true
        }
        image.isTemplate = tint == nil
        return image
    }

    static func failureImage() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        return NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }

    private static func draw(in bounds: NSRect, fill: Double, scale: Double, alpha: Double, color: NSColor, flame: NSColor,
                             burst: Double, glow: Double) {
        let charge = Transformation.charge(at: burst)
        let flash = Transformation.flash(at: burst)
        // The leaf trembles while it charges, then the aura and the sparks take over.
        let shake = Transformation.shake(at: burst)
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX + CGFloat(shake), yBy: bounds.midY)
        transform.scale(by: CGFloat(scale))
        transform.translateX(by: -bounds.midX, yBy: -bounds.midY)
        transform.concat()

        let leaf = silhouette(in: rect)
        let aura = max(glow, Transformation.aura(at: burst))
        if aura > 0 { drawAura(in: rect, color: flame, strength: min(aura, 1.4)) }
        drawSparks(Transformation.sparks(at: burst), in: bounds, color: flame)
        // Charging turns the leaf white-hot before it settles into its colour.
        let hot = color.blended(withFraction: CGFloat(max(charge, flash)), of: .white) ?? color
        let ink = hot.withAlphaComponent(CGFloat(alpha))
        let edge = glow > 0 ? (color.blended(withFraction: 0.3, of: .black) ?? color) : ink
        edge.withAlphaComponent(CGFloat(alpha)).setStroke()
        leaf.lineWidth = 1.3
        leaf.lineJoinStyle = .round
        leaf.stroke()

        if fill > 0.001 {
            NSGraphicsContext.saveGraphicsState()
            leaf.addClip()
            sweep(upTo: fill, in: rect).addClip()
            ink.setFill()
            leaf.fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        let stalk = stem(in: rect)
        stalk.lineWidth = 1.5
        edge.withAlphaComponent(CGFloat(alpha)).setStroke()
        stalk.stroke()

        let rib = vein(in: rect)
        rib.lineWidth = 1.1
        if fill < 1 { ink.setStroke(); rib.stroke() }
        if fill > 0.5 {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSColor.black.withAlphaComponent(CGFloat((fill - 0.5) * 2)).setStroke()
            rib.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }
        guard flash > 0 else { return }
        // A soft white bloom that stays inside the frame: a hard disc would show as a clipped shape.
        let radius = 4 + 6.5 * CGFloat(flash)
        let bloom = NSGradient(colors: [NSColor.white.withAlphaComponent(CGFloat(0.9 * flash)), NSColor.white.withAlphaComponent(0)])
        bloom?.draw(fromCenter: NSPoint(x: bounds.midX, y: bounds.midY), radius: 0,
                    toCenter: NSPoint(x: bounds.midX, y: bounds.midY), radius: radius, options: [])
    }

    // Tongues of flame around the leaf, the way a power-up aura licks upward. The tips are fixed per tongue (no
    // random numbers: a frame must look the same every time it is drawn) and grow with `strength`.
    private static let tongues: [Double] = [1.0, 0.55, 0.85, 0.5, 1.15, 0.6, 0.95, 0.45, 1.05, 0.6, 0.9, 0.5, 1.1, 0.55]

    static func aura(in rect: NSRect, strength: Double) -> NSBezierPath {
        let centre = NSPoint(x: rect.midX, y: rect.midY)
        let major = rect.width * 0.5, minor = rect.width * 0.3
        let path = NSBezierPath()
        let count = tongues.count * 2
        for step in 0...count {
            let angle = Double(step % count) / Double(count) * 2 * .pi
            let isTip = step % 2 == 1
            // The leaf lies along the diagonal; the ellipse is turned to follow it.
            let turned = angle + .pi / 4
            let reach = isTip ? 1 + 0.3 * min(strength, 1.2) * tongues[(step / 2) % tongues.count] : 0.92
            // Flames rise: tongues that point up grow a little longer.
            let rise = isTip ? 1 + 0.12 * max(0, sin(angle)) * min(strength, 1.2) : 1
            let x = cos(turned) * major * reach * rise
            let y = sin(turned) * minor * reach * rise
            let rotated = NSPoint(x: centre.x + CGFloat(x * cos(-.pi / 4) - y * sin(-.pi / 4)),
                                  y: centre.y + CGFloat(x * sin(-.pi / 4) + y * cos(-.pi / 4)))
            if step == 0 { path.move(to: rotated) } else { path.line(to: rotated) }
        }
        path.close()
        path.lineJoinStyle = .miter
        return path
    }

    private static func drawAura(in rect: NSRect, color: NSColor, strength: Double) {
        let outer = color.blended(withFraction: 0.2, of: NSColor(srgbRed: 1, green: 0.38, blue: 0.02, alpha: 1)) ?? color
        let flame = aura(in: rect, strength: strength)
        outer.withAlphaComponent(CGFloat(min(strength, 1) * 0.62)).setFill()
        flame.fill()
        let core = aura(in: rect, strength: strength * 0.55)
        color.withAlphaComponent(CGFloat(min(strength, 1) * 0.6)).setFill()
        core.fill()
    }

    // Short bolts that crackle off the leaf while it powers up: `progress` runs 0...1 over the sparks' life.
    private static func drawSparks(_ progress: Double, in bounds: NSRect, color: NSColor) {
        guard progress > 0, progress < 1 else { return }
        let bolts: [(angle: Double, kinks: [Double])] = [(0.5, [0.3, -0.35, 0.25]), (2.5, [-0.3, 0.3, -0.25]), (4.2, [0.35, -0.3, 0.3]), (5.6, [-0.25, 0.35, -0.3])]
        let reach = 7 + 5 * CGFloat(progress)
        let bolt = NSColor.white.blended(withFraction: 0.35, of: color) ?? .white
        for (angle, kinks) in bolts {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: bounds.midX + CGFloat(cos(angle)) * 5, y: bounds.midY + CGFloat(sin(angle)) * 5))
            for (index, kink) in kinks.enumerated() {
                let along = 5 + (reach - 5) * CGFloat(index + 1) / CGFloat(kinks.count)
                let bent = angle + kink
                path.line(to: NSPoint(x: bounds.midX + CGFloat(cos(bent)) * along, y: bounds.midY + CGFloat(sin(bent)) * along))
            }
            path.lineWidth = 1.1
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            bolt.withAlphaComponent(CGFloat(1 - progress)).setStroke()
            path.stroke()
        }
    }

    private static func sweep(upTo fill: Double, in rect: NSRect) -> NSBezierPath {
        let along = 0.04 + 1.0 * fill
        let limit = along * 2
        let path = NSBezierPath()
        path.move(to: point(-1, -1, rect))
        path.line(to: point(-1, limit + 1, rect))
        path.line(to: point(limit + 1, -1, rect))
        path.close()
        return path
    }

    private static func point(_ x: Double, _ y: Double, _ rect: NSRect) -> NSPoint {
        let span = 1.15
        return NSPoint(x: rect.minX + CGFloat((x + 0.20) / span) * rect.width,
                       y: rect.minY + CGFloat((y + 0.20) / span) * rect.height)
    }
}
