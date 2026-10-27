//
//  SampleSettings+Trust.swift
//  V2.settings, second half (ST-5 … ST-9): the sample values those pages own (the voice, how straight
//  retro is, what it has learned, …), word for word from Paper. Owned by the second settings builder,
//  so the two halves never edit the same file; ST-1 reads these through SampleSettings.
//
import Foundation
import Observation

extension SampleSettings {
    @MainActor @Observable
    final class Trust {
        typealias Settings = Flows.Settings

        var voiceName = "warm"
        /// Starts on retro's own pick.
        var straightness: Settings.Straightness = .honestObservations
        let retroPick: Settings.Straightness = .honestObservations
        /// Paper 1GQR-0.
        let retroReason =
            "i picked honest observations because you answer the hard questions, and say \"not quite\" when i'm wrong. choose another and yours wins."
        /// Paper 1GTM-0, 1GTL-0, 1GTK-0.
        var learned: Settings.Learned? = Settings.Learned(
            headline: "you answer questions about work most, 8 of 10.",
            detail: "you skip ones about family (1 of 5), so i ask those less, and only when you bring it up first.",
            changed: "last changed on sunday"
        )

        /// ST-5's ambient switch (Paper 1GPZ-0: on).
        var readsInBackground = true
        /// Paper 1GPU-0.
        let processedWhere = "europe · named providers"
        /// ST-7 (Paper 1GSK-0: "1×").
        var speed: Settings.Speed = .normal

        /// ST-1's "how straight i am with you" value.
        var straightnessName: String {
            straightness.shortName
        }

        init() {}
    }
}

extension SampleSettings: Flows.SettingsTrustData {
    var straightness: Settings.Straightness {
        trust.straightness
    }

    var retroPick: Settings.Straightness {
        trust.retroPick
    }

    var retroReason: String {
        trust.retroReason
    }

    var learned: Settings.Learned? {
        trust.learned
    }

    var readsInBackground: Bool {
        trust.readsInBackground
    }

    var processedWhere: String {
        trust.processedWhere
    }

    var speed: Settings.Speed {
        trust.speed
    }

    func setStraightness(_ value: Settings.Straightness) {
        trust.straightness = value
    }

    func setReadsInBackground(_ isOn: Bool) {
        trust.readsInBackground = isOn
    }

    func setSpeed(_ value: Settings.Speed) {
        trust.speed = value
    }

    /// Nothing after a delete is drawn (ST-D19): the sample keeps its values and the dialog closes.
    func deleteMyData() async {}
}
