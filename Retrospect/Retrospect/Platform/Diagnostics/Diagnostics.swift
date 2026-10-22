import Foundation

extension Platform {
    /// What the app did in the person's recent sessions, kept on the phone for
    /// "send a report" (docs/team/flows/diagnostics.md). Every record is ids
    /// from closed lists, numbers, booleans and times: the types can't carry
    /// entry words, a name, a search or an email. The lists are the backend's
    /// (`fixtures/00/diagnostics.ids.json`); a test holds them equal.
    enum Diagnostics {}
}

// MARK: - The closed lists

extension Platform.Diagnostics {
    /// A screen the report may name: Beta 1's screens, the old ones as one id each.
    enum Screen: String, CaseIterable, Codable, Sendable {
        case signIn = "sign_in"
        case inviteGate = "invite_gate"
        case waitlist
        case youreIn = "youre_in"
        case updateRequired = "update_required"
        case journal, brief, entries, entry, settings
        case legacyOnboarding = "legacy.onboarding"
        case legacyPodcasts = "legacy.podcasts"
        case legacyGoals = "legacy.goals"
        case legacyYou = "legacy.you"
        case legacySettings = "legacy.settings"
    }

    enum Sheet: String, CaseIterable, Codable, Sendable {
        case player
        case messageMenu = "message_menu"
        case sendReport = "send_report"
        case shareInvite = "share_invite"
    }

    /// A named control: its id, never its text.
    enum Control: String, CaseIterable, Codable, Sendable {
        case signInApple = "sign_in.apple"
        case inviteRedeem = "invite.redeem"
        case inviteJoinWaitlist = "invite.join_waitlist"
        case youreInBegin = "youre_in.begin"
        case updateOpenStore = "update.open_store"
        case composerSend = "composer.send"
        case composerMicStart = "composer.mic_start"
        case composerMicStop = "composer.mic_stop"
        case composerMicCancel = "composer.mic_cancel"
        case messageRetry = "message.retry"
        case messageMenu = "message.menu"
        case briefPlay = "brief.play"
        case briefPause = "brief.pause"
        case briefSkipBack = "brief.skip_back"
        case briefSkipForward = "brief.skip_forward"
        case briefScrub = "brief.scrub"
        case briefEnable = "brief.enable"
        case guessRight = "guess.right"
        case guessNotQuite = "guess.not_quite"
        case drawerOpen = "drawer.open"
        case drawerClose = "drawer.close"
        case entriesOpenEntry = "entries.open_entry"
        case entryBack = "entry.back"
        case settingsOpen = "settings.open"
        case reportOpen = "report.open"
        case reportSend = "report.send"
        case reportShakeSwitch = "report.shake_switch"
        case stateTryAgain = "state.try_again"
    }

    enum Permission: String, CaseIterable, Codable, Sendable {
        case microphone, notifications, health, calendar, photos, contacts, speech
    }

    /// A `Flows.Failure` kind, as the report names it.
    enum FailureKind: String, CaseIterable, Codable, Sendable {
        case network, server
        case notFound = "not_found"
        case rateLimited = "rate_limited"
        case spendLimited = "spend_limited"
        case updateRequired = "update_required"
        case signedOut = "signed_out"
        case inviteRequired = "invite_required"
        case suspended
        case invalidCredentials = "invalid_credentials"
        case inviteInvalid = "invite_invalid"
        case inviteUsed = "invite_used"
        case inviteExpired = "invite_expired"
        case invalid, unknown
    }

    /// Contract 00 §2's error codes (and §4's invite codes): the only codes a
    /// network record may carry. A code outside the list is recorded as none.
    enum ErrorCode: String, CaseIterable, Codable, Sendable {
        case invalidRequest = "invalid_request"
        case invalidCredentials = "invalid_credentials"
        case unauthenticated
        case sessionRevoked = "session_revoked"
        case inviteRequired = "invite_required"
        case suspended
        case notFound = "not_found"
        case idempotencyMismatch = "idempotency_mismatch"
        case updateRequired = "update_required"
        case rateLimited = "rate_limited"
        case spendLimited = "spend_limited"
        case upstreamTimeout = "upstream_timeout"
        case upstreamUnavailable = "upstream_unavailable"
        case `internal`
        case inviteInvalid = "invite_invalid"
        case inviteUsed = "invite_used"
        case inviteExpired = "invite_expired"
    }

