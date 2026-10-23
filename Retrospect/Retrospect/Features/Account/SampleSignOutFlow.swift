//
//  SampleSignOutFlow.swift
//  P33 on invented data: the sign-out flow with the timing of the real one (counts roll down over an
//  injected clock; nothing is instant), so every state of the sheet can be opened from the launcher.
//
import Foundation
import Observation

@MainActor @Observable
final class SampleSignOutFlow: SignOutFlowing {
    enum Script: Equatable {
        /// Everything sends, then the person is signed out.
        case sends
        /// The connection is gone after the first entry: the flow gets stuck.
        case offline
        /// This build is too old to send them.
        case updateRequired
    }

    private(set) var state: SignOutState
    private(set) var forced = false
    @ObservationIgnored private let script: Script
    @ObservationIgnored private let sleep: @Sendable (Duration) async -> Void
    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private let unsent: Int

    init(
        unsent: Int, script: Script = .sends, state: SignOutState? = nil,
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.unsent = unsent
        self.script = script
        self.sleep = sleep
        self.state = state ?? .asking(unsent: unsent)
    }

    func begin() {
        guard case .asking = state else { return }
        let start = unsent
        running = Task { [weak self] in await self?.run(from: start) }
    }

    private func run(from count: Int) async {
        var remaining = count
        while remaining > 0 {
            state = .sending(remaining: remaining)
            await sleep(.seconds(1))
            guard !Task.isCancelled else { return }
            if let reason = stuckReason() {
                state = .stuck(remaining: remaining, reason: reason)
                return
            }
            remaining -= 1
        }
        state = .signingOut
        await sleep(.milliseconds(400))
        guard !Task.isCancelled else { return }
        state = .done
    }

    private func stuckReason() -> SignOutState.StuckReason? {
        switch script {
        case .sends: nil
        case .offline: .offline
        case .updateRequired: .updateRequired
        }
    }

    func signOutAnyway() {
        guard case .stuck = state else { return }
        running?.cancel()
        forced = true
        state = .done
    }

    func cancel() {
        switch state {
        case .signingOut, .done:
            return
        default:
            running?.cancel()
            running = nil
            state = .asking(unsent: unsent)
        }
    }
}
