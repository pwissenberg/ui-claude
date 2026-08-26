#!/usr/bin/env swift
//
// Draws "Claude Companion".app's icon and writes Resources/AppIcon.icns.
//
//   swift Tools/make-icon.swift
//
// The icon is generated rather than checked in as an opaque binary so it stays
// editable: every curve below is a coordinate you can nudge and re-run.
//
// Coordinates are expressed in a 1024x1024 design canvas with the origin at the
// TOP-LEFT and y growing downwards, which is how you would read them off a
// drawing. `pt` flips them into Core Graphics' bottom-left space.

import AppKit
import CoreGraphics

let canvas: CGFloat = 1024

/// Design-space (y-down) to Core Graphics (y-up).
func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: canvas - y) }

// MARK: - Palette

/// Claude's coral, darkened towards the bottom so the tile has some depth.
let coralTop = CGColor(red: 0.898, green: 0.510, blue: 0.376, alpha: 1)
let coralBottom = CGColor(red: 0.745, green: 0.322, blue: 0.220, alpha: 1)
/// Warm off-white for the bird, matching claude.ai's cream rather than pure white.
let cream = CGColor(red: 0.961, green: 0.945, blue: 0.910, alpha: 1)
let creamShade = CGColor(red: 0.878, green: 0.847, blue: 0.796, alpha: 1)
/// Near-black with a warm bias, for the beak and eye.
let charcoal = CGColor(red: 0.180, green: 0.149, blue: 0.129, alpha: 1)

// MARK: - Shapes

/// The rounded tile. macOS icons sit on an 824pt squircle inside a 1024pt canvas,
/// leaving the 100pt margin the system expects for its own shadow.
func tilePath() -> CGPath {
    let inset: CGFloat = 100
    let rect = CGRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
    return CGPath(roundedRect: rect, cornerWidth: 185, cornerHeight: 185, transform: nil)
}

/// Appends a circular arc, sampled in design (y-down) coordinates. Angles are
/// degrees clockwise from east, so 90 points straight down.
///
/// Sampling rather than converting to beziers: the curve is only ever rendered
/// at 1024pt or smaller, where 48 segments are indistinguishable from a true
/// arc, and reasoning about a centre and a radius beats guessing control points.
func addArc(_ p: CGMutablePath, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat,
            from a0: CGFloat, to a1: CGFloat, steps: Int = 48) {
    for i in 0...steps {
        let deg = a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)
        let rad = deg * .pi / 180
        let q = pt(cx + r * cos(rad), cy + r * sin(rad))
        if i == 0 && p.isEmpty { p.move(to: q) } else { p.addLine(to: q) }
    }
}

/// A circle described in design (y-down) coordinates.
func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGRect {
    CGRect(x: cx - r, y: canvas - cy - r, width: r * 2, height: r * 2)
}

/// Head, crest and shoulders, as one silhouette. Facing left.
///
/// The bird is a cockatoo: cream body, pointed crest, dark hooked beak. It is
/// framed as a tight portrait - the head fills the tile and the shoulders only
/// clip the bottom corners. Earlier drafts gave the body more room and the
/// result read as a goose: at icon sizes the head has to be the whole subject.
func birdPath() -> CGPath {
    let p = CGMutablePath()
    // Forehead, immediately behind the top of the beak.
    p.move(to: pt(396, 344))
    p.addQuadCurve(to: pt(452, 246), control: pt(402, 282))
    // Crest: three feathers with pointed tips, swept up and back. Points, not
    // bumps - a rounded crest just reads as a lumpy skull.
    p.addQuadCurve(to: pt(470, 132), control: pt(438, 172))
    p.addQuadCurve(to: pt(546, 226), control: pt(524, 166))
    p.addQuadCurve(to: pt(622, 128), control: pt(576, 152))
    p.addQuadCurve(to: pt(682, 236), control: pt(674, 164))
    p.addQuadCurve(to: pt(766, 176), control: pt(738, 176))
    p.addQuadCurve(to: pt(776, 320), control: pt(796, 240))
    // Back of the skull, down into the nape.
    p.addCurve(to: pt(768, 560), control1: pt(786, 400), control2: pt(782, 490))
    // Shoulder: pinched at the nape, then flaring off the bottom of the tile.
    p.addCurve(to: pt(890, 970), control1: pt(752, 660), control2: pt(830, 800))
    p.addLine(to: pt(232, 970))
    // Breast, bulging forward rather than dropping in a straight column.
    p.addCurve(to: pt(352, 690), control1: pt(250, 850), control2: pt(300, 760))
    p.addCurve(to: pt(374, 596), control1: pt(372, 654), control2: pt(366, 626))
    // Face: a gentle curve the beak sits in front of.
    p.addCurve(to: pt(396, 344), control1: pt(368, 500), control2: pt(376, 410))
    p.closeSubpath()
    return p
}

