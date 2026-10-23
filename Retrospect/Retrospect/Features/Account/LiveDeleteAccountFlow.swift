//
//  LiveDeleteAccountFlow.swift
//  P31.delete on the real platform: "delete my account" runs `deleteAccount` (Apple's fresh code, then
//  `DELETE /v2/account`). On `.deleted` the goodbye stays up for `goodbyeHold`, then `finishAccountDeletion`
//  erases the rest and ends the session (the root shows the first-time splash). Apple closed: the dialog
//  closes, nothing said. Anything else: the dialog's error line, nothing erased, and it can be tried again.
//
import Foundation
import Observation

@MainActor @Observable
final class LiveDeleteAccountFlow: DeleteAccountFlowing {
    /// What the flow needs from the platform, as closures, so tests drive it without Apple or a server.
    struct Ports {
        var unsent: @MainActor () async -> Int
        var isOnline: @MainActor () async -> Bool
        var delete: @MainActor () async -> Session.DeletionOutcome
        var finish: @MainActor () async -> Void
        var sleep: @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    }

    /// How long the goodbye stays before the phone is erased and the splash shows (C50.2: about 2.4 s).
    static let goodbyeHold: Duration = .milliseconds(2400)

    private(set) var state: DeleteAccountState = .closed
    private(set) var unsent: Int
    private(set) var isOnline = true
    @ObservationIgnored private let ports: Ports
    @ObservationIgnored private var running: Task<Void, Never>?

    init(ports: Ports, unsent: Int = 0) {
        self.ports = ports
        self.unsent = unsent
    }

    static func make(platform: Platform.AppEnvironment, apple: any Session.AppleReauthorizing) -> LiveDeleteAccountFlow {
        LiveDeleteAccountFlow(ports: Ports(
            unsent: { await platform.unsentEntryCount() },
            isOnline: { await platform.reachability.isOnline },
            delete: { await platform.deleteAccount(apple: apple) },
            finish: { await platform.finishAccountDeletion() }
        ))
    }

    func open() {
        guard state == .closed, running == nil else { return }
        state = .asking
        running = Task { [weak self] in await self?.readFacts() }
    }

    func confirm() {
        switch state {
        case .asking, .failed: break
        default: return
        }
        guard isOnline else { return }
        running?.cancel()
        state = .pending
        running = Task { [weak self] in await self?.run() }
    }

    func cancel() {
        switch state {
        case .asking, .failed:
            running?.cancel()
            running = nil
            state = .closed
        default:
            return // pending: Apple's sheet or the request is out; goodbye: it can't be taken back
        }
    }

    // MARK: Inside

    private func readFacts() async {
        let count = await ports.unsent()
        let online = await ports.isOnline()
        guard !Task.isCancelled else { return }
        unsent = count
        isOnline = online
        running = nil
    }

    private func run() async {
        let outcome = await ports.delete()
        switch outcome {
        case .deleted:
            state = .goodbye
            await ports.sleep(Self.goodbyeHold)
            await ports.finish()
            state = .done
        case .cancelledAtApple:
            state = .closed
        case .offline:
            isOnline = false
            state = .asking
        case let .failed(problem):
            state = .failed(problem)
        }
        running = nil
    }
}
