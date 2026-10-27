//
//  SampleSettings.swift
//  V2.settings: the settings on invented data (Paper ST-1 … ST-4's words), so every page opens from the
//  launcher and every control does what Paper draws. Nothing is sent or saved. A sync or a connect
//  turns for a moment on an injected clock, then settles.
//
import Foundation
import Observation

@MainActor @Observable
final class SampleSettings: Flows.SettingsData {
    typealias Settings = Flows.Settings

    private(set) var brief: Settings.Brief
    let briefTimes: [Settings.LocalTime]
    private(set) var talkOrRead: Settings.TalkOrRead = .talk
    /// The second half's values (ST-5 … ST-9), in `SampleSettings+Trust.swift`.
    let trust: Trust
    var voiceName: String {
        trust.voiceName
    }

    var straightnessName: String {
        trust.straightnessName
    }

    private(set) var sources: [Settings.Source]

    @ObservationIgnored private let sleep: @Sendable (Duration) async -> Void
    @ObservationIgnored private let settle: Duration

    init(
        trust: Trust = Trust(),
        settle: Duration = .milliseconds(1500),
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.trust = trust
        self.settle = settle
        self.sleep = sleep
        brief = Settings.Brief(
            isOn: true,
            time: Settings.LocalTime(hour: 8, minute: 30),
            length: .standard,
            city: "london",
            today: Settings.TodaysBrief(day: "tuesday", minutes: 4),
            minutes: [.short: 2, .standard: 4, .long: 8]
        )
        // every half hour from 6 to 10 in the morning (ST-D5: the picker's look isn't drawn)
        briefTimes = (12 ... 20).map { Settings.LocalTime(hour: $0 / 2, minute: $0 % 2 * 30) }
        sources = Self.paperSources
    }

    func setBrief(isOn: Bool) {
        brief.isOn = isOn
    }

    func setBrief(time: Settings.LocalTime) {
        brief.time = time
    }

    func setBrief(length: Settings.BriefLength) {
        brief.length = length
    }

    func setTalkOrRead(_ value: Settings.TalkOrRead) {
        talkOrRead = value
    }

    func connect(_ id: Settings.Source.ID) async {
        update(id) { $0.status = .syncing }
        await sleep(settle)
        update(id) { source in
            source.status = .connected
            source.lastRead = "last read just now"
        }
    }

    func sync(_ id: Settings.Source.ID) async {
        update(id) { $0.status = .syncing }
        await sleep(settle)
        update(id) { source in
            source.status = .connected
            source.lastRead = "last read just now"
        }
    }

    func disconnect(_ id: Settings.Source.ID) async {
        update(id) { $0.status = .notConnected }
    }

    /// Nothing on the page changes after a delete (nothing is drawn for it); the sample keeps its rows.
    func deleteData(of _: Settings.Source.ID) async {}

    private func update(_ id: Settings.Source.ID, _ change: (inout Settings.Source) -> Void) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        change(&sources[index])
    }

    /// ST-3's four rows and ST-4's calendar, word for word (Paper 1GL7-0, 1GNV-0).
    static let paperSources: [Settings.Source] = [
        Settings.Source(
            id: "calendar",
            name: "calendar",
            purpose: "so your brief knows your day",
            symbol: "calendar",
            status: .connected,
            reads: "your events: when, how long, and who was there.",
            helpsMeSee: "what your weeks are really like, and what fills them.",
            lastRead: "last read 2 min ago"
        ),
        Settings.Source(id: "voice-notes", name: "voice notes", purpose: "in your own words", symbol: "mic", status: .notConnected),
        Settings.Source(
            id: "podcasts",
            name: "podcasts",
            purpose: "stopped reading on monday",
            symbol: "dot.radiowaves.left.and.right",
            status: .needsYou
        ),
        Settings.Source(id: "health", name: "health", purpose: "how you slept, how you moved", symbol: "sun.horizon", status: .syncing),
    ]
}
