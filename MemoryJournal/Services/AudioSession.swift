//
//  AudioSession.swift
//  MemoryJournal
//
//  Centralised AVAudioSession setup. Switching the session's category and
//  activating it reconfigure the audio hardware route — a slow, main-thread
//  operation, and the reason there's a lag before recording or playback starts
//  if it's done on every tap.
//
//  So we remember the configured category and only call `setCategory` when it
//  actually changes, and we keep the session active for the app's lifetime
//  (never deactivate). After the first use of each category, starting audio is
//  effectively instant — no re-routing, just `setActive` (a cheap no-op when
//  already active).
//

import AVFoundation

@MainActor
enum AudioSession {
    private static var currentCategory: AVAudioSession.Category?

    /// Ensure the shared session is configured for `category` and active. The
    /// expensive `setCategory` runs only when the category changes.
    static func activate(_ category: AVAudioSession.Category,
                         options: AVAudioSession.CategoryOptions = []) {
        let session = AVAudioSession.sharedInstance()
        do {
            if currentCategory != category {
                try session.setCategory(category, mode: .default, options: options)
                currentCategory = category
            }
            try session.setActive(true)
        } catch {
            // If the session can't be set up, audio simply won't start — non-fatal.
        }
    }
}
