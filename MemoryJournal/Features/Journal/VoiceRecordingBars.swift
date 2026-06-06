//
//  VoiceRecordingBars.swift
//  MemoryJournal
//
//  The two transient bars the composer shows during the voice-note flow, in the
//  spot where "Save your memory" normally sits:
//    • RecordingBar — while recording: live waveform + timer + stop.
//    • ReviewBar    — after stopping: discard (✕) + play-to-preview + confirm.
//

import SwiftUI

/// Recording in progress: a real live waveform, a running timer, and a stop button.
struct RecordingBar: View {
    let elapsed: TimeInterval
    let levels: [CGFloat]
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            LiveWaveformView(levels: levels)
                .frame(maxWidth: .infinity)
                .frame(height: 20)

            Text(timeString(elapsed))
                .font(.system(size: 15))
                .monospacedDigit()
                .foregroundStyle(.white)

            Button(action: onStop) {
                ZStack {
                    Circle().stroke(.white, lineWidth: 1.5).frame(width: 28, height: 28)
                    RoundedRectangle(cornerRadius: 2).fill(.white).frame(width: 11, height: 11)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Stop recording")
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(Color.appPrimary)
        .clipShape(.rect(cornerRadius: CornerRadius.button))
    }
}

/// Reviewing a take: discard it, preview it (play/pause + waveform), or keep it.
struct ReviewBar: View {
    let filename: String
    let onDiscard: () -> Void
    let onConfirm: () -> Void

    @Environment(VoicePlayer.self) private var player
    private var isPlaying: Bool { player.isPlaying(filename) }

    /// Destructive red for "discard". (The palette has no red; this is the
    /// conventional destructive colour — flagged for the owner.)
    private static let discardRed = Color(red: 0.80, green: 0.30, blue: 0.29)

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button(action: onDiscard) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Self.discardRed)
                    .clipShape(.rect(cornerRadius: CornerRadius.button))
            }
            .accessibilityLabel("Discard recording")

            // Preview player
            HStack(spacing: Spacing.md) {
                Button { player.toggle(filename) } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }
                WaveformView(progress: isPlaying ? player.progress : 0)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(Color.appPrimary)
            .clipShape(.rect(cornerRadius: CornerRadius.button))

            Button(action: onConfirm) {
                Text("Save")
                    .font(.kyotoItalic(size: 18))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .frame(height: 56)
                    .background(Color.appPrimary)
                    .clipShape(.rect(cornerRadius: CornerRadius.button))
            }
            .accessibilityLabel("Keep voice note")
        }
    }
}

/// "M:SS" for the recording timer.
private func timeString(_ interval: TimeInterval) -> String {
    let total = Int(interval)
    return String(format: "%d:%02d", total / 60, total % 60)
}
