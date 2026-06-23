//
//  WaveformLevelsTests.swift
//  MemoryJournalTests
//
//  The pure downsampling that turns a voice note's full level history into the
//  ~48 bars persisted for its saved waveform.
//

import Testing
import Foundation
@testable import MemoryJournal

struct WaveformLevelsTests {

    @Test func downsamplesToTheTargetCount() {
        let levels = (0..<480).map { _ in CGFloat.random(in: 0...1) }
        #expect(VoiceRecorder.downsample(levels, to: 48).count == 48)
    }

    @Test func shortInputIsReturnedUnchanged() {
        let levels: [CGFloat] = [0.2, 0.4, 0.6]
        #expect(VoiceRecorder.downsample(levels, to: 48) == levels)   // fewer than target
        #expect(VoiceRecorder.downsample([], to: 48) == [])           // empty
    }

    @Test func invalidTargetReturnsInput() {
        let levels: [CGFloat] = [0.1, 0.2, 0.3, 0.4]
        #expect(VoiceRecorder.downsample(levels, to: 0) == levels)
    }

    @Test func averagesWithinEachBucket() {
        // 96 values: first half 0, second half 1 → halving to 48 gives 24 zeros
        // then 24 ones (each bucket of 2 sits entirely in one half).
        let levels = Array(repeating: CGFloat(0), count: 48)
            + Array(repeating: CGFloat(1), count: 48)
        let result = VoiceRecorder.downsample(levels, to: 48)
        #expect(result.count == 48)
        #expect(result.prefix(24).allSatisfy { $0 == 0 })
        #expect(result.suffix(24).allSatisfy { $0 == 1 })
    }

    @Test func uniformInputStaysUniform_andStaysInRange() {
        let result = VoiceRecorder.downsample(Array(repeating: CGFloat(0.5), count: 500), to: 48)
        #expect(result.allSatisfy { $0 == 0.5 })
        #expect(result.allSatisfy { $0 >= 0 && $0 <= 1 })
    }
}
