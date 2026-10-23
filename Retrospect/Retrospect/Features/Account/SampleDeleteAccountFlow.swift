//
//  SampleDeleteAccountFlow.swift
//  P31.delete on invented data: the delete flow with the timing of the real one (Apple's sheet and the request take
//  a moment, the goodbye holds `goodbyeHold`), so every state of the dialog and the goodbye opens from the
//  launcher. It deletes nothing and sends nothing anywhere.
//
import Foundation
import Observation

@MainActor @Observable
final class SampleDeleteAccountFlow: DeleteAccountFlowing {
    enum Script: Equatable {
        /// The server takes it: goodbye, then done.
        case deletes
        /// The server can't be reached: the error line.
        case fails
        /// The person closes Apple's sheet: the dialog closes.
        case appleCancelled
    }

    private(set) var state: DeleteAccountState
    let unsent: Int
    let isOnline: Bool
    @ObservationIgnored private let script: Script
    @ObservationIgnored private let sleep: @Sendable (Duration) async -> Void
    @ObservationIgnored private var running: Task<Void, Never>?

    init(
        unsent: Int = 0, isOnline: Bool = true, script: Script = .deletes, state: DeleteAccountState = .closed,
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.unsent = unsent
        self.isOnline = isOnline
        self.script = script
        self.state = state
        self.sleep = sleep
    }

    func open() {
        guard state == .closed else { return }
        state = .asking
    }

    func confirm() {
        switch state {
        case .asking, .failed: break
        default: return
        }
        guard isOnline else { return }
        state = .pending
        running = Task { [weak self] in await self?.run() }
    }

    func cancel() {
        switch state {
        case .asking, .failed: state = .closed
        default: return
        }
    }

    private func run() async {
        await sleep(.seconds(1))
        switch script {
        case .deletes:
            state = .goodbye
            await sleep(LiveDeleteAccountFlow.goodbyeHold)
            state = .done
        case .fails:
            state = .failed(.notNow)
        case .appleCancelled:
            state = .closed
        }
    }
}
