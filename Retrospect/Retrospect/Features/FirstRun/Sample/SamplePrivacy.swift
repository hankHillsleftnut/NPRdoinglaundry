//
//  SamplePrivacy.swift
//  PV.privacy: ON-5 on sample data. A silent stand-in for Retro reading the page aloud: it
//  "finishes" after about 8 s and the page moves on by itself, the way the 0.2 voice will.
//  Nothing is said aloud and nothing leaves the phone.
//
import Foundation

/// The launcher's ON-5 state (`-Screen first-run -State privacy`).
enum PrivacyScenario: String, CaseIterable {
    /// Retro reads the page (silently, ~8 s), then the page moves on; a tap moves on early.
    case privacy
}

/// A silent reading of a fixed length: `read()` returns true after `length`, false when stopped
/// or cancelled first.
@MainActor
final class SamplePrivacyReadAloud: PrivacyReadAloud {
    /// About how long Retro takes to read the page's title and description aloud.
    static let length: Duration = .seconds(8)

    private let clock: any Clock<Duration>
    private var stopped = false

    init(clock: any Clock<Duration>) {
        self.clock = clock
    }

    func read() async -> Bool {
        stopped = false
        do {
            try await clock.sleep(for: Self.length)
        } catch {
            return false
        }
        return !stopped
    }

    func stop() {
        stopped = true
    }
}
