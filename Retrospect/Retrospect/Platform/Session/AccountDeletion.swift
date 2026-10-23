import Foundation

extension Session {
    /// What a deletion did, for the screen (C50.1 #4 / C50.2).
    enum DeletionOutcome: Sendable, Equatable {
        /// The server has the account (202, or a dead token after sending): the phone is being erased.
        case deleted
        /// The person closed Apple's sheet: nothing was sent, nothing changes, no message.
        case cancelledAtApple
        /// No connection: nothing was asked, nothing was sent.
        case offline
        /// Nothing was erased; the dialog says why and "delete my account" works again.
        case failed(DeletionProblem)
    }

    /// Why a deletion didn't happen, in the words the dialog needs.
    enum DeletionProblem: Sendable, Equatable {
        /// Apple's sheet signed in with a different Apple account than this one: nothing was sent.
        case differentAppleAccount
        /// Apple couldn't give a code, or the server said the code wasn't this person's (`invalid_credentials`).
        case appleRefused
        /// The request went out but no answer came back: the server may or may not have it.
        case noAnswer
        /// The server answered no (409, 429, 5xx, anything else) or the phone couldn't keep the pending flag.
        case notNow
    }

    /// Why the server said no, logged by kind (never its message).
    enum DeletionFailure: Sendable, Equatable {
        case appleConfirmationRequired, appleRefused, unavailable, rateLimited, other
    }

    /// The deletion's log lines (`Platform.Log.Event.accountDeletion`): steps and kinds, never a code or a token.
    enum DeletionStep: Sendable, Equatable {
        case cancelledAtApple, differentAppleAccount, appleUnavailable, flagNotKept
        case refused(DeletionFailure)
        /// No answer after sending: the flag stays for the next launch.
        case unsure
        case underWay
        /// Everything on the phone is gone.
        case finished
        /// A launch found the flag and a session the server still accepts: the request never landed.
        case resumeCleared
        /// A launch found the flag but couldn't ask the server: kept for the next launch.
        case resumeKept
    }

    /// How the session treats its tokens while a deletion is in flight (`Manager.setDeletionHold`).
    enum DeletionHold: Sendable, Equatable {
        /// Normal.
        case none
        /// The request is out (or a launch is asking whether it landed): a 401 is never answered with a refresh,
        /// and a refresh the server refuses doesn't end the session (no "please sign in again" flash).
        case confirming
        /// The server has it: no token is handed out, so nothing more is sent, and nothing renews or ends.
        case held
    }

    /// Apple's fresh one-time code for this app, and the Apple account it belongs to.
    struct AppleCode: Sendable, Equatable {
        let code: String
        /// `ASAuthorizationAppleIDCredential.user`, compared with the signed-in session's.
        let user: String
    }

    /// Delete my account (PL3.7g.min), the sequence alone: every effect is a port, so tests drive it without Apple,
    /// a server or a phone. The platform builds the ports (`Platform.AppEnvironment.deleteAccount`).
    ///
    /// online? -> Apple's fresh code (cancel = nothing) -> the same Apple account? -> keep the pending flag ->
    /// hold the session -> `DELETE /v2/account` -> 202 / `session_revoked` = under way (a plain 401 is checked
    /// with one refresh first): hold everything and erase the phone; a refusal clears the flag and erases nothing;
    /// no answer or a 5xx keeps the flag for the next launch and erases nothing.
    struct AccountDeletion: Sendable {
        struct Ports: Sendable {
            var isOnline: @Sendable () async -> Bool
            /// The signed-in session's Apple account; nil when not known (then the server's own check decides).
            var signedInAppleUser: @Sendable () async -> String?
            /// Apple's sheet. Throws `SignInError.cancelled` when the person closes it.
            var freshAppleCode: @Sendable () async throws -> AppleCode
            /// Keeps the flag; false when it couldn't be kept (then nothing is sent).
            var markPending: @Sendable () async -> Bool
            var clearPending: @Sendable () async -> Void
            var hold: @Sendable (DeletionHold) async -> Void
            var send: @Sendable (_ appleCode: String) async throws -> Backend.AccountDeletion
            /// After a 401 `unauthenticated`: one refresh tells a locked account from a token that simply expired
            /// (checker m1 on #188: an expired token answers the same 401).
            var probe: @Sendable () async -> DeletionResume
            /// Stops and erases everything per-person on the phone (the store, outbox, media, diagnostics).
            var eraseLocal: @Sendable () async -> Void
            var log: @Sendable (DeletionStep) -> Void
        }

