import Foundation
import os

extension Platform {
    /// The one way new code logs. An event is a closed list of cases carrying
    /// only enums and counts, so a log line can never hold someone's words, a
    /// token or a URL. Each byte that needs a new line adds a case here.
    enum Log {}

    /// Where log events go. Production uses `Log.SystemSink`; tests and previews
    /// use `Log.Recorder`.
    protocol LogSink: Sendable {
        func record(_ event: Log.Event)
    }
}

extension Platform.Log {
    enum Event: Equatable, Sendable {
        /// The session was refreshed.
        case refreshed
        /// One outbox drain finished.
        case outboxDrained(sent: Int, failed: Int)
        /// One request finished: its door, the HTTP status (0 when nothing came
        /// back) and how long it took.
        case requestSent(path: Backend.PathTemplate, status: Int, ms: Int)
        /// A door answered with an error code outside the contract's list. The
        /// code itself is never logged.
        case unknownErrorCode(path: Backend.PathTemplate)
        /// Something was queued in the outbox (PL2.2). No text, no ids.
        case outboxEnqueued(operation: Store.OutboxOperation)
        /// Someone signed in (PL1.4): which provider, and whether the account is new.
        case signedIn(provider: Session.Provider, isNew: Bool)
        /// The system couldn't make random bytes for a sign-in nonce (PL1.4), so
        /// the sign-in was not sent; `status` is what `SecRandomCopyBytes` returned.
        case nonceUnavailable(status: OSStatus)
        /// The launch install check ran (PL1.3): what it found.
        case installChecked(Session.InstallCheck)
        /// The launch install check failed with this Keychain status; the next
        /// launch tries again.
        case installCheckFailed(status: OSStatus)
        /// The launch install check threw something that isn't a Keychain error.
        case installCheckErrored
        /// A refresh was sent again after a dropped answer (PL1.5).
        case refreshRetried
        /// A refresh failed and the credentials were kept (PL1.5).
        case refreshFailed(Session.RefreshFailure)
        /// The server ended the session (`session_revoked`, or a refresh token
        /// it called malformed); the device signed out (PL1.5).
        case sessionRevoked
        /// This device signed out, and whether the server was told.
        case signedOut(reason: Session.SignedOutReason, serverNotified: Bool)
        /// A 401 on an authenticated door was answered with one refresh and one replay.
        case requestReplayed(path: Backend.PathTemplate)
        /// A Keychain write of one of the session's items failed; the session
        /// carries on in memory and the write is tried again later.
        case keychainWriteFailed(Session.KeychainItem, status: OSStatus)
        /// The session couldn't be read: the phone is locked (`errSecInteractionNotAllowed`)
        /// or the Keychain answered another status. Read again on the next active scene.
        case sessionLocked(status: OSStatus)
        /// The session manager was asked for the server before the client was connected.
        case sessionNotConnected
        /// Apple says the person removed the app from their Apple ID: signed out.
        case appleCredentialRevoked
        /// The old client's 401 went through the bridge: what came back.
        case legacyRefresh(Platform.Bridges.LegacyRefresh)
        /// `-Environment staging` resolved to the backend on this Mac (no Render staging yet).
        case stagingResolvedToLocal
        /// An invite code arrived (a link or a typed code) and was kept. Never the code.
        case inviteReceived
        /// A pending code was checked (PL1.7d): what came back.
        case inviteChecked(Session.InviteCheckOutcome)
        /// A tear redeemed, or didn't.
        case inviteTorn(Session.InviteTearOutcome)
        /// The version floor was checked (PL1.6): what it found.
        case versionFloor(Platform.VersionFloorOutcome)
        /// A version string couldn't be read; logged once per process and side.
        case versionUnreadable(Platform.UnreadableVersion)
        /// A launch argument was ignored (debug builds only).
        case launchOptionIgnored(Platform.LaunchOptions.Problem)
        /// A batch of diagnostics couldn't be written; it was dropped.
        case diagnosticsWriteFailed
    }

    /// Writes to the unified log, subsystem `com.shauryanarang.Retrospect`,
    /// category `platform`. Every line is a fixed string; only integers are
    /// interpolated, and the system keeps those public by default, so nothing
    /// is marked `.public`.
    struct SystemSink: Platform.LogSink {
        private let logger = Logger(subsystem: "com.shauryanarang.Retrospect", category: "platform")

