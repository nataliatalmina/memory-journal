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
//  Saved waveform: ALSO REAL. We accumulate the full level history while
//  recording, downsample it to ~48 bars on confirm, and persist it in a sidecar
//  next to the audio (`MediaStore.saveLevels`). `WaveformView` then renders the
//  true amplitude — no need to ever decode the audio file. (Notes without a
//  sidecar fall back to a representative waveform.)
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

    /// How many bars a saved waveform is downsampled to (~40–50, per the design).
    static let savedBarCount = 48

    private(set) var phase: Phase = .idle
    private(set) var elapsed: TimeInterval = 0
    /// Recent normalised (0...1) levels for the live waveform (capped to a window).
    private(set) var liveLevels: [CGFloat] = []
    /// The temporary file holding the current take (valid in `.reviewing`).
    private(set) var recordedFilename: String?

    /// The FULL level history of the current take (uncapped), used to build the
    /// saved waveform. Separate from `liveLevels`, which only keeps a scrolling
    /// window for the on-screen meter.
    private var capturedLevels: [CGFloat] = []

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    /// The current take downsampled to `savedBarCount` bars — for the review
    /// preview before it's saved (empty when there's nothing recorded).
    var capturedWaveform: [CGFloat] { Self.downsample(capturedLevels, to: Self.savedBarCount) }

    /// Begin recording. Throws if the recorder can't be set up.
    func start() throws {
        // Cached session config (no re-route when already set up for recording).
        AudioSession.activate(.playAndRecord, options: [.defaultToSpeaker])

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
        newRecorder.prepareToRecord()          // buffer ahead so record() starts promptly
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
        let level = Self.normalised(recorder.averagePower(forChannel: 0))
        capturedLevels.append(level)                   // full history → saved waveform
        liveLevels.append(level)                       // scrolling window → live meter
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

    /// Keep the current take: persists its waveform sidecar, returns its filename,
    /// and resets to idle WITHOUT deleting the audio (the caller now owns it /
    /// attaches it to the draft; a later discard/cancel cleans both up).
    func confirm() -> String? {
        recorder?.stop()
        stopTimer()
        let filename = recordedFilename
        if let filename {
            let bars = Self.downsample(capturedLevels, to: Self.savedBarCount).map { Float($0) }
            MediaStore.saveLevels(bars, forAudio: filename)
        }
        reset()
        return filename
    }

    private func reset() {
        recorder = nil
        recordedFilename = nil
        elapsed = 0
        liveLevels = []
        capturedLevels = []
        phase = .idle
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Downsample a level history to at most `target` bars by averaging each
    /// contiguous bucket. Pure (no instance state) so it's unit-testable; returns
    /// the input unchanged when it's already short enough or `target` is invalid.
    nonisolated static func downsample(_ levels: [CGFloat], to target: Int) -> [CGFloat] {
        guard target > 0, levels.count > target else { return levels }
        let bucket = Double(levels.count) / Double(target)
        return (0..<target).map { i in
            let start = Int(Double(i) * bucket)
            let end = max(start + 1, min(levels.count, Int(Double(i + 1) * bucket)))
            let slice = levels[start..<end]
            return slice.reduce(0, +) / CGFloat(slice.count)
        }
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