    /// Every `/v2` route a report may name, as templates: the backend's closed
    /// list (`fixtures/00/diagnostics.ids.json`; a test holds them equal).
    /// `Backend.PathTemplate` is the subset the app calls so far.
    enum Route: String, CaseIterable, Codable, Sendable {
        case access = "/v2/access"
        case authApple = "/v2/auth/apple"
        case authGoogle = "/v2/auth/google"
        case authRefresh = "/v2/auth/refresh"
        case authSignout = "/v2/auth/signout"
        case briefs = "/v2/briefs"
        case briefsEnabled = "/v2/briefs/enabled"
        case briefsLatest = "/v2/briefs/latest"
        case conversation = "/v2/conversation"
        case conversationStream = "/v2/conversation/stream"
        case corrections = "/v2/corrections"
        case correctionsConfirm = "/v2/corrections/confirm"
        case devices = "/v2/devices"
        case devicesByToken = "/v2/devices/:token"
        case diagnostics = "/v2/diagnostics"
        case entitlement = "/v2/entitlement"
        case entries = "/v2/entries"
        case entriesById = "/v2/entries/:id"
        case entriesByIdTook = "/v2/entries/:id/took"
        case entriesToday = "/v2/entries/today"
        case episodesById = "/v2/episodes/:id"
        case episodesJobs = "/v2/episodes/jobs"
        case episodesJobsById = "/v2/episodes/jobs/:id"
        case episodesJobsFirst = "/v2/episodes/jobs/first"
        case goals = "/v2/goals"
        case guesses = "/v2/guesses"
        case guessesById = "/v2/guesses/:id"
        case guessesByIdWhy = "/v2/guesses/:id/why"
        case invitesCheck = "/v2/invites/check"
        case invitesMine = "/v2/invites/mine"
        case invitesRedeem = "/v2/invites/redeem"
        case knowsYou = "/v2/knows-you"
        case meta = "/v2/meta"
        case onboardingAnswers = "/v2/onboarding/answers"
        case onboardingComplete = "/v2/onboarding/complete"
        case onboardingGoals = "/v2/onboarding/goals"
        case sources = "/v2/sources"
        case sourcesByIdConnect = "/v2/sources/:id/connect"
        case waitlist = "/v2/waitlist"

        init(_ path: Backend.PathTemplate) {
            self = switch path {
            case .meta: .meta
            }
        }
    }

    enum Idempotency: String, CaseIterable, Codable, Sendable {
        case new, replayed
    }

    enum CrashKind: String, CaseIterable, Codable, Sendable {
        case crash, hang
    }
}

// MARK: - The records

extension Platform.Diagnostics {
    /// One thing that happened in the app, in the report's own shape
    /// (`{"kind":"screen_shown","screen":"journal"}`).
    enum Event: Equatable, Sendable {
        case appLaunch
        case appForeground
        case appBackground
        case screenShown(Screen)
        case screenLeft(Screen)
        case controlTapped(Control, on: Screen)
        case sheetOpened(Sheet)
        case sheetClosed(Sheet)
        /// A playback item's id (an episode or brief id), never its title.
        case playbackStarted(itemID: UUID, positionMs: Int)
        case playbackPaused(itemID: UUID, positionMs: Int)
        case playbackEnded(itemID: UUID, positionMs: Int)
        case permissionPrompted(Permission)
        case permissionAnswered(Permission, granted: Bool)

        enum Kind: String, CaseIterable, Codable, Sendable {
            case appLaunch = "app_launch"
            case appForeground = "app_foreground"
            case appBackground = "app_background"
            case screenShown = "screen_shown"
            case screenLeft = "screen_left"
            case controlTapped = "control_tapped"
            case sheetOpened = "sheet_opened"
            case sheetClosed = "sheet_closed"
            case playbackStarted = "playback_started"
            case playbackPaused = "playback_paused"
            case playbackEnded = "playback_ended"
            case permissionPrompted = "permission_prompted"
            case permissionAnswered = "permission_answered"
        }