        func record(_ event: Event) {
            switch event {
            case .refreshed:
                logger.info("session refreshed")
            case let .outboxDrained(sent, failed):
                logger.info("outbox drained: sent \(sent), failed \(failed)")
            case let .requestSent(path, status, ms):
                record(sent: path, status: status, ms: ms)
            case let .unknownErrorCode(path):
                record(unknownCodeFrom: path)
            case let .outboxEnqueued(operation):
                record(operation)
            case let .launchOptionIgnored(problem):
                record(problem)
            case .refreshRetried, .refreshFailed, .sessionRevoked, .signedOut, .requestReplayed, .keychainWriteFailed, .signedIn,
                 .nonceUnavailable:
                recordSession(event)
            case .installChecked, .installCheckFailed, .installCheckErrored, .sessionLocked, .sessionNotConnected, .appleCredentialRevoked,
                 .legacyRefresh, .stagingResolvedToLocal, .diagnosticsWriteFailed:
                recordDevice(event)
            case .inviteReceived, .inviteChecked, .inviteTorn, .versionFloor, .versionUnreadable:
                recordGate(event)
            }
        }

        /// The invite's and the version floor's lines (PL1.6, PL1.7).
        private func recordGate(_ event: Event) {
            switch event {
            case .inviteReceived:
                logger.info("invite code received")
            case let .inviteChecked(outcome):
                record(checked: outcome)
            case let .inviteTorn(outcome):
                record(torn: outcome)
            case let .versionFloor(outcome):
                record(floor: outcome)
            case let .versionUnreadable(which):
                record(unreadable: which)
            default:
                break
            }
        }

        private func record(floor outcome: Platform.VersionFloorOutcome) {
            switch outcome {
            case .current: logger.info("version floor: this build is current")
            case .updateRequired: logger.error("version floor: this build must update")
            case .askFailed: logger.info("version floor: meta couldn't be asked, next scene")
            }
        }

        private func record(unreadable which: Platform.UnreadableVersion) {
            switch which {
            case .running: logger.error("version floor: the running version is unreadable")
            case .floor: logger.error("version floor: the server's minimum version is unreadable")
            }
        }

        /// The session's lines (PL1.5), kept apart so each switch stays small.
        private func recordSession(_ event: Event) {
            switch event {
            case .refreshRetried:
                logger.info("session refresh sent again after a dropped answer")
            case let .refreshFailed(failure):
                record(failure)
            case .sessionRevoked:
                logger.error("session revoked by the server: signed out")
            case let .signedOut(reason, serverNotified):
                record(signedOut: reason, serverNotified: serverNotified)
            case let .requestReplayed(path):
                record(replayed: path)
            case let .keychainWriteFailed(item, status):
                record(writeFailed: item, status: status)
            case let .signedIn(provider, isNew):
                record(signedInWith: provider, isNew: isNew)
            case let .nonceUnavailable(status):
                logger.error("sign-in nonce unavailable: random status \(status)")
            default:
                break
            }
        }

        /// The phone's and the old app's lines (PL1.3, PL1.5).
        private func recordDevice(_ event: Event) {
            switch event {
            case let .installChecked(check):
                record(check)
            case let .installCheckFailed(status):
                logger.error("install check failed: keychain status \(status)")
            case .installCheckErrored:
                logger.error("install check failed with an error that isn't a keychain status")
            case let .sessionLocked(status):
                logger.info("session unreadable, read again when active: keychain status \(status)")
            case .sessionNotConnected:
                logger.error("session manager asked for the server before the client was connected")
            case .appleCredentialRevoked:
                logger.info("apple credential revoked or not found: signed out")
            case let .legacyRefresh(outcome):
                record(legacy: outcome)
            case .stagingResolvedToLocal:
                logger.info("environment staging resolved to the backend on this Mac")
            case .diagnosticsWriteFailed:
                logger.error("diagnostics: a batch couldn't be written, dropped")
            default:
                break
            }
        }

