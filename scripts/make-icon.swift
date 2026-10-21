import AppKit
import CoreGraphics

// TBPK app icon v2: one bold diagonal leaf on a deep emerald squircle, with a bright
// smooth glowing midrib ("palang bai" = leaf power).
// The leaf silhouette is the same one the menu bar glyph uses; keep it unchanged.
// Usage: swiftc -O make-icon.swift -o make-icon && ./make-icon out.png

let side = 1024
let S = CGFloat(side)
let rgb = CGColorSpace(name: CGColorSpace.sRGB)!

func col(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: rgb, components: [
        CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a])!
}
func grad(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(colorsSpace: rgb, colors: stops.map { $0.1 } as CFArray, locations: stops.map { $0.0 })!
}

guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                          space: rgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
ctx.interpolationQuality = .high

// 1. Squircle tile (Big Sur ratio 0.225) -------------------------------------------------
let tileRect = CGRect(x: 0, y: 0, width: S, height: S)
let r = S * 0.225
let tile = CGPath(roundedRect: tileRect, cornerWidth: r, cornerHeight: r, transform: nil)

ctx.saveGState()
ctx.addPath(tile); ctx.clip()
ctx.drawLinearGradient(grad([(0, col(0x021F14)), (0.55, col(0x06512F)), (1, col(0x0C8A4B))]),
                       start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
// subtle top-left light
ctx.drawRadialGradient(grad([(0, col(0xFFFFFF, 0.20)), (1, col(0xFFFFFF, 0))]),
                       startCenter: CGPoint(x: S * 0.18, y: S * 0.92), startRadius: 0,
                       endCenter: CGPoint(x: S * 0.18, y: S * 0.92), endRadius: S * 0.8, options: [])
// soft glow behind the leaf
ctx.drawRadialGradient(grad([(0, col(0x5CFFA0, 0.62)), (0.55, col(0x35E889, 0.22)), (1, col(0x35E889, 0))]),
                       startCenter: CGPoint(x: S * 0.5, y: S * 0.5), startRadius: 0,
                       endCenter: CGPoint(x: S * 0.5, y: S * 0.5), endRadius: S * 0.66, options: [])
// sunburst of rays behind the leaf
for i in 0..<28 {
    let angle = CGFloat(i) / 28 * 2 * .pi
    let half: CGFloat = i % 2 == 0 ? 0.035 : 0.02
    let reach = S * 0.95
    ctx.move(to: CGPoint(x: S * 0.5, y: S * 0.5))
    ctx.addLine(to: CGPoint(x: S * 0.5 + cos(angle - half) * reach, y: S * 0.5 + sin(angle - half) * reach))
    ctx.addLine(to: CGPoint(x: S * 0.5 + cos(angle + half) * reach, y: S * 0.5 + sin(angle + half) * reach))
    ctx.closePath()
    ctx.setFillColor(col(0xAFFFD0, i % 2 == 0 ? 0.10 : 0.05)); ctx.fillPath()
}
// pulse rings radiating from the heart of the leaf
for (radius, width, alpha) in [(0.34, 7.0, 0.34), (0.45, 5.0, 0.22), (0.57, 4.0, 0.12)] as [(CGFloat, CGFloat, CGFloat)] {
    ctx.addEllipse(in: CGRect(x: S * 0.5 - S * radius, y: S * 0.5 - S * radius, width: S * radius * 2, height: S * radius * 2))
    ctx.setLineWidth(width); ctx.setStrokeColor(col(0x9CFFC4, alpha)); ctx.strokePath()
}
// thin specular rim on the tile
ctx.addPath(tile); ctx.setLineWidth(4); ctx.setStrokeColor(col(0xFFFFFF, 0.14)); ctx.strokePath()
ctx.restoreGState()

// 2. Leaf geometry -----------------------------------------------------------------------
let leafSize = S * 0.72
let center = CGPoint(x: S * 0.5, y: S * 0.5)
// leaf bbox centre in unit space is about (0.52,0.52); stem tail pulls it slightly low-left
let unitCenter = CGPoint(x: 0.50, y: 0.50)
var xf = CGAffineTransform(translationX: center.x - unitCenter.x * leafSize + S * 0.005,
                           y: center.y - unitCenter.y * leafSize - S * 0.005)
    .scaledBy(x: leafSize, y: leafSize)

let leaf = CGMutablePath()
leaf.move(to: CGPoint(x: 0.10, y: 0.10))
leaf.addCurve(to: CGPoint(x: 0.95, y: 0.95), control1: CGPoint(x: 0.00, y: 0.58), control2: CGPoint(x: 0.55, y: 0.86))
leaf.addCurve(to: CGPoint(x: 0.10, y: 0.10), control1: CGPoint(x: 0.86, y: 0.55), control2: CGPoint(x: 0.58, y: 0.00))
leaf.closeSubpath()
let leafPath = leaf.copy(using: &xf)!

// Midrib: stem tail -> base -> 0.68, slight bow, one heartbeat kink near the middle.
func rib(_ t: CGFloat, _ off: CGFloat = 0) -> CGPoint {   // t along the diagonal, off perpendicular (up-left positive)
    let bow = 0.014 * sin(.pi * t / 0.68)
    let o = off + bow
    return CGPoint(x: t - o * 0.7071, y: t + o * 0.7071)
}
let ribPts: [CGPoint] = [rib(0.10), rib(0.30), rib(0.48), rib(0.64)]
let stemPts: [CGPoint] = [rib(-0.02), rib(0.12)]
let ribU = CGMutablePath()
ribU.move(to: ribPts[0])
for p in ribPts.dropFirst() { ribU.addLine(to: p) }
let ribPath = ribU.copy(using: &xf)!
let stemU = CGMutablePath()
stemU.move(to: stemPts[0]); stemU.addLine(to: stemPts[1])
let stemPath = stemU.copy(using: &xf)!

ctx.saveGState()
ctx.setLineCap(.round)
ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.012), blur: S * 0.03, color: col(0x00140B, 0.55))
ctx.addPath(stemPath); ctx.setLineWidth(S * 0.04); ctx.setStrokeColor(col(0x14A957)); ctx.strokePath()
ctx.restoreGState()