        var kind: Kind {
            switch self {
            case .appLaunch: .appLaunch
            case .appForeground: .appForeground
            case .appBackground: .appBackground
            case .screenShown: .screenShown
            case .screenLeft: .screenLeft
            case .controlTapped: .controlTapped
            case .sheetOpened: .sheetOpened
            case .sheetClosed: .sheetClosed
            case .playbackStarted: .playbackStarted
            case .playbackPaused: .playbackPaused
            case .playbackEnded: .playbackEnded
            case .permissionPrompted: .permissionPrompted
            case .permissionAnswered: .permissionAnswered
            }
        }
    }

    /// One request: its route template (`/v2/entries/:id`), never the URL.
    struct Request: Codable, Equatable, Sendable {
        var method: Backend.Method
        var route: Route
        /// 0 when nothing came back.
        var status: Int
        var code: ErrorCode?
        var ms: Int
        var retries: Int
        var idempotency: Idempotency?

        init(method: Backend.Method, route: Route, status: Int, code: ErrorCode? = nil, ms: Int, retries: Int = 0, idempotency: Idempotency? = nil) {
            self.method = method
            self.route = route
            self.status = status
            self.code = code
            self.ms = ms
            self.retries = retries
            self.idempotency = idempotency
        }
    }

    /// A failure a screen was told about; `screen` is nil for one in the background.
    struct Failure: Codable, Equatable, Sendable {
        var code: FailureKind
        var screen: Screen?

        init(code: FailureKind, screen: Screen? = nil) {
            self.code = code
            self.screen = screen
        }
    }

    struct Crash: Codable, Equatable, Sendable {
        var kind: CrashKind

        init(kind: CrashKind) {
            self.kind = kind
        }
    }

    /// Anything the recorder keeps. Each case goes to its own ring.
    enum Record: Equatable, Sendable {
        case event(Event)
        case request(Request)
        case failure(Failure)
        case crash(Crash)

        var ring: Ring {
            switch self {
            case .event: .events
            case .request: .network
            case .failure: .failures
            case .crash: .crashes
            }
        }
    }

    /// The four parts of a report that are lists, each with the most rows the
    /// server accepts (DG.1's schema). The recorder keeps at most `cap` rows
    /// of each, so a bundle built from the rings can never be refused for
    /// size, and a busy kind (requests) never pushes out a rare one (crashes).
    enum Ring: String, CaseIterable, Codable, Sendable {
        case events, network, failures, crashes

        var cap: Int {
            switch self {
            case .events, .network: 2000
            case .failures: 500
            case .crashes: 100
            }
        }
    }

    /// A record with when it happened, in the report's shape: `t` beside the
    /// record's own fields.
    struct Stamped<Body: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
        var at: Date
        var body: Body

        init(at: Date, body: Body) {
            self.at = at
            self.body = body
        }

        private enum CodingKeys: String, CodingKey {
            case at = "t"
        }

        init(from decoder: any Decoder) throws {
            at = try decoder.container(keyedBy: CodingKeys.self).decode(Date.self, forKey: .at)
            body = try Body(from: decoder)
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(at, forKey: .at)
            try body.encode(to: encoder)
        }
    }
}