        let ports: Ports

        func run() async -> DeletionOutcome {
            guard await ports.isOnline() else { return .offline }
            let apple: AppleCode
            do {
                apple = try await ports.freshAppleCode()
            } catch SignInError.cancelled {
                ports.log(.cancelledAtApple)
                return .cancelledAtApple
            } catch {
                ports.log(.appleUnavailable)
                return .failed(.appleRefused)
            }
            if let expected = await ports.signedInAppleUser(), expected != apple.user {
                ports.log(.differentAppleAccount)
                return .failed(.differentAppleAccount)
            }
            guard await ports.markPending() else {
                ports.log(.flagNotKept)
                return .failed(.notNow)
            }
            await ports.hold(.confirming)
            do {
                _ = try await ports.send(apple.code)
                return await underWay()
            } catch let failure as Backend.Failure {
                return await answered(failure)
            } catch {
                // cancelled while out: whether the server heard is unknown, so the flag stays
                ports.log(.unsure)
                await ports.hold(.none)
                return .failed(.noAnswer)
            }
        }

        /// What a failure after sending means. `session_revoked` is the first request's own lock (QA #187); a plain
        /// 401 is checked with one refresh. No answer, or a 5xx (which can come after the server locked the account,
        /// checker m2 on #188), keeps the flag for the next launch's question.
        private func answered(_ failure: Backend.Failure) async -> DeletionOutcome {
            switch failure.kind {
            case .sessionRevoked:
                return await underWay()
            case .unauthenticated:
                return await afterProbe()
            case .offline, .timedOut, .transport, .decoding, .internal, .upstreamTimeout, .upstreamUnavailable:
                return await unsure()
            default:
                let refusal = Self.refusal(failure.kind)
                ports.log(.refused(refusal))
                await ports.clearPending()
                await ports.hold(.none)
                return .failed(refusal == .appleRefused ? .appleRefused : .notNow)
            }
        }

        /// The refresh after a 401: refused = the account is locked (under way); a new pair = the token had only
        /// expired and the request never reached the lock (flag cleared, nothing erased); no answer = unsure.
        private func afterProbe() async -> DeletionOutcome {
            switch await ports.probe() {
            case .finish:
                return await underWay()
            case .clear:
                ports.log(.resumeCleared)
                await ports.clearPending()
                await ports.hold(.none)
                return .failed(.notNow)
            case .keep:
                return await unsure()
            }
        }

        private func unsure() async -> DeletionOutcome {
            ports.log(.unsure)
            await ports.hold(.none)
            return .failed(.noAnswer)
        }

        private func underWay() async -> DeletionOutcome {
            await ports.hold(.held)
            ports.log(.underWay)
            await ports.eraseLocal()
            return .deleted
        }

        static func refusal(_ kind: Backend.Failure.Kind) -> DeletionFailure {
            switch kind {
            case .unknown(code: "apple_confirmation_required"): .appleConfirmationRequired
            case .invalidCredentials: .appleRefused
            case .rateLimited: .rateLimited
            case .upstreamUnavailable, .upstreamTimeout, .internal: .unavailable
            default: .other
            }
        }
    }

    /// What a launch with the pending flag set does, decided from the server's answer to `GET /v2/access`.
    enum DeletionResume: Sendable, Equatable {
        /// Nobody is signed in, or the server refused the session: finish the erase.
        case finish
        /// The server still accepts this session: the request never landed. Clear the flag, erase nothing.
        case clear
        /// The server couldn't be asked: keep the flag for the next launch.
        case keep

        /// The decision for a probe's result (nil = it answered 200).
        static func after(_ failure: Backend.Failure.Kind?) -> DeletionResume {
            switch failure {
            case nil: .clear
            // The lock bumps the token version and ends every refresh family, so a deleted account only ever
            // answers these two. `suspended` alone is a paused person whose request never landed: kept.
            case .unauthenticated?, .sessionRevoked?: .finish
            default: .keep
            }
        }
    }
}

// MARK: - The session's part

extension Session.Manager {
    /// How the tokens are treated while the account is being deleted (`Session.DeletionHold`).
    func setDeletionHold(_ hold: Session.DeletionHold) {
        deletionHold = hold
    }

