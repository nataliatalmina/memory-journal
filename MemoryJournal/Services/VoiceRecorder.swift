//
//  VoiceRecorder.swift
//  MemoryJournal
//
//  Records a single voice note with `AVAudioRecorder`, into a temporary file in
//  the app's audio container. Drives the composer's three-state mic flow:
//      idle → recording → reviewing
//
//  Live waveform: REAL. We turn on metering and sample the recorder's average
//  power on a timer, so the bars while recording actually react to your voice.
//
//  TODO(owner-requested upgrade, later): persist ~40–50 of these captured levels
//  alongside the saved note (e.g. a sidecar file) so the SAVED waveform can be a
//  true amplitude render too — without ever decoding the audio file. Today the
//  saved-note waveform is representative (see WaveformView); only the live meter
//  is real.
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class VoiceRecorder {
    enum Phase {
        case idle        // nothing recorded
        case recording   // capturing now
        case reviewing   // stopped; a take is waiting to be kept or discarded
    }

    private(set) var phase: Phase = .idle
    private(set) var elapsed: TimeInterval = 0
    /// Recent normalised (0...1) levels for the live waveform.
    private(set) var liveLevels: [CGFloat] = []
    /// The temporary file holding the current take (valid in `.reviewing`).
    private(set) var recordedFilename: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    /// Begin recording. Throws if the audio session or recorder can't be set up.
    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        MediaStore.ensureDirectories()
        let filename = "\(UUID().uuidString).m4a"
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let newRecorder = try AVAudioRecorder(url: MediaStore.audioURL(filename), settings: settings)
        newRecorder.isMeteringEnabled = true   // required for the live meter
        newRecorder.record()

        recorder = newRecorder
        recordedFilename = filename
        elapsed = 0
        liveLevels = []
        phase = .recording

        // Sample ~20×/sec. Timer fires on the main run loop (we're main-actor).
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
    }

    private func sample() {
        guard let recorder else { return }
        recorder.updateMeters()
        liveLevels.append(Self.normalised(recorder.averagePower(forChannel: 0)))
        if liveLevels.count > 300 { liveLevels.removeFirst(liveLevels.count - 300) }
        elapsed = recorder.currentTime
    }

    /// Stop recording and move to review (the file is kept for preview).
    func stop() {
        recorder?.stop()
        stopTimer()
        phase = .reviewing
    }

    /// Throw the current take away (deletes the temp file) and return to idle.
    func discard() {
        recorder?.stop()
        stopTimer()
        if let recordedFilename {
            MediaStore.deleteAudio(recordedFilename)
        }
        reset()
    }

    /// Keep the current take: returns its filename and resets to idle WITHOUT
    /// deleting the file (the caller now owns it / attaches it to the draft).
    func confirm() -> String? {
        recorder?.stop()
        stopTimer()
        let filename = recordedFilename
        reset()
        return filename
    }

    private func reset() {
        recorder = nil
        recordedFilename = nil
        elapsed = 0
        liveLevels = []
        phase = .idle
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Map decibels (-160...0) to a 0...1 bar height over a useful -50...0 window.
    private static func normalised(_ decibels: Float) -> CGFloat {
        let floor: Float = -50
        guard decibels > floor else { return 0.05 }
        return CGFloat(max(0.05, min(1, (decibels - floor) / -floor)))
    }

    #if DEBUG
    /// Put the recorder into a fake state (no real audio) for screenshots/tests.
    func debugEnter(_ phase: Phase, filename: String? = nil) {
        self.phase = phase
        if phase == .recording {
            elapsed = 5
            liveLevels = (0..<140).map { CGFloat(0.15 + 0.75 * abs(sin(Double($0) * 0.45))) }
        }
        if phase == .reviewing { recordedFilename = filename }
    }
    #endif
}
