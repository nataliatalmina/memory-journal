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

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(bars.indices, id: \.self) { index in
                    let played = Double(index) / Double(bars.count) <= progress
                    Capsule()
                        .fill(color.opacity(played ? 1 : 0.55))
                        // A small floor keeps quiet bars visible rather than vanishing.
                        .frame(height: geo.size.height * max(0.08, bars[index]))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
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