    /// The signed-in session's Apple account, to compare with the one Apple's sheet answers for.
    var appleUserID: String? {
        get async { await signedInCredentials?.appleUserID }
    }

    /// Whether anyone is signed in on this phone now.
    var hasCredentials: Bool {
        get async { await signedInCredentials != nil }
    }

    /// Keeps the pending-deletion flag before the request goes out; false when the Keychain refused (then nothing is sent).
    func markDeletionPending() async -> Bool {
        do {
            try await store.markDeletionPending()
            return true
        } catch {
            return false
        }
    }

    /// The server never heard it: the flag goes and nothing is erased.
    func clearDeletionPending() async {
        try? await store.clearDeletionPending()
    }

    /// One refresh, under the deletion's hold (a refused refresh doesn't end the session here): `session_revoked` or a
    /// 401 means the account is locked; a new pair means it isn't (the 401 was only an expired token).
    func probeDeletion() async -> Session.DeletionResume {
        do {
            _ = try await refresh()
            return .clear
        } catch let failure as Backend.Failure {
            return .after(failure.kind)
        } catch {
            return .keep
        }
    }

    /// Whether a sent deletion waits to be finished on this phone; nil when the Keychain can't be read yet.
    var isDeletionPending: Bool? {
        get async { try? await store.isDeletionPending() }
    }
}

// MARK: - On the platform

extension Platform.AppEnvironment {
    /// "delete my account": Apple's fresh code, `DELETE /v2/account`, and on the 202 the person's store, outbox, media
    /// and diagnostics are erased at once while the session is held (nothing more is sent, nothing signs out under the
    /// goodbye). The session itself ends in `finishAccountDeletion`, after the goodbye.
    func deleteAccount(apple: any Session.AppleReauthorizing) async -> Session.DeletionOutcome {
        let session = session
        let client = client
        let reachability = reachability
        let log = log
        let deletion = Session.AccountDeletion(ports: .init(
            isOnline: { await reachability.isOnline },
            signedInAppleUser: { await session.appleUserID },
            freshAppleCode: { try await apple.freshCode() },
            markPending: { await session.markDeletionPending() },
            clearPending: { await session.clearDeletionPending() },
            hold: { await session.setDeletionHold($0) },
            send: { try await client.send(Backend.Endpoints.DeleteAccount(appleAuthorizationCode: $0)) },
            probe: { await session.probeDeletion() },
            eraseLocal: { [weak self] in await self?.eraseForDeletion() },
            log: { log.record(.accountDeletion($0)) }
        ))
        return await deletion.run()
    }

    /// After the goodbye (or at a launch that found the deletion under way): everything on the phone goes, the
    /// session included, deeper than Log Out (`hasSignedInBefore`, the pending invite and Apple's kept first
    /// authorization too), and the root shows the first-time splash.
    func finishAccountDeletion() async {
        await eraseForDeletion()
        if await session.endAfterDeletion() {
            log.record(.accountDeletion(.finished))
        }
        await pendingInvite.refresh()
    }

    /// At launch: a pending flag means a deletion was sent and the phone wasn't erased. Nobody signed in, or the
    /// server refusing the session, finishes it; a session the server still accepts means the request never landed
    /// (the flag goes, nothing is erased); no answer keeps the flag for the next launch.
    func resumeAccountDeletionIfPending() async {
        guard await session.isDeletionPending == true else { return }
        guard await session.hasCredentials else {
            await finishAccountDeletion()
            return
        }
        await session.setDeletionHold(.confirming)
        let decision: Session.DeletionResume
        do {
            _ = try await client.send(Backend.Endpoints.Access())
            decision = .after(nil)
        } catch let failure as Backend.Failure where failure.kind == .unauthenticated {
            decision = await session.probeDeletion() // an expired token answers 401 too (checker m1 on #188)
        } catch let failure as Backend.Failure {
            decision = .after(failure.kind)
        } catch {
            decision = .keep
        }
        switch decision {
        case .finish:
            await session.setDeletionHold(.held)
            await finishAccountDeletion()
        case .clear:
            await session.clearDeletionPending()
            await session.setDeletionHold(.none)
            log.record(.accountDeletion(.resumeCleared))
        case .keep:
            await session.setDeletionHold(.none)
            log.record(.accountDeletion(.resumeKept))
        }
    }
}
