// Cuts a simulator recording into an App Store App Preview:
// selected time ranges joined together, scaled to 886 x 1920 (6.3" iPhone),
// 30 fps H.264, with a silent stereo AAC track.
// Usage: swift make_app_preview.swift <raw.mov> <silence.wav> <output.mp4> <start-end> [<start-end> ...]
import AVFoundation

let args = CommandLine.arguments
let source = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let silence = AVURLAsset(url: URL(fileURLWithPath: args[2]))
let outputURL = URL(fileURLWithPath: args[3])
let ranges: [(Double, Double)] = args.dropFirst(4).map {
    let parts = $0.split(separator: "-").compactMap { Double($0) }
    return (parts[0], parts[1])
}

let renderSize = CGSize(width: 886, height: 1920)
let composition = AVMutableComposition()
let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!

let sourceVideo = source.tracks(withMediaType: .video)[0]
var cursor = CMTime.zero
for (start, end) in ranges {
    let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                            end: CMTime(seconds: end, preferredTimescale: 600))
    try videoTrack.insertTimeRange(range, of: sourceVideo, at: cursor)
    cursor = cursor + range.duration
}
let total = cursor

// Silent audio for the full length (loop the silence file if needed).
let silenceTrack = silence.tracks(withMediaType: .audio)[0]
let silenceLength = silence.duration
var audioCursor = CMTime.zero
while audioCursor < total {
    let length = min(silenceLength, total - audioCursor)
    try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: silenceTrack, at: audioCursor)
    audioCursor = audioCursor + length
}

// Scale the 1206 x 2622 recording to fill 886 x 1920 (crops a few pixels vertically).
let natural = sourceVideo.naturalSize
let scale = max(renderSize.width / natural.width, renderSize.height / natural.height)
let scaledHeight = natural.height * scale
let transform = CGAffineTransform(scaleX: scale, y: scale)
    .concatenating(CGAffineTransform(translationX: (renderSize.width - natural.width * scale) / 2,
                                     y: (renderSize.height - scaledHeight) / 2))

let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
layer.setTransform(transform, at: .zero)
let instruction = AVMutableVideoCompositionInstruction()
instruction.timeRange = CMTimeRange(start: .zero, duration: total)
instruction.layerInstructions = [layer]

let videoComposition = AVMutableVideoComposition()
videoComposition.renderSize = renderSize
videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
videoComposition.instructions = [instruction]

try? FileManager.default.removeItem(at: outputURL)
let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)!
export.outputURL = outputURL
export.outputFileType = .mp4
export.videoComposition = videoComposition

let done = DispatchSemaphore(value: 0)
export.exportAsynchronously { done.signal() }
done.wait()
if export.status == .completed {
    print(String(format: "Wrote %@ (%.2f s)", outputURL.path, CMTimeGetSeconds(total)))
} else {
    print("Export failed:", export.error?.localizedDescription ?? "unknown")
    exit(1)
}
