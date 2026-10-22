import Foundation
import Security

extension Session {
    /// Where the session stands, as screens see it. Inside `.signedIn` the
    /// access token may be fresh, expiring, expired or refreshing; none of
    /// that is published.
    enum State: Sendable, Equatable {
        /// The phone hasn't been unlocked since it started (or the Keychain
        /// couldn't be read): nothing wiped, nothing read as signed out. Leaves
        /// on the first active scene, when the launch check and the read run again.
        case locked
        case signedOut(hasSignedInBefore: Bool, reason: SignedOutReason)
        case signedIn(userID: String, access: AccessState)
    }

    enum SignedOutReason: Sendable, Equatable {
        /// Never signed in on this install, or signed out before this process.
        case none
        /// The server ended the session: AC-1 says "please sign in again".
        case revoked
        /// The person signed out.
        case signedOut
    }

    enum SignOutResult: Sendable, Equatable {
        case signedOut
        /// Unsent entries exist and `force` was false: nothing changed.
        case hasUnsent(count: Int)
    }

    /// Why a refresh failed while the credentials were kept. Logged.
    enum RefreshFailure: Sendable, Equatable {
        case offline, timedOut, transport, decoding, rateLimited, server, other

        init(_ kind: Backend.Failure.Kind) {
            switch kind {
            case .offline: self = .offline
            case .timedOut: self = .timedOut
            case .transport: self = .transport
            case .decoding: self = .decoding
            case .rateLimited: self = .rateLimited
            case .internal, .upstreamTimeout, .upstreamUnavailable: self = .server
            default: self = .other
            }
        }
    }

    /// The session's Keychain writes that can fail without ending the session.
    enum KeychainItem: Sendable, Equatable {
        case session, signedInBefore, mirror, sessionClear
    }

    /// Apple's answer about the person's credential for this app.
    enum AppleCredentialState: Sendable, Equatable {
        case authorized
        /// Revoked or not found: the person removed the app from their Apple ID.
        case revoked
        /// Couldn't be checked now (an error, a timeout): ignored.
        case unknown
    }