        /// One fixed line per door: the template is never interpolated.
        private func record(sent path: Backend.PathTemplate, status: Int, ms: Int) {
            switch path {
            case .meta: logger.info("request /v2/meta: status \(status), \(ms) ms")
            case .diagnostics: logger.info("request /v2/diagnostics: status \(status), \(ms) ms")
            case .entries: logger.info("request /v2/entries: status \(status), \(ms) ms")
            case .authApple: logger.info("request /v2/auth/apple: status \(status), \(ms) ms")
            case .authRefresh: logger.info("request /v2/auth/refresh: status \(status), \(ms) ms")
            case .authSignout: logger.info("request /v2/auth/signout: status \(status), \(ms) ms")
            case .access, .waitlist, .invitesCheck, .invitesRedeem, .invitesMine: record(sentInvite: path, status: status, ms: ms)
            }
        }

        private func record(sentInvite path: Backend.PathTemplate, status: Int, ms: Int) {
            switch path {
            case .access: logger.info("request /v2/access: status \(status), \(ms) ms")
            case .waitlist: logger.info("request /v2/waitlist: status \(status), \(ms) ms")
            case .invitesCheck: logger.info("request /v2/invites/check: status \(status), \(ms) ms")
            case .invitesRedeem: logger.info("request /v2/invites/redeem: status \(status), \(ms) ms")
            case .invitesMine: logger.info("request /v2/invites/mine: status \(status), \(ms) ms")
            default: break
            }
        }

        private func record(unknownCodeFrom path: Backend.PathTemplate) {
            switch path {
            case .meta: logger.error("unknown error code from /v2/meta")
            case .diagnostics: logger.error("unknown error code from /v2/diagnostics")
            case .entries: logger.error("unknown error code from /v2/entries")
            case .authApple: logger.error("unknown error code from /v2/auth/apple")
            case .authRefresh: logger.error("unknown error code from /v2/auth/refresh")
            case .authSignout: logger.error("unknown error code from /v2/auth/signout")
            case .access, .waitlist, .invitesCheck, .invitesRedeem, .invitesMine: record(unknownCodeFromInvite: path)
            }
        }

        private func record(unknownCodeFromInvite path: Backend.PathTemplate) {
            switch path {
            case .access: logger.error("unknown error code from /v2/access")
            case .waitlist: logger.error("unknown error code from /v2/waitlist")
            case .invitesCheck: logger.error("unknown error code from /v2/invites/check")
            case .invitesRedeem: logger.error("unknown error code from /v2/invites/redeem")
            case .invitesMine: logger.error("unknown error code from /v2/invites/mine")
            default: break
            }
        }

        private func record(checked outcome: Session.InviteCheckOutcome) {
            switch outcome {
            case .usable: logger.info("invite check: usable")
            case .yours: logger.info("invite check: yours")
            case .alreadyIn: logger.info("invite check: already in")
            case .used: logger.info("invite check: used")
            case .expired: logger.info("invite check: expired")
            case .invalid: logger.info("invite check: invalid")
            case .offline: logger.info("invite check: offline, code kept")
            case .rateLimited: logger.info("invite check: rate limited, code kept")
            case .failed: logger.error("invite check: failed, code kept")
            case .unreadable: logger.error("invite check: unreadable answer, code kept")
            }
        }

        private func record(torn outcome: Session.InviteTearOutcome) {
            switch outcome {
            case .yours: logger.info("invite tear: yours")
            case .used: logger.info("invite tear: used by someone else")
            case .refused: logger.info("invite tear: refused, code dropped")
            case .offline: logger.info("invite tear: offline, code kept")
            case .rateLimited: logger.info("invite tear: rate limited, code kept")
            case .failed: logger.error("invite tear: failed, code kept")
            }
        }

        private func record(signedInWith provider: Session.Provider, isNew: Bool) {
            switch provider {
            case .apple: logger.info("signed in with apple, new account: \(isNew)")
            case .google: logger.info("signed in with google, new account: \(isNew)")
            case .unknown: logger.info("signed in with an unknown provider, new account: \(isNew)")
            }
        }

        private func record(_ failure: Session.RefreshFailure) {
            switch failure {
            case .offline: logger.info("session refresh failed: offline, credentials kept")
            case .timedOut: logger.info("session refresh failed: timed out, credentials kept")
            case .transport: logger.info("session refresh failed: transport, credentials kept")
            case .decoding: logger.error("session refresh failed: unreadable answer, credentials kept")
            case .rateLimited: logger.info("session refresh failed: rate limited, credentials kept")
            case .server: logger.error("session refresh failed: server error, credentials kept")
            case .other: logger.error("session refresh failed: unexpected answer, credentials kept")
            }
        }

