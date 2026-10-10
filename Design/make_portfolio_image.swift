// Builds a landscape preview image of Recipe Rescue for the portfolio website.
// Usage: swift make_portfolio_image.swift <repo-root> <output.jpg>
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let width = 1500, height = 900

func load(_ path: String) -> CGImage {
    let url = root.appendingPathComponent(path)
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let w = CGFloat(width), h = CGFloat(height)

// Background: the icon's green gradient.
let bg = CGGradient(colorsSpace: space, colors: [rgb(20, 104, 58), rgb(96, 190, 104)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h),
                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

/// Draws a screenshot inside a rounded phone frame.
func drawPhone(_ image: CGImage, center: CGPoint, height phoneHeight: CGFloat) {
    let phoneWidth = phoneHeight * CGFloat(image.width) / CGFloat(image.height)
    let screen = CGRect(x: center.x - phoneWidth / 2, y: center.y - phoneHeight / 2, width: phoneWidth, height: phoneHeight)
    let bezel = screen.insetBy(dx: -10, dy: -10)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: rgb(0, 30, 10, 0.45))
    ctx.addPath(CGPath(roundedRect: bezel, cornerWidth: 58, cornerHeight: 58, transform: nil))
    ctx.setFillColor(rgb(18, 18, 20))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: 48, cornerHeight: 48, transform: nil))
    ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(image, in: screen)
    ctx.restoreGState()
}

// Phones on the right, the middle one raised and in front.
drawPhone(load("AppStore/screenshots/2-recipe-ideas.png"), center: CGPoint(x: 905, y: 430), height: 690)
drawPhone(load("AppStore/screenshots/3-recipe-detail.png"), center: CGPoint(x: 1305, y: 430), height: 690)
drawPhone(load("AppStore/screenshots/1-discover.png"), center: CGPoint(x: 1105, y: 455), height: 760)

// Icon and title on the left.
let icon = load("RecipeApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let iconRect = CGRect(x: 90, y: 500, width: 220, height: 220)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: rgb(0, 30, 10, 0.4))
ctx.addPath(CGPath(roundedRect: iconRect, cornerWidth: 50, cornerHeight: 50, transform: nil))
ctx.setFillColor(rgb(255, 255, 255))
ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: iconRect, cornerWidth: 50, cornerHeight: 50, transform: nil))
ctx.clip()
ctx.draw(icon, in: iconRect)
ctx.restoreGState()

NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
func drawText(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, at point: CGPoint) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(white: 1, alpha: alpha),
    ]
    NSAttributedString(string: text, attributes: attributes).draw(at: point)
}
drawText("Recipe Rescue", size: 72, weight: .heavy, alpha: 1, at: CGPoint(x: 86, y: 370))
drawText("Cook with what you have.", size: 34, weight: .medium, alpha: 0.9, at: CGPoint(x: 90, y: 318))
drawText("SwiftUI · SwiftData · iOS", size: 26, weight: .semibold, alpha: 0.75, at: CGPoint(x: 90, y: 200))

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(output as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
CGImageDestinationFinalize(dest)
print("Wrote \(output.path)")
