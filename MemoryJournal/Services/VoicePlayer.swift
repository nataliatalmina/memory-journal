//
//  VoicePlayer.swift
//  MemoryJournal
//
//  One shared audio player for the whole app (injected via the environment).
//  Because there's a single instance, starting playback of one note stops any
//  other — so the Home list, the detail view, the composer review, etc. never
//  play over each other. Views ask "am I the one playing?" to show play/pause
//  and to drive the waveform's progress fill.
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class VoicePlayer: NSObject {
    /// Filename currently playing, or `nil` if stopped.
    private(set) var playingFilename: String?
    /// 0...1 playback progress of the current note.
    private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func isPlaying(_ filename: String) -> Bool { playingFilename == filename }

    /// Play this note, or stop it if it's already the one playing.
    func toggle(_ filename: String) {
        if playingFilename == filename {
            stop()
        } else {
            play(filename)
        }
    }

    func play(_ filename: String) {
        stop()
        let url = MediaStore.audioURL(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            // Cached session config (no re-route when already set up for playback).
            AudioSession.activate(.playback)

            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()   // buffer ahead so play() starts promptly
            newPlayer.play()

            player = newPlayer
            playingFilename = filename
            progress = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateProgress() }
            }
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        playingFilename = nil
        progress = 0
    }

    private func updateProgress() {
        guard let player, player.duration > 0 else { return }
        progress = player.currentTime / player.duration
    }
}

extension VoicePlayer: AVAudioPlayerDelegate {
    // Delegate callbacks are nonisolated; hop back to the main actor to reset.
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}
