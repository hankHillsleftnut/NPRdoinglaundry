import Foundation
import Observation

extension Platform {
    /// Whether this build must update (PL1.6). True once any door answers
    /// `update_required`, or `GET /v2/meta` reports a floor above the running
    /// build; never false again within the process. Meta is asked at launch
    /// and on each active scene, at most once every six hours.
    @MainActor @Observable
    final class VersionFloor {
        /// How often meta is asked at most.
        static let checkEvery: TimeInterval = 6 * 60 * 60

        private(set) var updateRequired = false
        /// The newest version the server knows, once meta has answered.
        private(set) var latestVersion: Backend.AppVersion?

        private let running: Backend.AppVersion?
        private let log: any Platform.LogSink
        private let uptime: @Sendable () -> TimeInterval
        private var lastChecked: TimeInterval?
        private var checking: Task<Void, Never>?
        private var loggedUnreadableRunning = false
        private var loggedUnreadableFloor = false

        init(runningVersion: String, log: any Platform.LogSink, uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
            running = Backend.AppVersion(runningVersion)
            self.log = log
            self.uptime = uptime
        }

        /// A door answered `update_required` (the client calls this on every 426).
        func serverRequiresUpdate() {
            guard !updateRequired else { return }
            updateRequired = true
            log.record(.versionFloor(.updateRequired))
        }

        /// Asks meta if six hours have passed since the last answer (or it
        /// never answered). A failed ask is logged and tried on the next scene.
        func checkIfDue(using client: Backend.Client) async {
            if let checking {
                await checking.value
                return
            }
            if let lastChecked, uptime() - lastChecked < Self.checkEvery {
                return
            }
            let task = Task { await check(using: client) }
            checking = task
            await task.value
            checking = nil
        }

        private func check(using client: Backend.Client) async {
            do {
                let meta = try await client.send(Backend.Endpoints.Meta())
                lastChecked = uptime()
                latestVersion = Backend.AppVersion(meta.latestVersion)
                apply(floor: meta.minVersion)
            } catch {
                log.record(.versionFloor(.askFailed))
            }
        }

        /// Compares the running build with the floor. An unreadable version on
        /// either side never forces an update, and is logged once.
        func apply(floor text: String) {
            guard let running else {
                if !loggedUnreadableRunning {
                    loggedUnreadableRunning = true
                    log.record(.versionUnreadable(.running))
                }
                return
            }
            guard let floor = Backend.AppVersion(text) else {
                if !loggedUnreadableFloor {
                    loggedUnreadableFloor = true
                    log.record(.versionUnreadable(.floor))
                }
                return
            }
            if running.isBelow(floor: floor) {
                serverRequiresUpdate()
            } else {
                log.record(.versionFloor(.current))
            }
        }
    }

    /// What a version-floor check came to, for the log.
    enum VersionFloorOutcome: Sendable, Equatable {
        case current, updateRequired, askFailed
    }

    /// Which version couldn't be read.
    enum UnreadableVersion: Sendable, Equatable {
        case running, floor
    }
}
