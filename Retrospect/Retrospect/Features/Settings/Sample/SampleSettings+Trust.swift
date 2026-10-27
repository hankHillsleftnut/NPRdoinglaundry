//
//  SampleSettings+Trust.swift
//  V2.settings, second half (ST-5 … ST-9): the sample values those pages own (the voice, how straight
//  retro is, …). Owned by the second settings builder, so the two halves never edit the same file;
//  ST-1 reads these through SampleSettings.
//
import Foundation
import Observation

extension SampleSettings {
    @MainActor @Observable
    final class Trust {
        var voiceName = "warm"
        var straightnessName = "honest"

        init() {}
    }
}
