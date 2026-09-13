//
//  FeatureFlagStore.swift
//  Retrospect
//
//  Reads the per-user feature flags the backend resolves and returns in the
//  /auth/* response, and exposes them to the app.
//
//  The backend resolves flags with this precedence:
//      1. an explicit per-user override
//      2. the flag's default_enabled
//      3. false
//  and hands the app the SAME resolved map it used for that user's requests,
//  so client and server branch on identical values for a given session.
//
//  Flags FAIL CLOSED here too: an unknown key, a sign-out, a response with no
//  `flags` object, and every app launch before the first auth reply all read as
//  `false`. A flag turning itself on because something went wrong — or because
//  a stale value outlived the server's decision — is the one outcome this must
//  never produce.
//
//  NOT YET WIRED: RetrospectAPIClient holds uncommitted work in this branch and
//  could not be edited here. See the workstream summary for the three-line diff
//  (decode `accountType`/`flags` in SignInData, call `apply` in `signIn`, call
//  `reset` in `signOut`). Until that lands every `isEnabled` returns false,
//  which is the safe direction.
//

import Foundation
import Combine

// MARK: - Known flags

/// Flags seeded in supabase/migrations/005_account_type_and_flags.sql.
/// `isEnabled(_:)` also accepts a raw String, so a flag added server-side works
/// before it is listed here.
enum FeatureFlag: String, CaseIterable {
    /// Backend selects the v2 CBT insight-synthesis prompt for this user only.
    case insightSynthesisPromptV2 = "insight_synthesis_prompt_v2"
    /// Backend routes this user's pipeline runs at v2 agent behaviour.
    case pipelineAgentV2 = "pipeline_agent_v2"
}

// MARK: - Account type

enum RetrospectAccountType: String, Codable {
    case real
    case test

    /// Anything the server sends that we don't recognise is treated as a real
    /// account — the conservative reading, since `test` unlocks nothing.
    init(serverValue: String?) {
        self = RetrospectAccountType(rawValue: serverValue ?? "") ?? .real
    }
}

// MARK: - Store

/// Single source of truth for per-user feature flags on the client.
///
/// Usage:
///     if FeatureFlagStore.shared.isEnabled(.pipelineAgentV2) { ... }
///
/// Populated by handing it the raw body of an /auth/signin or /auth/refresh
/// response — see `apply(authResponseBody:)`.
final class FeatureFlagStore: ObservableObject {

    static let shared = FeatureFlagStore()

    /// The resolved map exactly as the server sent it.
    @Published private(set) var flags: [String: Bool] = [:]

    /// 'real' for every customer. 'test' marks a founder throwaway account that
    /// the backend keeps out of aggregate stats and batch spend.
    @Published private(set) var accountType: RetrospectAccountType = .real

    /// When the flags were last refreshed from an auth response.
    @Published private(set) var lastUpdated: Date?

    private let defaults: UserDefaults
    private let flagsKey = "retrospect.featureFlags"
    private let accountTypeKey = "retrospect.accountType"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
    }

    // MARK: Reading

    /// Whether a known flag is on. Absent, malformed, or unknown reads as `false`.
    func isEnabled(_ flag: FeatureFlag) -> Bool {
        isEnabled(flag.rawValue)
    }

    /// Whether a flag is on by raw key. Absent reads as `false`.
    func isEnabled(_ rawKey: String) -> Bool {
        flags[rawKey] == true
    }

    /// True only for accounts the backend marked `test`.
    var isTestAccount: Bool {
        accountType == .test
    }

    // MARK: Writing

    /// Absorb the flags the backend resolved for this user.
    ///
    /// Call from `RetrospectAPIClient.signIn` with the decoded `accountType`
    /// and `flags` fields of the /auth/* payload.
    func apply(flags newFlags: [String: Bool]?, accountType newAccountType: String?) {
        // A response carrying no `flags` key means "no flags resolved", i.e.
        // everything off — not "keep whatever we had".
        let resolved = newFlags ?? [:]
        let resolvedType = RetrospectAccountType(serverValue: newAccountType)

        // Always hop, never a `Thread.isMainThread` fast path: a synchronous
        // main-thread write could otherwise overtake an already-queued one and
        // land out of order — e.g. a reset() on sign-out running before a
        // background apply() that then restores the signed-out user's flags.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.flags = resolved
            if newAccountType != nil {
                self.accountType = resolvedType
            }
            self.lastUpdated = Date()
            self.persist()
        }
    }

    /// Clear on sign-out. The next user must never inherit the previous user's flags.
    func reset() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.flags = [:]
            self.accountType = .real
            self.lastUpdated = nil
            self.defaults.removeObject(forKey: self.flagsKey)
            self.defaults.removeObject(forKey: self.accountTypeKey)
        }
    }

    // MARK: Persistence

    private func persist() {
        defaults.set(flags, forKey: flagsKey)
        defaults.set(accountType.rawValue, forKey: accountTypeKey)
    }

    private func restore() {
        // Deliberately does NOT restore `flags`.
        //
        // Persisting the map would be friendlier on a cold launch, but it is
        // the one thing that can make a flag read `true` after the server has
        // turned it off — offline, or before the first auth round-trip, with no
        // bound on how stale the value is. Flags start empty (all off) every
        // launch and only turn on once the server says so in an /auth/* reply.
        //
        // accountType IS restored: it is a stable property of the account, and
        // its unknown value is `.real`, which unlocks nothing.
        accountType = RetrospectAccountType(serverValue: defaults.string(forKey: accountTypeKey))
    }
}
