//
//  LiveWaveformView.swift
//  MemoryJournal
//
//  The REAL waveform shown while recording: one bar per recent metering sample,
//  newest on the right, scrolling left as new samples arrive. (Contrast with
//  `WaveformView`, the representative one used for a saved note.)
//

import SwiftUI

struct LiveWaveformView: View {
    /// Normalised 0...1 levels, oldest → newest.
    let levels: [CGFloat]
    var color: Color = .white

    private let barWidth: CGFloat = 2
    private let spacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            // How many bars fit, and show that many of the most recent samples.
            let capacity = max(1, Int(geo.size.width / (barWidth + spacing)))
            let recent = Array(levels.suffix(capacity))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(recent.indices, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: barWidth, height: max(2, geo.size.height * recent[index]))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
    }
}
