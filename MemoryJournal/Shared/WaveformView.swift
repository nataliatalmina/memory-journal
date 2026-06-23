//
//  WaveformView.swift
//  MemoryJournal
//
//  A row of vertical bars for a voice note. When given the note's real captured
//  `levels` (from `MediaStore.loadLevels`), it renders the TRUE amplitude;
//  otherwise it falls back to a stable, good-looking representative pattern (for
//  notes recorded before levels were saved, or media without a sidecar).
//

import SwiftUI

struct WaveformView: View {
    /// 0...1 playback progress. Bars before this fraction render at full opacity,
    /// the rest dimmer.
    var progress: Double = 0
    var color: Color = .white
    /// Real captured amplitudes (0...1), oldest → newest. When nil/empty, the
    /// representative pattern below is drawn instead.
    var levels: [CGFloat]? = nil

    /// The bars to draw: the real levels if we have them, else the stand-in.
    private var bars: [CGFloat] {
        if let levels, !levels.isEmpty { return levels }
        return Self.representativeBars
    }

    /// Thin bars with a tight, fixed gap — the iMessage voice-memo look (and the
    /// same pitch as the live recording meter).
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            // Pick how many bars fit at the fixed pitch, then RESAMPLE the levels to
            // that count — so the row stays full and tightly packed regardless of
            // width, instead of stretching a fixed number of bars far apart.
            let count = max(1, Int((geo.size.width + barSpacing) / (barWidth + barSpacing)))
            let display = Self.resample(bars, to: count)

            HStack(spacing: barSpacing) {
                ForEach(display.indices, id: \.self) { index in
                    let played = Double(index) / Double(display.count) <= progress
                    Capsule()
                        .fill(color.opacity(played ? 1 : 0.55))
                        // A small floor keeps quiet bars visible rather than vanishing.
                        .frame(width: barWidth, height: geo.size.height * max(0.08, display[index]))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    /// Resample `values` to `count` points by linear interpolation (handles both
    /// up- and down-sampling), so the waveform shape is preserved at whatever bar
    /// count fits the width.
    private static func resample(_ values: [CGFloat], to count: Int) -> [CGFloat] {
        guard values.count > 1, count > 1 else { return values }
        return (0..<count).map { i in
            let t = Double(i) / Double(count - 1) * Double(values.count - 1)
            let lo = Int(t)
            let hi = min(values.count - 1, lo + 1)
            let frac = CGFloat(t - Double(lo))
            return values[lo] * (1 - frac) + values[hi] * frac
        }
    }

    /// Deterministic stand-in bar heights — built from a couple of sine waves so
    /// it looks organic but never changes. Used only when no real levels exist.
    private static let representativeBars: [CGFloat] = (0..<44).map { i in
        let x = Double(i)
        let wave = (sin(x * 0.6) * 0.5 + 0.5) * 0.6 + abs(sin(x * 1.9)) * 0.4
        return CGFloat(0.18 + wave * 0.82)   // keep within 0.18...1.0
    }
}

#Preview {
    VStack(spacing: 16) {
        WaveformView(progress: 0.4)                              // representative
        WaveformView(progress: 0.4,
                     levels: (0..<48).map { CGFloat(0.9 * exp(-1.2 * Double($0) / 48 * 2)) })  // real-ish
    }
    .frame(height: 15)
    .padding()
    .background(Color.appPrimary)
}
