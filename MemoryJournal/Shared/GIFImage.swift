//
//  GIFImage.swift
//  MemoryJournal
//
//  Plays an animated GIF from the app bundle.
//
//  Why this exists: SwiftUI's `Image` shows only the FIRST frame of a GIF — it
//  can't animate one. The options for animating a GIF are:
//    1. Wrap a UIKit `UIImageView` (it animates GIFs via `UIImage.animatedImage`).
//    2. Load it in a `WKWebView` — heavyweight, wrong tool for a splash.
//    3. A third-party package (e.g. Gifu/SDWebImage) — but CLAUDE.md says no
//       third-party dependencies without agreeing first.
//    4. Decode the frames ourselves with Apple's ImageIO and step through them.
//
//  We use (4): pure SwiftUI + Apple frameworks, no UIKit view, no dependency.
//  `TimelineView(.animation)` drives the animation — it ticks once per display
//  refresh and, crucially, PAUSES automatically when the view is offscreen, so
//  there's no timer to leak or cancel. Frames are decoded once and cached.
//
//  Memory note: the source GIF is 2048×2048. Decoding every frame at full size
//  would be huge, so we downsample each frame to `maxPixel` on decode.
//

import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct GIFImage: View {
    /// Bundle resource name without the `.gif` extension (e.g. "Loading").
    let resourceName: String
    /// Longest-edge pixel size to downsample frames to. ~600 is crisp at the
    /// on-screen size while keeping memory modest.
    var maxPixel: CGFloat = 600

    @State private var gif: DecodedGIF?

    var body: some View {
        Group {
            if let gif, !gif.frames.isEmpty {
                // `.animation` schedule re-renders every frame; we pick the frame
                // whose time window contains "now".
                TimelineView(.animation) { context in
                    gif.frame(at: context.date)
                        .resizable()
                        .scaledToFit()
                }
                // The book is decorative; the "memory journal" wordmark carries the
                // meaning, so we hide the image from VoiceOver to avoid noise.
                .accessibilityHidden(true)
            } else {
                Color.clear
            }
        }
        // Decode after first render (kept off the initial layout pass). Cached,
        // so re-creating this view is essentially free.
        .task(id: resourceName) {
            gif = GIFStore.shared.decoded(resourceName: resourceName, maxPixel: maxPixel)
        }
    }
}

/// A decoded GIF: its frames (each a SwiftUI `Image` plus the running time at
/// which it ends) and the total loop duration.
struct DecodedGIF {
    struct Frame {
        let image: Image
        let endTime: Double   // cumulative seconds from loop start to end of this frame
    }

    let frames: [Frame]
    let duration: Double

    /// The frame to show at the given wall-clock instant, looping forever.
    func frame(at date: Date) -> Image {
        guard duration > 0, !frames.isEmpty else { return frames.first?.image ?? Image(systemName: "book") }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
        for frame in frames where t < frame.endTime {
            return frame.image
        }
        return frames[frames.count - 1].image
    }
}

/// Caches decoded GIFs by name so we never decode the same file twice. Lives on
/// the main actor (matches the app's default isolation), so the dictionary is
/// safe from data races without extra locking.
@MainActor
final class GIFStore {
    static let shared = GIFStore()
    private var cache: [String: DecodedGIF] = [:]

    func decoded(resourceName: String, maxPixel: CGFloat) -> DecodedGIF {
        if let cached = cache[resourceName] { return cached }
        let decoded = Self.decode(resourceName: resourceName, maxPixel: maxPixel)
        cache[resourceName] = decoded
        return decoded
    }

    private static func decode(resourceName: String, maxPixel: CGFloat) -> DecodedGIF {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return DecodedGIF(frames: [], duration: 0)
        }

        let frameCount = CGImageSourceGetCount(source)
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]

        var frames: [DecodedGIF.Frame] = []
        var elapsed = 0.0
        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, index, thumbnailOptions as CFDictionary) else { continue }
            elapsed += frameDelay(source: source, index: index)
            frames.append(.init(image: Image(decorative: cgImage, scale: 1), endTime: elapsed))
        }

        return DecodedGIF(frames: frames, duration: elapsed)
    }

    /// Per-frame delay in seconds, read from the GIF metadata. GIFs that declare
    /// an absurdly small delay are clamped to a sane default (matching how
    /// browsers treat them).
    private static func frameDelay(source: CGImageSource, index: Int) -> Double {
        let fallback = 0.1
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return fallback
        }
        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? fallback
        return delay < 0.011 ? fallback : delay
    }
}