    /// The one session: reads it at start, hands the client its token, renews
    /// it quietly (single flight, once per 401, before it expires, on every
    /// active scene), signs this device out, and publishes `State`. Exactly
    /// one per process, held by `Platform.AppEnvironment`.
    ///
    /// Clock skew: the server's clock is read from each sign-in and refresh
    /// answer (`accessTokenExpiresAt` − 15 min = the server's now), so a phone
    /// whose clock is off never refreshes on every request. A token received
    /// under 60 seconds ago on the monotonic clock is never refreshed early,
    /// whatever either clock says.
    actor Manager: Backend.TokenProviding, Installing {
        /// The access token's lifetime on the server (`ACCESS_TOKEN_TTL_SECONDS`).
        static let accessTokenLifetime: TimeInterval = 15 * 60
        /// Refresh before a request when the token ends within this.
        static let refreshAhead: TimeInterval = 60
        /// Never refresh early a token received less than this ago.
        static let freshFor: TimeInterval = 60

        private let store: Store
        private let mirror: any LegacyMirroring
        private let log: any Platform.LogSink
        private let now: @Sendable () -> Date
        private let uptime: @Sendable () -> TimeInterval
        private let unsentCount: @Sendable () async -> Int
        private let clearGate: @MainActor @Sendable () -> Void
        private let probeUnlock: @Sendable () -> UnlockProbe
        private let appleCredentialState: @Sendable (String) async -> AppleCredentialState
        private let connection = Platform.Box<Backend.Client?>(nil)

        private var launchCheck: InstallCheck?
        private var started = false
        private var credentials: Credentials?
        private var hasSignedInBefore = false
        private var current: State = .locked
        private var continuations: [UUID: AsyncStream<State>.Continuation] = [:]
        private var refreshTask: Task<Credentials, any Error>?
        /// Server now − device now, from the last answer. Zero until one arrives.
        private var skew: TimeInterval = 0
        private var receivedAt: TimeInterval?
        /// The pair in memory is newer than the one on disk: save again later.
        private var pendingSave = false
        private var signingOut = false

        init(
            store: Store,
            mirror: any LegacyMirroring,
            log: any Platform.LogSink,
            launchCheck: InstallCheck?,
            probeUnlock: @escaping @Sendable () -> UnlockProbe,
            clearGate: @escaping @MainActor @Sendable () -> Void,
            appleCredentialState: @escaping @Sendable (String) async -> AppleCredentialState,
            unsentCount: @escaping @Sendable () async -> Int = { 0 },
            now: @escaping @Sendable () -> Date = Date.init,
            uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
        ) {
            self.store = store
            self.mirror = mirror
            self.log = log
            self.launchCheck = launchCheck
            self.probeUnlock = probeUnlock
            self.clearGate = clearGate
            self.appleCredentialState = appleCredentialState
            self.unsentCount = unsentCount
            self.now = now
            self.uptime = uptime
        }

        /// The client this manager refreshes and signs out through. It can't
        /// be an init argument: the client takes the manager as its token
        /// provider, so the two are built and then joined.
        nonisolated func connect(_ client: Backend.Client) {
            connection.value = client
        }

        // MARK: State

        var state: State {
            get async {
                await ensureStarted()
                return current
            }
        }

        /// The current state first, then every change.
        nonisolated func states() -> AsyncStream<State> {
            let (stream, continuation) = AsyncStream.makeStream(of: State.self, bufferingPolicy: .unbounded)
            let id = UUID()
            Task { await self.add(continuation, id: id) }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.remove(id) }
            }
            return stream
        }

        // MARK: The scene

        /// The first active scene after launch, and every one after: finish a
        /// deferred launch check, read a locked session, check Apple hasn't
        /// revoked the credential, save what couldn't be saved, renew what's
        /// about to expire.
        func becameActive() async {
            if launchCheck == nil || launchCheck == .deferredUntilUnlock {
                launchCheck = await store.checkInstall(probe: probeUnlock, log: log)
                started = true
                guard launchCheck != nil, launchCheck != .deferredUntilUnlock else {
                    publish(.locked)
                    return
                }
                await read()
            } else {
                await ensureStarted()
                if case .locked = current {
                    await read()
                }
            }
            guard let credentials else { return }
            if credentials.provider == .apple, let appleUserID = credentials.appleUserID,
               await appleCredentialState(appleUserID) == .revoked {
                log.record(.appleCredentialRevoked)
                _ = await signOut(force: true)
                return
            }
            if pendingSave {
                await save(credentials)
            }
            await refreshIfNeeded()
        }

        /// Renews the token now if it ends within a minute. Failures are kept
        /// to the log; the next request surfaces them.
        func refreshIfNeeded() async {
            await ensureStarted()
            guard let credentials, refreshTask == nil, needsRefresh(credentials) else { return }
            _ = try? await refresh()
        }

        // MARK: Backend.TokenProviding

        func accessToken() async throws -> String {
            await ensureStarted()
            guard let credentials else { throw Backend.Failure(.unauthenticated) }
            if signingOut {
                return credentials.accessToken
            }
            if let refreshTask {
                return try await refreshTask.value.accessToken
            }
            if needsRefresh(credentials) {
                return try await refresh().accessToken
            }
            return credentials.accessToken
        }

        /// After a 401: a new token, through the one refresh in flight if there
        /// is one. A failed token older than the stored one means someone
        /// already refreshed: the stored one is returned without another refresh.
        func refreshAfterUnauthorized(failedToken: String) async throws -> String {
            await ensureStarted()
            guard let credentials, !signingOut else { throw Backend.Failure(.unauthenticated) }
            if credentials.accessToken != failedToken {
                return credentials.accessToken
            }
            return try await refresh().accessToken
        }

        // MARK: Sign-in (Installing)

        /// A new session from sign-in: the old family (if any) is told to end,
        /// best effort; then save, mirror, mark signed in before, publish. A
        /// save that fails throws, with nothing mirrored and nothing marked.
        func install(_ credentials: Credentials) async throws {
            await ensureStarted()
            if let old = self.credentials {
                _ = await notifyServer(signingOut: old)
            }
            try await store.save(credentials)
            adopt(credentials)
            pendingSave = false
            write(mirrorFor: credentials)
            do {
                try await store.markSignedInBefore()
            } catch let error as KeychainError {
                log.record(.keychainWriteFailed(.signedInBefore, status: error.status))
            }
            hasSignedInBefore = true
            publish(.signedIn(userID: credentials.userID, access: credentials.access))
        }

        /// A changed access state (an invite redeemed): kept with the session.
        func setAccess(_ access: AccessState) async {
            await ensureStarted()
            guard let credentials else { return }
            let updated = Credentials(
                accessToken: credentials.accessToken, accessTokenExpiresAt: credentials.accessTokenExpiresAt,
                refreshToken: credentials.refreshToken, userID: credentials.userID, access: access,
                firstName: credentials.firstName, provider: credentials.provider, appleUserID: credentials.appleUserID
            )
            self.credentials = updated
            await save(updated)
            publish(.signedIn(userID: updated.userID, access: access))
        }

        // MARK: Sign-out

        /// Signs this device out: the server is told (best effort, never
        /// retried, never queued), the session item goes, the mirror and the
        /// old sign-in gate are cleared. With unsent entries and `force`
        /// false, nothing changes. Already signed out is still signed out.
        func signOut(force: Bool) async -> SignOutResult {
            await ensureStarted()
            guard let credentials else { return .signedOut }
            if !force {
                let unsent = await unsentCount()
                if unsent > 0 {
                    return .hasUnsent(count: unsent)
                }
            }
            let notified = await notifyServer(signingOut: credentials)
            await endSession(reason: .signedOut, serverNotified: notified)
            return .signedOut
        }

        /// The old client's 401 (`Platform.Bridges.refreshLegacy`): refresh
        /// and re-mirror, or say why not.
        func refreshForLegacy() async -> Platform.Bridges.LegacyRefresh {
            await ensureStarted()
            let outcome: Platform.Bridges.LegacyRefresh
            if credentials == nil {
                outcome = .signedOut
            } else {
                do {
                    _ = try await refresh()
                    outcome = .refreshed
                } catch let failure as Backend.Failure where failure.kind == .sessionRevoked {
                    outcome = .signedOut
                } catch {
                    outcome = .unavailable
                }
            }
            log.record(.legacyRefresh(outcome))
            return outcome
        }

        // MARK: Reading

        private func ensureStarted() async {
            guard !started else { return }
            started = true
            if launchCheck == nil || launchCheck == .deferredUntilUnlock {
                publish(.locked)
                return
            }
            await read()
        }

        /// The stored session, or why it can't be read yet.
        private func read() async {
            do {
                let stored = try await store.credentials()
                hasSignedInBefore = try await store.hasSignedInBefore
                credentials = stored
                if let stored {
                    publish(.signedIn(userID: stored.userID, access: stored.access))
                } else {
                    publish(.signedOut(hasSignedInBefore: hasSignedInBefore, reason: .none))
                }
            } catch let error as KeychainError {
                log.record(.sessionLocked(status: error.status))
                publish(.locked)
            } catch {
                log.record(.sessionLocked(status: errSecInternalError))
                publish(.locked)
            }
        }

        // MARK: Refreshing

        /// Whether the token ends within `refreshAhead`, on the server's
        /// clock, unless it arrived under `freshFor` ago.
        private func needsRefresh(_ credentials: Credentials) -> Bool {
            if let receivedAt, uptime() - receivedAt < Self.freshFor {
                return false
            }
            let serverNow = now().addingTimeInterval(skew)
            return credentials.accessTokenExpiresAt.timeIntervalSince(serverNow) < Self.refreshAhead
        }

        /// One refresh at a time: every caller awaits the same task.
        private func refresh() async throws -> Credentials {
            if let refreshTask {
                return try await refreshTask.value
            }
            let task = Task { try await performRefresh() }
            refreshTask = task
            defer { refreshTask = nil }
            return try await task.value
        }

        /// `POST /v2/auth/refresh` with the stored refresh token, sent again
        /// once if the answer was dropped (never on a server code: a refused
        /// token is refused). A revoked or malformed token ends the session;
        /// anything else keeps the credentials and surfaces to the caller.
        private func performRefresh() async throws -> Credentials {
            guard let old = credentials else { throw Backend.Failure(.unauthenticated) }
            let client = try door()
            var attempt = 1
            while true {
                do {
                    let answer = try await client.send(Backend.Endpoints.Refresh(refreshToken: old.refreshToken))
                    return await adopt(answer, replacing: old)
                } catch let failure as Backend.Failure {
                    switch failure.kind {
                    case .sessionRevoked, .invalidRequest:
                        log.record(.sessionRevoked)
                        await endSession(reason: .revoked, serverNotified: false)
                        throw Backend.Failure(.sessionRevoked, message: failure.message)
                    case .timedOut, .transport, .decoding, .offline where attempt == 1:
                        log.record(.refreshRetried)
                        attempt += 1
                    default:
                        log.record(.refreshFailed(RefreshFailure(failure.kind)))
                        throw failure
                    }
                }
            }
        }

        /// The refreshed pair, unless the session changed meanwhile (a
        /// sign-out or a new sign-in): then the answer is dropped.
        private func adopt(_ answer: Backend.AuthResponse, replacing old: Credentials) async -> Credentials {
            let fresh = Credentials(
                accessToken: answer.accessToken, accessTokenExpiresAt: answer.accessTokenExpiresAt,
                refreshToken: answer.refreshToken, userID: answer.user.id, access: answer.access.state,
                firstName: answer.user.firstName, provider: old.provider, appleUserID: old.appleUserID
            )
            guard credentials?.refreshToken == old.refreshToken else { return fresh }
            adopt(fresh)
            await save(fresh)
            write(mirrorFor: fresh)
            log.record(.refreshed)
            publish(.signedIn(userID: fresh.userID, access: fresh.access))
            return fresh
        }

        /// Takes a pair into memory and reads the server's clock from it.
        private func adopt(_ fresh: Credentials) {
            credentials = fresh
            skew = fresh.accessTokenExpiresAt.addingTimeInterval(-Self.accessTokenLifetime).timeIntervalSince(now())
            receivedAt = uptime()
        }

        // MARK: Writing

        /// Saves the pair; a failure is logged and tried again on the next
        /// refresh or active scene (the stored token is in grace for 30 s).
        private func save(_ credentials: Credentials) async {
            do {
                try await store.save(credentials)
                pendingSave = false
            } catch let error as KeychainError {
                pendingSave = true
                log.record(.keychainWriteFailed(.session, status: error.status))
            } catch {
                pendingSave = true
                log.record(.keychainWriteFailed(.session, status: errSecInternalError))
            }
        }

        private func write(mirrorFor credentials: Credentials) {
            do {
                try mirror.write(accessToken: credentials.accessToken, userID: credentials.userID, appleUserID: credentials.appleUserID)
            } catch let error as KeychainError {
                log.record(.keychainWriteFailed(.mirror, status: error.status))
            } catch {
                log.record(.keychainWriteFailed(.mirror, status: errSecInternalError))
            }
        }

        private func notifyServer(signingOut credentials: Credentials) async -> Bool {
            guard let client = try? door() else { return false }
            signingOut = true
            defer { signingOut = false }
            do {
                _ = try await client.send(Backend.Endpoints.SignOut(refreshToken: credentials.refreshToken))
                return true
            } catch {
                return false
            }
        }

        private func endSession(reason: SignedOutReason, serverNotified: Bool) async {
            credentials = nil
            pendingSave = false
            receivedAt = nil
            do {
                try await store.clearCredentials()
            } catch let error as KeychainError {
                log.record(.keychainWriteFailed(.sessionClear, status: error.status))
            } catch {
                log.record(.keychainWriteFailed(.sessionClear, status: errSecInternalError))
            }
            do {
                try mirror.clear()
            } catch let error as KeychainError {
                log.record(.keychainWriteFailed(.mirror, status: error.status))
            } catch {
                log.record(.keychainWriteFailed(.mirror, status: errSecInternalError))
            }
            await clearGate()
            log.record(.signedOut(reason: reason, serverNotified: serverNotified))
            publish(.signedOut(hasSignedInBefore: hasSignedInBefore, reason: reason))
        }

        private func door() throws -> Backend.Client {
            guard let client = connection.value else {
                log.record(.sessionNotConnected)
                throw Backend.Failure(.transport)
            }
            return client
        }

        // MARK: Publishing

        private func publish(_ state: State) {
            guard state != current else { return }
            current = state
            continuations.values.forEach { $0.yield(state) }
        }

        private func add(_ continuation: AsyncStream<State>.Continuation, id: UUID) async {
            await ensureStarted()
            continuations[id] = continuation
            continuation.yield(current)
        }

        private func remove(_ id: UUID) {
            continuations[id] = nil
        }
    }
}