/// The hooked beak - the single feature that says "parrot" rather than "bird".
///
/// Both mandibles are one shape with a notch cut between them. At icon sizes a
/// separately drawn lower mandible only ever reads as a stray speck.
func beakPath() -> CGPath {
    let p = CGMutablePath()
    // Top and leading edge in one stroke: an arc curling around a centre down
    // near the throat. A parrot's upper mandible really is close to a circular
    // arc, and hand-placed control points kept producing a snout instead.
    // Starts at the cere (nearly straight up from the centre) and sweeps
    // anticlockwise through the upper left to finish at the hook's point.
    addArc(p, 418, 524, 169, from: 264, to: 171)
    // Round off the point of the hook.
    p.addQuadCurve(to: pt(292, 534), control: pt(272, 558))
    // Underside of the hook: concave, cutting back up to the right. This is the
    // edge that makes it a hook rather than a cone.
    p.addCurve(to: pt(368, 476), control1: pt(312, 520), control2: pt(344, 496))
    // Notch, then the lower mandible tucked in behind the hook.
    p.addQuadCurve(to: pt(382, 508), control: pt(376, 490))
    p.addQuadCurve(to: pt(424, 528), control: pt(408, 536))
    // Gape corner, then back up the trailing edge to the cere.
    p.addQuadCurve(to: pt(430, 462), control: pt(434, 502))
    p.addCurve(to: pt(400, 356), control1: pt(428, 424), control2: pt(412, 384))
    p.closeSubpath()
    return p
}

// MARK: - Rendering

func draw(into ctx: CGContext, size: CGFloat) {
    ctx.saveGState()
    ctx.scaleBy(x: size / canvas, y: size / canvas)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // Everything is clipped to the tile, so the shoulders can run off the bottom.
    ctx.addPath(tilePath())
    ctx.clip()

    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [coralTop, coralBottom] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(gradient, start: pt(0, 100), end: pt(0, 924), options: [])

    // Bird.
    ctx.addPath(birdPath())
    ctx.setFillColor(cream)
    ctx.fillPath()

    // Beak.
    ctx.addPath(beakPath())
    ctx.setFillColor(charcoal)
    ctx.fillPath()

    // Eye, high and forward on the face as a parrot's is.
    ctx.setFillColor(charcoal)
    ctx.fillEllipse(in: circle(516, 396, 44))
    ctx.setFillColor(cream)
    ctx.fillEllipse(in: circle(532, 380, 15))

    ctx.restoreGState()
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gctx
    draw(into: gctx.cgContext, size: CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// MARK: - Output

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// The ten representations `iconutil` expects.
let variants: [(name: String, size: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for v in variants {
    try render(size: v.size).write(to: iconset.appendingPathComponent("\(v.name).png"))
}

// A standalone 1024 preview, handy for eyeballing the artwork.
try render(size: 1024).write(to: root.appendingPathComponent("Resources/AppIcon-preview.png"))

let icns = root.appendingPathComponent("Resources/AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else {
    FileHandle.standardError.write("iconutil failed\n".data(using: .utf8)!)
    exit(1)
}
try? FileManager.default.removeItem(at: iconset)
print("wrote \(icns.path)")
