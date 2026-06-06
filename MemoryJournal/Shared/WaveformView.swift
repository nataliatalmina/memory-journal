//
//  WaveformView.swift
//  MemoryJournal
//
//  A simple, representative waveform — a row of vertical bars. It is NOT a real
//  rendering of the audio's amplitude; it's a stable, good-looking stand-in so
//  the voice-note player matches the design.
//
//  TODO(Part D): when we record real audio, we can sample the recorder's levels
//  and draw a true waveform, and use `progress` to colour the played portion.
//

import SwiftUI

struct WaveformView: View {
    /// 0...1 playback progress. Bars before this fraction render at full opacity,
    /// the rest dimmer. (Always 0 until playback is wired up in Part D.)
    var progress: Double = 0
    var color: Color = .white

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Self.barHeights.indices, id: \.self) { index in
                    let played = Double(index) / Double(Self.barHeights.count) <= progress
                    Capsule()
                        .fill(color.opacity(played ? 1 : 0.55))
                        .frame(height: geo.size.height * Self.barHeights[index])
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    /// Deterministic bar heights (fractions of the available height) — built from
    /// a couple of sine waves so it looks organic but never changes.
    private static let barHeights: [CGFloat] = (0..<44).map { i in
        let x = Double(i)
        let wave = (sin(x * 0.6) * 0.5 + 0.5) * 0.6 + abs(sin(x * 1.9)) * 0.4
        return CGFloat(0.18 + wave * 0.82)   // keep within 0.18...1.0
    }
}

#Preview {
    WaveformView()
        .frame(height: 15)
        .padding()
        .background(Color.appPrimary)
}