// 3. Leaf body ----------------------------------------------------------------------------
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.022), blur: S * 0.045, color: col(0x00140B, 0.65))
ctx.addPath(leafPath); ctx.setFillColor(col(0x1DBE62)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(leafPath); ctx.clip()
// body gradient: light mint at the tip, vivid green to the base
ctx.drawLinearGradient(grad([(0, col(0x0B9A4C)), (0.5, col(0x20CC6C)), (1, col(0x7DF2B0))]),
                       start: CGPoint(x: S * 0.30, y: S * 0.20), end: CGPoint(x: S * 0.80, y: S * 0.82), options: [])
// inner glow: darker pooled shade on the lower-right half, lit upper-left half
ctx.drawLinearGradient(grad([(0, col(0xFFFFFF, 0.20)), (0.5, col(0xFFFFFF, 0)), (1, col(0x003D1E, 0.35))]),
                       start: CGPoint(x: S * 0.30, y: S * 0.80), end: CGPoint(x: S * 0.75, y: S * 0.25), options: [])
// glow hugging the midrib
ctx.addPath(ribPath); ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.setLineWidth(S * 0.06)
ctx.setShadow(offset: .zero, blur: S * 0.05, color: col(0xBFFFDD, 0.9))
ctx.setStrokeColor(col(0xBFFFDD, 0.35)); ctx.strokePath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)
// specular edge, brightest on the upper-left rim
ctx.addPath(leafPath); ctx.setLineWidth(10); ctx.setStrokeColor(col(0xFFFFFF, 0.35)); ctx.strokePath()
ctx.restoreGState()

// 4. Vein: dark groove for contrast, then luminous core ---------------------------------
ctx.saveGState()
ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.addPath(ribPath); ctx.setLineWidth(S * 0.03); ctx.setStrokeColor(col(0x04542B, 0.5)); ctx.strokePath()
ctx.setShadow(offset: .zero, blur: S * 0.03, color: col(0xE9FFF3, 0.95))
ctx.addPath(ribPath); ctx.setLineWidth(S * 0.02); ctx.setStrokeColor(col(0xFFFFFF)); ctx.strokePath()
ctx.restoreGState()

// 5. Write PNG --------------------------------------------------------------------------
guard CommandLine.arguments.count > 1, let img = ctx.makeImage() else {
    FileHandle.standardError.write("usage: make-icon <out.png>\n".data(using: .utf8)!); exit(1)
}
let rep = NSBitmapImageRep(cgImage: img)
rep.size = NSSize(width: side, height: side)
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
