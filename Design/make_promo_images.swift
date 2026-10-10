// Builds landscape App Store promo images (3840 x 2560) from the app's screenshots.
// Usage: swift make_promo_images.swift <repo-root> <output-dir>
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let outDir = URL(fileURLWithPath: CommandLine.arguments[2])
let width = 3840, height = 2560
let w = CGFloat(width), h = CGFloat(height)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func load(_ path: String) -> CGImage {
    let source = CGImageSourceCreateWithURL(root.appendingPathComponent(path) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

/// Draws a screenshot inside a rounded phone frame, centred on `center`.
func drawPhone(_ ctx: CGContext, _ image: CGImage, center: CGPoint, height phoneHeight: CGFloat) {
    let phoneWidth = phoneHeight * CGFloat(image.width) / CGFloat(image.height)
    let screen = CGRect(x: center.x - phoneWidth / 2, y: center.y - phoneHeight / 2, width: phoneWidth, height: phoneHeight)
    let bezelInset = phoneHeight * 0.014
    let bezel = screen.insetBy(dx: -bezelInset, dy: -bezelInset)
    let radius = phoneHeight * 0.075

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -phoneHeight * 0.025), blur: phoneHeight * 0.06, color: rgb(0, 30, 10, 0.45))
    ctx.addPath(CGPath(roundedRect: bezel, cornerWidth: radius + bezelInset, cornerHeight: radius + bezelInset, transform: nil))
    ctx.setFillColor(rgb(18, 18, 20))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(image, in: screen)
    ctx.restoreGState()
}

func styled(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineHeightMultiple = 0.95
    return NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(white: 1, alpha: alpha),
        .paragraphStyle: paragraph,
    ])
}

/// Height of `text` when wrapped to `width`.
func textHeight(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
    ceil(text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                           options: [.usesLineFragmentOrigin, .usesFontLeading]).height)
}

/// Draws wrapped text inside `rect` (CoreGraphics coordinates, origin bottom-left).
func drawText(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, in rect: CGRect) {
    styled(text, size: size, weight: weight, alpha: alpha)
        .draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func makeCanvas() -> CGContext {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let bg = CGGradient(colorsSpace: space, colors: [rgb(20, 104, 58), rgb(96, 190, 104)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    return ctx
}

func save(_ ctx: CGContext, _ name: String) {
    let url = outDir.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("Wrote \(url.path)")
}

/// A feature slide: headline and caption on the left, one or two phones on the right.
func featureSlide(_ name: String, headline: String, caption: String, phones: [String]) {
    let ctx = makeCanvas()
    // Headline and caption as one block, centred vertically beside the phones.
    let left: CGFloat = 300, headlineWidth: CGFloat = 1500, captionWidth: CGFloat = 1400, gap: CGFloat = 110
    let title = styled(headline, size: 190, weight: .heavy, alpha: 1)
    let body = styled(caption, size: 92, weight: .medium, alpha: 0.88)
    let titleHeight = textHeight(title, width: headlineWidth)
    let bodyHeight = textHeight(body, width: captionWidth)
    let blockTop = h / 2 + (titleHeight + gap + bodyHeight) / 2
    title.draw(with: CGRect(x: left, y: blockTop - titleHeight, width: headlineWidth, height: titleHeight),
               options: [.usesLineFragmentOrigin, .usesFontLeading])
    body.draw(with: CGRect(x: left, y: blockTop - titleHeight - gap - bodyHeight, width: captionWidth, height: bodyHeight),
              options: [.usesLineFragmentOrigin, .usesFontLeading])

    let phoneHeight: CGFloat = 2150
    if phones.count == 1 {
        drawPhone(ctx, load(phones[0]), center: CGPoint(x: 2780, y: h / 2), height: phoneHeight)
    } else {
        drawPhone(ctx, load(phones[0]), center: CGPoint(x: 2440, y: h / 2 + 60), height: phoneHeight * 0.92)
        drawPhone(ctx, load(phones[1]), center: CGPoint(x: 3200, y: h / 2 - 40), height: phoneHeight)
    }
    save(ctx, name)
}

// 1. Hero: icon, name and tagline with three phones.
do {
    let ctx = makeCanvas()
    let iconRect = CGRect(x: 300, y: 1500, width: 560, height: 560)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 70, color: rgb(0, 30, 10, 0.4))
    ctx.addPath(CGPath(roundedRect: iconRect, cornerWidth: 126, cornerHeight: 126, transform: nil))
    ctx.setFillColor(rgb(255, 255, 255))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: iconRect, cornerWidth: 126, cornerHeight: 126, transform: nil))
    ctx.clip()
    ctx.draw(load("RecipeApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png"), in: iconRect)
    ctx.restoreGState()

    drawText("Recipe Rescue", size: 190, weight: .heavy, alpha: 1, in: CGRect(x: 292, y: 1090, width: 1700, height: 280))
    drawText("Cook with what you have.", size: 104, weight: .medium, alpha: 0.9, in: CGRect(x: 300, y: 880, width: 1700, height: 160))

    drawPhone(ctx, load("AppStore/screenshots/2-recipe-ideas.png"), center: CGPoint(x: 2400, y: h / 2), height: 1750)
    drawPhone(ctx, load("AppStore/screenshots/3-recipe-detail.png"), center: CGPoint(x: 3330, y: h / 2), height: 1750)
    drawPhone(ctx, load("AppStore/screenshots/1-discover.png"), center: CGPoint(x: 2865, y: h / 2 + 30), height: 1980)
    save(ctx, "1-recipe-rescue.png")
}

featureSlide("2-what-can-i-make.png",
             headline: "See what you can make tonight",
             caption: "Add what's in your kitchen. Recipes are ranked by how few ingredients you're missing.",
             phones: ["AppStore/screenshots/5-kitchen.png", "AppStore/screenshots/2-recipe-ideas.png"])

featureSlide("3-step-by-step.png",
             headline: "Every recipe, step by step",
             caption: "Ingredients you already have are checked off automatically.",
             phones: ["AppStore/screenshots/3-recipe-detail.png"])

featureSlide("4-shopping-list.png",
             headline: "Shop only for what's missing",
             caption: "Add missing ingredients in one tap, then move them to your kitchen when you're home.",
             phones: ["AppStore/screenshots/4-shopping-list.png"])

featureSlide("5-discover.png",
             headline: "Discover something new",
             caption: "Fresh recipes from around the world, every time you open the app.",
             phones: ["AppStore/screenshots/1-discover.png"])
