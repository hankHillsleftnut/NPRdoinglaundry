//
//  PrivacyModel.swift
//  PV.privacy, ON-5 (Paper p-J-0 16FA-0): the privacy page's decisions, apart from the view so they
//  can be tested. Founder, 23 Oct: exactly as Paper draws it, with no continue button. Retro reads
//  the page aloud and the page moves on by itself when the reading ends; a tap anywhere moves on
//  early. Two holds keep it from moving under someone: the policy sheet being open, and VoiceOver
//  (VoiceOver users move on with the "move on" action or the magic tap, never automatically).
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
    /// FOUNDER: real URL. A placeholder until AC.legal's LegalLinks reads the configured one.
    static let policyURL = URL(string: "https://example.com/privacy")

    /// The privacy policy sheet is open.
    private(set) var isPolicyOpen = false
    /// The page has been left, one way or the other: nothing else fires.
    private(set) var hasLeft = false
    /// Retro finished reading, but the page is held for a VoiceOver user to move on themselves.
    private(set) var isWaitingForVoiceOver = false

    @ObservationIgnored private let readAloud: any PrivacyReadAloud
    @ObservationIgnored private let onAdvance: () -> Void
    @ObservationIgnored private let onBack: () -> Void
    /// Retro reached the end of the page.
    @ObservationIgnored private var finishedReading = false
    @ObservationIgnored private var voiceOverRunning = false

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

    /// The page is on screen: Retro reads it. Cancelled with the page (`.task`), which stops the
    /// reading: no voice without the page.
    func run() async {
        guard !hasLeft, !finishedReading else { return }
        let readAloud = readAloud
        let finished = await withTaskCancellationHandler {
            await readAloud.read()
        } onCancel: {
            Task { @MainActor in readAloud.stop() }
        }
        guard finished, !Task.isCancelled else { return }
        readAloudFinished()
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
        guard !hasLeft else { return }
        hasLeft = true
        readAloud.stop()
        onBack()
    }

    /// The reading reached its end.
    func readAloudFinished() {
        guard !hasLeft else { return }
        finishedReading = true
        advanceIfFree()
    }

    /// VoiceOver turned on or off (the page reports it on arrival and on every change).
    func voiceOver(running: Bool) {
        voiceOverRunning = running
        if !running {
            isWaitingForVoiceOver = false
        }
        advanceIfFree()
    }

    /// "read the privacy policy".
    func openPolicy() {
        guard !hasLeft, Self.policyURL != nil else { return }
        isPolicyOpen = true
    }

    /// The policy sheet closed (done, or swiped away).
    func policyClosed() {
        guard isPolicyOpen else { return }
        isPolicyOpen = false
        advanceIfFree()
    }

    // MARK: Private

    /// Moves on once the reading is over, unless the policy is open (never pull the page from under
    /// someone reading it) or VoiceOver is on (it may still be reading the page out).
    private func advanceIfFree() {
        guard finishedReading, !hasLeft, !isPolicyOpen else { return }
        guard !voiceOverRunning else {
            isWaitingForVoiceOver = true
            return
        }
        advance()
    }

    private func advance() {
        guard !hasLeft else { return }
        hasLeft = true
        isWaitingForVoiceOver = false
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
