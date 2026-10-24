//
//  PrivacyModel.swift
//  PV.privacy, ON-5 (Paper p-J-0 16FA-0): the privacy page's decisions, apart from the view so they
//  can be tested. Founder, 23 Oct: exactly as Paper draws it, with no continue button. Retro reads
//  the page aloud and the page moves on by itself when the reading ends; a tap anywhere moves on
//  early. Two holds keep it from moving under someone: the policy sheet being open, and VoiceOver
//  or Switch Control (they move on with the "move on" action or the magic tap, never by itself).
//  The host hears `onAdvance` or `onBack`, once, never both. Nothing here logs.
//
import Foundation
import Observation

/// Where the one flow progress line stands as a page opens: `from` is where the last page left
/// it, `to` is this page's place. Both 0…1; the line travels from one to the other on arrival.
struct FlowProgress: Equatable {
    let from: Double
    let to: Double

    init(from: Double, to: Double) {
        self.from = Self.clamped(from)
        self.to = Self.clamped(to)
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// Retro reading the page aloud. `read()` returns true when it reached the end, false when it was
/// stopped or cancelled first. `stop()` cuts it off.
@MainActor
protocol PrivacyReadAloud: AnyObject, Sendable {
    func read() async -> Bool
    func stop()
}

@MainActor @Observable
final class PrivacyModel {
    /// ON-5's place in the flow: 48% in Paper (1F8F-0), arriving from the questions' 41%.
    static let progress = FlowProgress(from: 0.41, to: 0.48)
    // FOUNDER: real URL. A placeholder until AC.legal's LegalLinks reads the configured one;
    // release builds hide the link until then rather than send the promise to example.com.
    #if DEBUG
    static let policyURL = URL(string: "https://example.com/privacy")
    #else
    static let policyURL: URL? = nil
    #endif

    /// Where the page is in its one life. `left` is terminal: a host that shows ON-5 again builds a
    /// fresh model (FR.root), or back, the taps and the reading all do nothing.
    enum Phase: Equatable {
        /// On screen, Retro reading.
        case reading
        /// The page went off screen while Retro was reading: a late end of that reading moves
        /// nothing. The page reads again when it returns.
        case offScreen
        /// Retro reached the end; the page moves on as soon as nothing holds it.
        case finished
        /// Moved on or backed out: nothing else fires.
        case left
    }

    /// What keeps a finished page from moving on by itself.
    struct Holds: OptionSet {
        let rawValue: Int
        /// The privacy policy sheet is open: never pull the page from under someone reading it.
        static let policy = Holds(rawValue: 1 << 0)
        /// VoiceOver or Switch Control is on: they move on themselves ("move on", the magic tap).
        static let assistiveTech = Holds(rawValue: 1 << 1)
    }

    private(set) var phase: Phase = .reading
    private(set) var holds: Holds = []

    /// The privacy policy sheet is open.
    var isPolicyOpen: Bool {
        holds.contains(.policy)
    }

    /// The page has been left, one way or the other: nothing else fires.
    var hasLeft: Bool {
        phase == .left
    }

    /// Retro finished reading, and the page waits for a VoiceOver user to move on themselves.
    var isWaitingForVoiceOver: Bool {
        phase == .finished && holds == .assistiveTech
    }

    @ObservationIgnored private let readAloud: any PrivacyReadAloud
    @ObservationIgnored private let onAdvance: () -> Void
    @ObservationIgnored private let onBack: () -> Void

    init(
        readAloud: any PrivacyReadAloud,
        onAdvance: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self.readAloud = readAloud
        self.onAdvance = onAdvance
        self.onBack = onBack
    }

    // MARK: Page events

    /// The page is on screen: Retro reads it (`.task`). However the reading ends (the last word, or
    /// cut short by the system: a call, Siri, a route change), the page moves on, so it can never
    /// sit there with nothing to press. A run cancelled with the page ends quietly; `pageLeft()`
    /// stops the voice, on the main actor and in order, so it can't cut off a newer reading.
    func run() async {
        switch phase {
        case .reading:
            break
        case .offScreen:
            // back on screen: read the page again
            phase = .reading
        case .finished, .left:
            return
        }
        _ = await readAloud.read()
        // every stop the model makes itself leaves `.reading` first, so only an outside end moves on
        guard !Task.isCancelled else { return }
        readAloudFinished()
    }

    /// The page went off screen: no voice without the page, and a reading that ends after this
    /// (a voice whose `stop()` hands back its `read()` before the run is cancelled) moves nothing.
    /// It reads again if the page returns.
    func pageLeft() {
        if phase == .reading {
            phase = .offScreen
        }
        readAloud.stop()
    }

    /// A tap anywhere on the page (the composer included): move on now, Retro stops.
    func tapAnywhere() {
        advance()
    }

    /// The VoiceOver "move on" action and the magic tap.
    func moveOn() {
        advance()
    }

    /// The back chevron: the host returns to the last question.
    func back() {
        guard phase != .left else { return }
        phase = .left
        readAloud.stop()
        onBack()
    }

    /// The reading reached its end. Only the reading on screen counts: one that ends after the
    /// page went off screen, or after it was left, moves nothing.
    func readAloudFinished() {
        guard phase == .reading else { return }
        phase = .finished
        advanceIfFree()
    }

    /// VoiceOver or Switch Control turned on or off (the page reports it on arrival and on every
    /// change): both move slowly through a page, so both hold it.
    func voiceOver(running: Bool) {
        if running {
            holds.insert(.assistiveTech)
        } else {
            holds.remove(.assistiveTech)
        }
        advanceIfFree()
    }

    /// "read the privacy policy".
    func openPolicy() {
        guard phase != .left, Self.policyURL != nil else { return }
        holds.insert(.policy)
    }

    /// The policy sheet closed (done, or swiped away).
    func policyClosed() {
        guard holds.contains(.policy) else { return }
        holds.remove(.policy)
        advanceIfFree()
    }

    // MARK: Private

    /// Moves on once the reading is over and nothing holds the page.
    private func advanceIfFree() {
        guard phase == .finished, holds.isEmpty else { return }
        advance()
    }

    private func advance() {
        guard phase != .left else { return }
        phase = .left
        readAloud.stop()
        onAdvance()
    }

    // MARK: Words (Paper ON-5, verbatim; lowercase is the design system's)

    static let title = "what you tell me stays yours."
    static let body = "i only read what you connect and tell me. a few trusted companies help me understand it, "
        + "and more of it moves onto your phone over time. i never sell it. delete everything, anytime."
    static let policyLink = "read the privacy policy"
    /// Read when the page arrives: where you are, then the title.
    static let arrival = "privacy. \(title)"
    /// The VoiceOver action that moves on.
    static let moveOnAction = "move on"
    /// Read when Retro has finished and a VoiceOver user is the one to move on.
    static let finishedForVoiceOver = "retro has finished. use the move on action when you're ready."
}
