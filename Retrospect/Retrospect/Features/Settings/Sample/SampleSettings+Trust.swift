//
//  SampleSettings+Trust.swift
//  V2.settings, second half (ST-5 … ST-9): the sample values those pages own (the voice, how straight
//  retro is, what it has learned, …), word for word from Paper. Owned by the second settings builder,
//  so the two halves never edit the same file; ST-1 reads these through SampleSettings.
//
import Foundation
import Observation

#if DEBUG
extension SampleSettings {
    @MainActor @Observable
    final class Trust {
        typealias Settings = Flows.Settings

        var voiceName = "warm"
        /// Retro's own pick, with Paper's reason (1GQR-0).
        static let retroPick = Settings.StraightnessSetting(
            level: .honestObservations,
            source: .picked,
            why: "i picked honest observations because you answer the hard questions, and say \"not quite\" when i'm wrong. choose another and yours wins."
        )
        var straightness = Trust.retroPick
        /// Paper 1GTM-0, 1GTL-0, 1GTK-0 ("last changed on sunday": the Sunday before the sample's Tuesday).
        var learned = Settings.Learned(
            state: .learning,
            headline: "you answer questions about work most, 8 of 10.",
            detail: "you skip ones about family (1 of 5), so i ask those less, and only when you bring it up first.",
            changedAt: Trust.lastSunday
        )

        /// ST-5's switch (Paper 1GPZ-0: on).
        var ambient = Settings.Ambient(enabled: true, effective: true, pausedForEveryone: false)
        /// ST-7 (Paper 1GSK-0: "1×").
        var speed: Settings.Speed = .normal

        /// ST-1's "how straight i am with you" value.
        var straightnessName: String {
            straightness.level?.shortName ?? ""
        }

        /// 25 Oct 2026, a Sunday, at noon in the phone's calendar.
        static let lastSunday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12)) ?? .now

        init() {}
    }
}

extension SampleSettings: Flows.SettingsTrustData {
    var straightness: Settings.StraightnessSetting {
        trust.straightness
    }

    var learned: Settings.Learned {
        trust.learned
    }

    var ambient: Settings.Ambient {
        trust.ambient
    }

    var speed: Settings.Speed {
        trust.speed
    }

    func setAmbient(enabled: Bool) async throws {
        trust.ambient.enabled = enabled
        trust.ambient.effective = enabled && !trust.ambient.pausedForEveryone
    }

    func setSpeed(_ value: Settings.Speed) {
        trust.speed = value
    }

    /// Nothing after a delete is drawn (ST-D19): the sample keeps its values and the dialog closes.
    func deleteMyData() async throws {}

    func setStraightness(_ level: Settings.Straightness?) {
        if let level {
            trust.straightness = Settings.StraightnessSetting(level: level, source: .yours, why: nil)
        } else {
            trust.straightness = Trust.retroPick
        }
    }
}
#endif
