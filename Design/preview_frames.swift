// Dumps one small frame per second from a video, for planning App Preview edits.
// Usage: swift preview_frames.swift <video> <output-dir>
import AVFoundation
import AppKit

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let out = URL(fileURLWithPath: CommandLine.arguments[2])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let asset = AVURLAsset(url: url)
let generator = AVAssetImageGenerator(asset: asset)
generator.maximumSize = CGSize(width: 240, height: 520)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

let duration = CMTimeGetSeconds(asset.duration)
var second = 0.0
while second < duration {
    let time = CMTime(seconds: second, preferredTimescale: 600)
    if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
        let rep = NSBitmapImageRep(cgImage: image)
        let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.6])!
        try data.write(to: out.appendingPathComponent(String(format: "f%03d.jpg", Int(second))))
    }
    second += 1
}
print("frames:", Int(duration))
