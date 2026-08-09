import Foundation
import Combine

/// Tracks the writing "session". A session is active while you're typing and ends after
/// `idleInterval` of no edits (default 10 minutes). Session boundaries gate when heavy work
/// (sync flush + synthesis) is allowed to run — never mid-session.
@MainActor
final class SessionMonitor: ObservableObject {
    /// 10 minutes of no typing ends the session.
    let idleInterval: TimeInterval

    @Published private(set) var isInSession = false

    /// Emitted once each time a session transitions active -> ended.
    let sessionDidEnd = PassthroughSubject<Void, Never>()

    private var idleTimer: Timer?
    private var lastActivity = Date.distantPast

    init(idleInterval: TimeInterval = 600) {
        self.idleInterval = idleInterval
    }

    /// Call on every edit / meaningful keystroke.
    func registerActivity() {
        lastActivity = Date()
        if !isInSession { isInSession = true }
        scheduleIdleCheck()
    }

    /// Force the current session to end now (e.g. app quitting or window closing).
    func endSessionNow() {
        idleTimer?.invalidate()
        idleTimer = nil
        guard isInSession else { return }
        isInSession = false
        sessionDidEnd.send(())
    }

    private func scheduleIdleCheck() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.fireIfIdle() }
        }
    }

    private func fireIfIdle() {
        guard isInSession else { return }
        if Date().timeIntervalSince(lastActivity) >= idleInterval - 1 {
            isInSession = false
            sessionDidEnd.send(())
        }
    }
}
