// Draws the RecipeApp icon: a letter R whose upright stroke is a whisk, on green.
// Every shape is drawn by hand (no fonts or SF Symbols), so there are no licensing concerns.
// Usage: swift make_icon.swift <output-dir>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

struct Palette {
    let backgroundTop: CGColor
    let backgroundBottom: CGColor
    let mark: CGColor
    let shadow: CGColor
}

let light = Palette(
    backgroundTop: rgb(120, 206, 120),
    backgroundBottom: rgb(28, 128, 72),
    mark: rgb(255, 255, 255),
    shadow: rgb(0, 60, 25, 0.35)
)

let dark = Palette(
    backgroundTop: rgb(44, 44, 48),
    backgroundBottom: rgb(16, 16, 18),
    mark: rgb(96, 200, 112),
    shadow: rgb(0, 0, 0, 0.55)
)

// Layout (CoreGraphics origin is bottom-left).
let stemX: CGFloat = 330          // centre line of the whisk / stem
let baseline: CGFloat = 200       // bottom of the letter
let wireBase: CGFloat = 500       // where the wires leave the handle
let wireTop: CGFloat = 812        // apex of the balloon
let wireWidths: [CGFloat] = [112, 56]
let wireThickness: CGFloat = 19

/// One wire loop of the whisk: a teardrop from the handle up to the apex and back.
func wireLoop(width: CGFloat) -> CGPath {
    let loop = CGMutablePath()
    loop.move(to: CGPoint(x: stemX - 10, y: wireBase))
    loop.addCurve(to: CGPoint(x: stemX, y: wireTop),
                  control1: CGPoint(x: stemX - width * 1.25, y: wireBase + 120),
                  control2: CGPoint(x: stemX - width, y: wireTop))
    loop.addCurve(to: CGPoint(x: stemX + 10, y: wireBase),
                  control1: CGPoint(x: stemX + width, y: wireTop),
                  control2: CGPoint(x: stemX + width * 1.25, y: wireBase + 120))
    return loop
}

func drawMark(in ctx: CGContext, color: CGColor) {
    ctx.setFillColor(color)
    ctx.setStrokeColor(color)

    // Bowl and leg of the R, kept outside the balloon so they appear to grow from its outer wire.
    ctx.saveGState()
    let outside = CGMutablePath()
    outside.addRect(CGRect(x: 0, y: 0, width: size, height: size))
    outside.addPath(wireLoop(width: wireWidths[0]))
    ctx.addPath(outside)
    ctx.clip(using: .evenOdd)

    let bowlTop: CGFloat = 762, bowlBottom: CGFloat = 548, bowlThickness: CGFloat = 96
    let bowlRadius = (bowlTop - bowlBottom) / 2
    let bowlCenter = CGPoint(x: 548, y: bowlBottom + bowlRadius)
    let bowl = CGMutablePath()
    bowl.move(to: CGPoint(x: stemX, y: bowlTop))
    bowl.addLine(to: CGPoint(x: bowlCenter.x, y: bowlTop))
    bowl.addArc(center: bowlCenter, radius: bowlRadius, startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: true)
    bowl.addLine(to: CGPoint(x: stemX, y: bowlBottom))
    ctx.addPath(bowl)
    ctx.setLineWidth(bowlThickness)
    ctx.setLineCap(.butt)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // Leg: a stroke with round caps so its foot matches the rounded whisk handle.
    let legThickness: CGFloat = 104
    ctx.move(to: CGPoint(x: 518, y: bowlBottom - 9))
    ctx.addLine(to: CGPoint(x: 706, y: baseline + legThickness / 2))
    ctx.setLineWidth(legThickness)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // The whisk: handle, ferrule and wires.
    ctx.addPath(CGPath(roundedRect: CGRect(x: stemX - 46, y: baseline, width: 92, height: 290),
                       cornerWidth: 46, cornerHeight: 46, transform: nil))
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: CGRect(x: stemX - 56, y: wireBase - 52, width: 112, height: 58),
                       cornerWidth: 16, cornerHeight: 16, transform: nil))
    ctx.fillPath()

    ctx.setLineWidth(wireThickness)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    for width in wireWidths {
        ctx.addPath(wireLoop(width: width))
        ctx.strokePath()
    }
    ctx.move(to: CGPoint(x: stemX, y: wireBase))
    ctx.addLine(to: CGPoint(x: stemX, y: wireTop))
    ctx.strokePath()
}

func drawIcon(_ p: Palette, to url: URL) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    // No alpha channel: App Store icons must be opaque.
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let s = CGFloat(size)

    let bg = CGGradient(colorsSpace: space, colors: [p.backgroundBottom, p.backgroundTop] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: s * 0.3, y: 0), end: CGPoint(x: s * 0.7, y: s),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Draw the whole mark in one layer so it casts a single soft shadow.
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 36, color: p.shadow)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    drawMark(in: ctx, color: p.mark)
    ctx.endTransparencyLayer()

    let image = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Wrote \(url.path)")
}

drawIcon(light, to: URL(fileURLWithPath: outDir).appendingPathComponent("AppIcon.png"))
drawIcon(dark, to: URL(fileURLWithPath: outDir).appendingPathComponent("AppIcon-Dark.png"))