        private func record(signedOut reason: Session.SignedOutReason, serverNotified: Bool) {
            switch reason {
            case .none: logger.info("signed out, server notified: \(serverNotified)")
            case .revoked: logger.info("signed out after revocation, server notified: \(serverNotified)")
            case .signedOut: logger.info("signed out by the person, server notified: \(serverNotified)")
            }
        }

        private func record(replayed path: Backend.PathTemplate) {
            switch path {
            case .meta: logger.info("401 on /v2/meta: refreshed and replayed once")
            case .diagnostics: logger.info("401 on /v2/diagnostics: refreshed and replayed once")
            case .entries: logger.info("401 on /v2/entries: refreshed and replayed once")
            case .authApple: logger.info("401 on /v2/auth/apple: refreshed and replayed once")
            case .authRefresh: logger.info("401 on /v2/auth/refresh: refreshed and replayed once")
            case .authSignout: logger.info("401 on /v2/auth/signout: refreshed and replayed once")
            case .access, .waitlist, .invitesCheck, .invitesRedeem, .invitesMine: record(replayedInvite: path)
            }
        }

        private func record(replayedInvite path: Backend.PathTemplate) {
            switch path {
            case .access: logger.info("401 on /v2/access: refreshed and replayed once")
            case .waitlist: logger.info("401 on /v2/waitlist: refreshed and replayed once")
            case .invitesCheck: logger.info("401 on /v2/invites/check: refreshed and replayed once")
            case .invitesRedeem: logger.info("401 on /v2/invites/redeem: refreshed and replayed once")
            case .invitesMine: logger.info("401 on /v2/invites/mine: refreshed and replayed once")
            case .meta, .diagnostics, .entries, .authApple, .authRefresh, .authSignout: break
            }
        }

        private func record(writeFailed item: Session.KeychainItem, status: OSStatus) {
            switch item {
            case .session: logger.error("session item write failed: keychain status \(status)")
            case .signedInBefore: logger.error("signed-in-before flag write failed: keychain status \(status)")
            case .mirror: logger.error("old client mirror write failed: keychain status \(status)")
            case .sessionClear: logger.error("session item delete failed: keychain status \(status)")
            case .pendingInvite: logger.error("pending invite item write failed: keychain status \(status)")
            }
        }

        private func record(legacy outcome: Platform.Bridges.LegacyRefresh) {
            switch outcome {
            case .refreshed: logger.info("old client 401: session refreshed, request retried")
            case .unavailable: logger.info("old client 401: refresh unavailable, nothing signed out")
            case .signedOut: logger.info("old client 401: session ended, signed out")
            }
        }

        private func record(_ operation: Store.OutboxOperation) {
            switch operation {
            case .entryCreate: logger.info("outbox: entry.create queued")
            case .unknown: logger.info("outbox: unknown operation queued")
            }
        }

        private func record(_ check: Session.InstallCheck) {
            switch check {
            case .alreadyDone: logger.debug("install check: already done")
            case .wipedLeftovers: logger.info("install check: fresh install, leftovers wiped")
            case .keptUpdate: logger.info("install check: update from the old app, nothing wiped")
            case .deferredUntilUnlock: logger.info("install check: deferred until the phone is unlocked")
            }
        }

        private func record(_ problem: Platform.LaunchOptions.Problem) {
            switch problem {
            case .unknownValue(.data): logger.error("launch option -Data: unknown value, using live")
            case .unknownValue(.environment): logger.error("launch option -Environment: unknown value, using production")
            case .unknownValue(.account): logger.error("launch option -Account: unknown value, ignored")
            case .missingValue(.data): logger.error("launch option -Data: no value, using live")
            case .missingValue(.environment): logger.error("launch option -Environment: no value, using production")
            case .missingValue(.account): logger.error("launch option -Account: no value, ignored")
            case .tooLong(.screen): logger.error("launch option -Screen: longer than 64 characters, ignored")
            case .tooLong(.state): logger.error("launch option -State: longer than 64 characters, ignored")
            case .accountNeedsStaging: logger.error("launch option -Account needs -Environment local or staging, ignored")
            }
        }
    }

    /// Keeps events in memory, in order. For tests and previews.
    final class Recorder: Platform.LogSink, @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [Event] = []

        init() {}

        var events: [Event] {
            lock.withLock { recorded }
        }

        func record(_ event: Event) {
            lock.withLock { recorded.append(event) }
        }
    }
}
