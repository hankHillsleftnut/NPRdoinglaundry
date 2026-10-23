//
//  LiveSignOutFlow.swift
//  APP-ROOT / P33: the sign-out sheet's flow on the real platform. What hasn't sent goes first (the outbox
//  is asked to send, and the count is read again); when it all sent, the session ends. When it can't (offline,
//  refused, this build too old) the flow is `stuck` and says why; ONLY the person's explicit "sign out anyway"
//  ends the session with words still on the phone, and that is the one call that erases them
//  (`logOut(confirmed: true)`, the founder's decision: unsent words are never erased silently).
//
import Foundation
import Observation

@MainActor @Observable
final class LiveSignOutFlow: SignOutFlowing {
    /// What the flow needs from the platform, as closures, so tests drive it without a store.
    struct Ports {
        /// Entries not sent yet (pending, in flight or refused).
        var unsent: @MainActor () async -> Int
        /// Entries the outbox can still send (pending or in flight); refused ones are not waiting for anything.
        /// Nil when the count can't be read: that counts as still waiting, never as nothing.
        var waiting: @MainActor () async -> Int?
        /// Asks the outbox to send what is due and returns when that pass is over.
        var drain: @MainActor () async -> Void
        var isOnline: @MainActor () async -> Bool
        var updateRequired: @MainActor () -> Bool
        var logOut: @MainActor (_ confirmed: Bool) async -> Platform.AppEnvironment.LogOutResult
        var sleep: @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    }

    private(set) var state: SignOutState
    @ObservationIgnored private let ports: Ports
    @ObservationIgnored private var running: Task<Void, Never>?
    /// Bumped by every begin and cancel: a run that finds it changed has been cancelled and stops without a word.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var lastUnsent: Int

    /// Passes at the outbox before the flow gives up and says it is stuck (one second apart).
    static let attempts = 8

    init(ports: Ports, unsent: Int) {
        self.ports = ports
        lastUnsent = unsent
        state = .asking(unsent: unsent)
    }

    /// The flow on the platform, with the unsent count read first so the sheet opens with the truth.
    static func make(platform: Platform.AppEnvironment) async -> LiveSignOutFlow {
        let ports = Ports(
            unsent: { await platform.unsentEntryCount() },
            waiting: { await Self.waitingCount(platform) },
            drain: { await platform.outbox?.drain(reason: .manual) },
            isOnline: { await platform.reachability.isOnline },
            updateRequired: { platform.updateRequired },
            logOut: { await platform.logOut(confirmed: $0) }
        )
        return await LiveSignOutFlow(ports: ports, unsent: ports.unsent())
    }

    private static func waitingCount(_ platform: Platform.AppEnvironment) async -> Int? {
        guard let outbox = platform.outbox else { return 0 }
        return try? await outbox.waitingToSendCount()
    }

    private var isEnding: Bool {
        switch state {
        case .signingOut, .done: true
        default: false
        }
    }

    func begin() {
        guard case .asking = state, running == nil else { return }
        generation += 1
        let mine = generation
        // Leave .asking at once: a second tap in the same frame is refused
        state = lastUnsent > 0 ? .sending(remaining: lastUnsent) : .signingOut
        running = Task { [weak self] in await self?.run(generation: mine) }
    }

    /// Only from `stuck`, only on the person's explicit tap: the one call that erases words still on the phone.
    func signOutAnyway() {
        guard case .stuck = state else { return }
        generation += 1
        state = .signingOut
        running = Task { [weak self] in await self?.endSession(confirmed: true) }
    }

    func cancel() {
        guard !isEnding else { return } // once the session is ending nothing stops it
        generation += 1
        running?.cancel()
        running = nil
        state = .asking(unsent: lastUnsent)
    }

    // MARK: Inside

    private func run(generation mine: Int) async {
        var remaining = await ports.unsent()
        guard mine == generation else { return }
        lastUnsent = remaining
        if remaining > 0 {
            state = .sending(remaining: remaining)
            guard let left = await sendWhatIsLeft(generation: mine) else { return }
            remaining = left
        }
        guard mine == generation else { return }
        if remaining > 0 {
            let reason = await stuckReason()
            guard mine == generation else { return }
            state = .stuck(remaining: remaining, reason: reason)
            running = nil
            return
        }
        state = .signingOut
        await endSession(confirmed: false)
    }

    /// Asks the outbox to send, reading the count again, until nothing is left or it will not mend. Nil when cancelled.
    private func sendWhatIsLeft(generation mine: Int) async -> Int? {
        var remaining = lastUnsent
        for attempt in 0 ..< Self.attempts {
            await ports.drain()
            remaining = await ports.unsent()
            guard mine == generation else { return nil }
            lastUnsent = remaining
            if remaining == 0 {
                break
            }
            state = .sending(remaining: remaining)
            // refused rows are not waiting for anything; offline and too-old builds will not mend in a second
            let waiting = await ports.waiting()
            let online = await ports.isOnline()
            if waiting == 0 || !online || ports.updateRequired() {
                break
            }
            if attempt < Self.attempts - 1 {
                await ports.sleep(.seconds(1))
            }
            guard mine == generation else { return nil }
        }
        return remaining
    }

    /// Ends the session. Without the person's "anyway", the platform itself refuses if words arrived meanwhile.
    private func endSession(confirmed: Bool) async {
        switch await ports.logOut(confirmed) {
        case .signedOut:
            state = .done
        case let .hasUnsent(count):
            lastUnsent = count
            state = await .stuck(remaining: count, reason: stuckReason())
        }
        running = nil
    }

    private func stuckReason() async -> SignOutState.StuckReason {
        if ports.updateRequired() {
            return .updateRequired
        }
        return await ports.isOnline() ? .failed : .offline
    }
}