extension Platform.Diagnostics.Event: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, screen, control, sheet, itemId, positionMs, permission, granted
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .appLaunch: self = .appLaunch
        case .appForeground: self = .appForeground
        case .appBackground: self = .appBackground
        case .screenShown, .screenLeft:
            let screen = try container.decode(Platform.Diagnostics.Screen.self, forKey: .screen)
            self = kind == .screenShown ? .screenShown(screen) : .screenLeft(screen)
        case .controlTapped:
            self = try .controlTapped(
                container.decode(Platform.Diagnostics.Control.self, forKey: .control),
                on: container.decode(Platform.Diagnostics.Screen.self, forKey: .screen)
            )
        case .sheetOpened, .sheetClosed:
            let sheet = try container.decode(Platform.Diagnostics.Sheet.self, forKey: .sheet)
            self = kind == .sheetOpened ? .sheetOpened(sheet) : .sheetClosed(sheet)
        case .playbackStarted, .playbackPaused, .playbackEnded:
            self = try Self.playback(kind, from: container)
        case .permissionPrompted, .permissionAnswered:
            self = try Self.permission(kind, from: container)
        }
    }

    /// `kind` is one of the three playback kinds; the caller's switch guarantees it.
    private static func playback(_ kind: Kind, from container: KeyedDecodingContainer<CodingKeys>) throws -> Self {
        let itemID = try container.decode(UUID.self, forKey: .itemId)
        let positionMs = try container.decode(Int.self, forKey: .positionMs)
        switch kind {
        case .playbackPaused: return .playbackPaused(itemID: itemID, positionMs: positionMs)
        case .playbackEnded: return .playbackEnded(itemID: itemID, positionMs: positionMs)
        default: return .playbackStarted(itemID: itemID, positionMs: positionMs)
        }
    }

    /// `kind` is one of the two permission kinds; the caller's switch guarantees it.
    private static func permission(_ kind: Kind, from container: KeyedDecodingContainer<CodingKeys>) throws -> Self {
        let permission = try container.decode(Platform.Diagnostics.Permission.self, forKey: .permission)
        if kind == .permissionPrompted {
            return .permissionPrompted(permission)
        }
        return try .permissionAnswered(permission, granted: container.decode(Bool.self, forKey: .granted))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .appLaunch, .appForeground, .appBackground:
            break
        case let .screenShown(screen), let .screenLeft(screen):
            try container.encode(screen, forKey: .screen)
        case let .controlTapped(control, screen):
            try container.encode(control, forKey: .control)
            try container.encode(screen, forKey: .screen)
        case let .sheetOpened(sheet), let .sheetClosed(sheet):
            try container.encode(sheet, forKey: .sheet)
        case let .playbackStarted(itemID, positionMs), let .playbackPaused(itemID, positionMs), let .playbackEnded(itemID, positionMs):
            try container.encode(itemID.uuidString.lowercased(), forKey: .itemId)
            try container.encode(positionMs, forKey: .positionMs)
        case let .permissionPrompted(permission):
            try container.encode(permission, forKey: .permission)
        case let .permissionAnswered(permission, granted):
            try container.encode(permission, forKey: .permission)
            try container.encode(granted, forKey: .granted)
        }
    }
}

/// The report writes a request's method as the contract spells it.
extension Backend.Method: Codable {}

extension Flows.Failure.Kind {
    /// The failure as a report names it.
    var diagnosticsKind: Platform.Diagnostics.FailureKind {
        switch self {
        case .network: .network
        case .server: .server
        case .notFound: .notFound
        case .rateLimited: .rateLimited
        case .spendLimited: .spendLimited
        case .updateRequired: .updateRequired
        case .signedOut: .signedOut
        case .inviteRequired: .inviteRequired
        case .suspended: .suspended
        case .invalidCredentials: .invalidCredentials
        case .inviteInvalid: .inviteInvalid
        case .inviteUsed: .inviteUsed
        case .inviteExpired: .inviteExpired
        case .invalid: .invalid
        case .unknown: .unknown
        }
    }
}

extension Backend.Failure.Kind {
    /// The contract code behind a backend failure; nil for a failure on the
    /// phone's side (offline, timed out, decoding, transport) and for a code
    /// outside the contract's list.
    var diagnosticsCode: Platform.Diagnostics.ErrorCode? {
        switch self {
        case .invalidRequest: .invalidRequest
        case .invalidCredentials: .invalidCredentials
        case .unauthenticated: .unauthenticated
        case .sessionRevoked: .sessionRevoked
        case .inviteRequired: .inviteRequired
        case .suspended: .suspended
        case .notFound: .notFound
        case .idempotencyMismatch: .idempotencyMismatch
        case .updateRequired: .updateRequired
        case .rateLimited: .rateLimited
        case .spendLimited: .spendLimited
        case .upstreamTimeout: .upstreamTimeout
        case .upstreamUnavailable: .upstreamUnavailable
        case .internal: .internal
        case .inviteInvalid: .inviteInvalid
        case .inviteUsed: .inviteUsed
        case .inviteExpired: .inviteExpired
        case .offline, .timedOut, .decoding, .transport, .unknown: nil
        }
    }
}
