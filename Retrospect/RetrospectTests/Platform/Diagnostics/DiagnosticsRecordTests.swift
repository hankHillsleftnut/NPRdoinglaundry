import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct DiagnosticsRecordTests {
    typealias Diagnostics = Platform.Diagnostics

    private struct Ids: Decodable {
        let routes: [String]
        let screens: [String]
        let sheets: [String]
        let controls: [String]
        let failures: [String]
    }

    private struct Report: Decodable {
        let events: [Diagnostics.Stamped<Diagnostics.Event>]
        let network: [Diagnostics.Stamped<Diagnostics.Request>]
        let failures: [Diagnostics.Stamped<Diagnostics.Failure>]
        let crashes: [Diagnostics.Stamped<Diagnostics.Crash>]
    }

    // MARK: No content

    @Test("no diagnostics record can hold text, data or a URL")
    func noRecordCanHoldContent() {
        for record in Diagnostics.Record.everyCase {
            #expect(ContentCheck.values(in: record).isEmpty, "\(record) carries content")
        }
    }

    @Test("the no-content check catches a record that carries text")
    func theNoContentCheckCatchesText() {
        enum Leaky {
            case words(String)
            case nested(count: Int, inner: [Substring])
        }
        #expect(ContentCheck.values(in: Leaky.words("invented")).count == 1)
        #expect(ContentCheck.values(in: Leaky.nested(count: 1, inner: ["invented"])).count == 1)
        #expect(ContentCheck.values(in: Diagnostics.Record.event(.appLaunch)).isEmpty)
    }

    @Test("the samples cover every event kind, once")
    func theSamplesCoverEveryEventKind() {
        let kinds = Diagnostics.Event.everyCase.map(\.kind)
        #expect(kinds.count == Diagnostics.Event.Kind.allCases.count)
        #expect(Set(kinds) == Set(Diagnostics.Event.Kind.allCases))
    }

    // MARK: The closed lists are the backend's

    @Test("the screens, sheets, controls and failures are exactly the fixture's lists")
    func theListsAreTheFixtures() throws {
        let ids = try JSONDecoder.contract.decode(Ids.self, from: Fixtures.data("00", "diagnostics.ids"))

        #expect(Set(Diagnostics.Screen.allCases.map(\.rawValue)) == Set(ids.screens))
        #expect(Set(Diagnostics.Sheet.allCases.map(\.rawValue)) == Set(ids.sheets))
        #expect(Set(Diagnostics.Control.allCases.map(\.rawValue)) == Set(ids.controls))
        #expect(Set(Diagnostics.FailureKind.allCases.map(\.rawValue)) == Set(ids.failures))
        #expect(Set(Diagnostics.Route.allCases.map(\.rawValue)) == Set(ids.routes))
        #expect(Diagnostics.Screen.allCases.count == ids.screens.count)
        #expect(Diagnostics.Control.allCases.count == ids.controls.count)
        #expect(Diagnostics.Route.allCases.count == ids.routes.count)
    }

    @Test("every door the app calls has its diagnostics route")
    func everyPathTemplateHasARoute() {
        // The signed-out preview (outside `/v2`) and the account door (records nothing): a report never names them.
        for path in Backend.PathTemplate.allCases where !Backend.unrecordedPaths.contains(path) {
            #expect(Diagnostics.Route(path).rawValue == path.rawValue)
        }
    }

    /// FR.doors: the backend refuses a whole report naming a route outside its list, so these four must be recorded
    /// under their own route; first run's screens and controls are in the closed lists too.
    @Test("the first-run and podcasts doors are recorded under their own routes, and first run's screens and controls are listed")
    func theFirstRunDoorsAreRecorded() {
        let doors: [Backend.PathTemplate: Diagnostics.Route] = [
            .podcasts: .podcasts, .episodeByID: .episodesById, .onboardingAnswers: .onboardingAnswers, .onboardingComplete: .onboardingComplete,
        ]
        for (door, route) in doors {
            #expect(!Backend.unrecordedPaths.contains(door), "\(door.rawValue) must be recorded")
            #expect(Diagnostics.Route(door) == route)
        }
        #expect(Diagnostics.Screen(rawValue: "first_run") == .firstRun && Diagnostics.Screen(rawValue: "first_episode") == .firstEpisode)
        #expect([Diagnostics.Control.firstRunSend, .firstEpisodePlay, .firstEpisodeContinue].map(\.rawValue) == [
            "first_run.send", "first_episode.play", "first_episode.continue",
        ])
    }

    @Test("every error code a request may carry is a contract 00 error fixture, and every error fixture is a code")
    func theErrorCodesAreTheErrorFixtures() throws {
        let fixtures = try FileManager.default.contentsOfDirectory(atPath: Fixtures.root.appendingPathComponent("00").path)
            .filter { $0.hasPrefix("error.") && $0.hasSuffix(".json") }
            .map { String($0.dropFirst("error.".count).dropLast(".json".count)) }

        #expect(Set(Diagnostics.ErrorCode.allCases.map(\.rawValue)) == Set(fixtures))
    }

    @Test("every event kind the backend accepts is one the app can record")
    func theEventKindsAreTheBackends() {
        let backend: Set = [
            "app_launch", "app_foreground", "app_background", "screen_shown", "screen_left", "control_tapped",
            "sheet_opened", "sheet_closed", "playback_started", "playback_paused", "playback_ended",
            "permission_prompted", "permission_answered",
        ]
        #expect(Set(Diagnostics.Event.Kind.allCases.map(\.rawValue)) == backend)
    }

    // MARK: Mapping from the app's failures

    @Test("every flow failure kind maps to a diagnostic failure id")
    func everyFlowFailureKindMaps() {
        let kinds: [Flows.Failure.Kind] = [
            .network, .server, .notFound, .rateLimited(retryAfterSeconds: 3), .spendLimited(retryAfterSeconds: nil), .updateRequired,
            .signedOut, .inviteRequired, .suspended, .invalidCredentials, .inviteInvalid, .inviteUsed, .inviteExpired, .invalid, .unknown,
        ]
        let mapped = kinds.map(\.diagnosticsKind)
        #expect(Set(mapped).count == kinds.count, "two flow kinds share a diagnostic id")
        #expect(Set(mapped) == Set(Diagnostics.FailureKind.allCases))
    }

    @Test("a backend failure maps to its contract code; a phone-side or unknown failure maps to none")
    func backendFailuresMapToCodes() {
        #expect(Backend.Failure.Kind.upstreamTimeout.diagnosticsCode == .upstreamTimeout)
        #expect(Backend.Failure.Kind.rateLimited(retryAfter: .seconds(1)).diagnosticsCode == .rateLimited)
        #expect(Backend.Failure.Kind.inviteExpired.diagnosticsCode == .inviteExpired)
        #expect(Backend.Failure.Kind.offline.diagnosticsCode == nil)
        #expect(Backend.Failure.Kind.timedOut.diagnosticsCode == nil)
        #expect(Backend.Failure.Kind.decoding.diagnosticsCode == nil)
        #expect(Backend.Failure.Kind.unknown(code: "invented").diagnosticsCode == nil)
        let backendCodes = Set(Backend.Failure.Kind.everyBackendCase.compactMap(\.diagnosticsCode))
        #expect(backendCodes == Set(Diagnostics.ErrorCode.allCases), "every contract code has a backend failure that maps to it")
    }

    // MARK: The report's shape

    @Test("the contract fixture's events, requests, failures and crashes decode and encode back to the same JSON")
    func theFixtureRoundTrips() throws {
        let bytes = try Fixtures.data("00", "diagnostics.request")
        let report = try JSONDecoder.contract.decode(Report.self, from: bytes)
        let fixture = try #require(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])

        #expect(try report.events.map(\.body) == [
            .appForeground, .screenShown(.journal), .controlTapped(.briefPlay, on: .journal),
            .playbackStarted(itemID: #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")), positionMs: 0),
            .playbackPaused(itemID: #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")), positionMs: 125_000),
        ])
        #expect(report.network.map(\.body) == [
            Diagnostics.Request(method: .get, route: .briefsLatest, status: 200, ms: 340, retries: 0),
            Diagnostics.Request(method: .get, route: .briefsLatest, status: 504, code: .upstreamTimeout, ms: 30000, retries: 1),
        ])
        #expect(report.failures.map(\.body) == [Diagnostics.Failure(code: .server, screen: .journal)])
        #expect(report.crashes.isEmpty)

        let parts: [(String, any Encodable)] = [("events", report.events), ("network", report.network), ("failures", report.failures)]
        for (key, value) in parts {
            let back = try JSONSerialization.jsonObject(with: Backend.Coding.encoder.encode(value)) as? NSArray
            #expect(back == fixture[key] as? NSArray, "\(key)")
        }
    }

    @Test("a stamped record writes its time as t beside its own fields, and reads it back")
    func aStampedRecordWritesT() throws {
        let stamped = Diagnostics.Stamped(at: Date(timeIntervalSince1970: 1_792_569_604.2), body: Diagnostics.Crash(kind: .hang))

        let json = try #require(String(data: Backend.Coding.encoder.encode(stamped), encoding: .utf8))
        let back = try JSONDecoder.contract.decode(Diagnostics.Stamped<Diagnostics.Crash>.self, from: Data(json.utf8))

        #expect(json == #"{"kind":"hang","t":"2026-10-21T08:00:04.200Z"}"#)
        #expect(back == stamped)
    }

    @Test("every event encodes to its kind and only the fields it carries, and decodes back", arguments: Diagnostics.Event.everyCase)
    func everyEventRoundTrips(_ event: Diagnostics.Event) throws {
        let bytes = try Backend.Coding.encoder.encode(event)
        let object = try #require(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])

        #expect(object["kind"] as? String == event.kind.rawValue)
        #expect(try JSONDecoder.contract.decode(Diagnostics.Event.self, from: bytes) == event)
        let expectedKeys: Set<String> = switch event {
        case .appLaunch, .appForeground, .appBackground: ["kind"]
        case .screenShown, .screenLeft: ["kind", "screen"]
        case .controlTapped: ["kind", "screen", "control"]
        case .sheetOpened, .sheetClosed: ["kind", "sheet"]
        case .playbackStarted, .playbackPaused, .playbackEnded: ["kind", "itemId", "positionMs"]
        case .permissionPrompted: ["kind", "permission"]
        case .permissionAnswered: ["kind", "permission", "granted"]
        }
        #expect(Set(object.keys) == expectedKeys)
    }

    @Test("a playback item id is written lowercase, as every id the app sends")
    func aPlaybackItemIDIsLowercase() throws {
        let id = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000B1"))
        let bytes = try Backend.Coding.encoder.encode(Diagnostics.Event.playbackEnded(itemID: id, positionMs: 1))
        #expect(try #require(String(data: bytes, encoding: .utf8)).contains("00000000-0000-4000-8000-0000000000b1"))
    }

    @Test("an event of a kind this build doesn't know doesn't decode")
    func anUnknownEventKindDoesntDecode() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder.contract.decode(Diagnostics.Event.self, from: Data(#"{"kind":"teleported"}"#.utf8))
        }
    }

    @Test("a request without a code, retries or idempotency omits them, as the door requires")
    func aRequestOmitsAbsentFields() throws {
        let bytes = try Backend.Coding.encoder.encode(Diagnostics.Request(method: .post, route: .meta, status: 0, ms: 12))
        #expect(try #require(String(data: bytes, encoding: .utf8)) == #"{"method":"POST","ms":12,"route":"/v2/meta","status":0}"#)
    }

    @Test("a request's numbers are clamped to the door's ranges, so one odd value can't refuse a whole report")
    func aRequestsNumbersAreClamped() {
        let wild = Diagnostics.Request(method: .get, route: .meta, status: 999, ms: -5, retries: 50)
        #expect(wild == Diagnostics.Request(method: .get, route: .meta, status: 599, ms: 0, retries: 20))
        let negative = Diagnostics.Request(method: .get, route: .meta, status: -1, ms: 90_000_000, retries: -3)
        #expect(negative == Diagnostics.Request(method: .get, route: .meta, status: 0, ms: 86_400_000, retries: 0))
        #expect(Diagnostics.Request(method: .get, route: .meta, status: 200, ms: 12).retries == nil)
    }

    @Test("a playback position is written within the door's range", arguments: [(-1, 0), (0, 0), (125_000, 125_000), (1_000_000_000, 86_400_000)])
    func aPlaybackPositionIsClamped(_ position: Int, _ written: Int) throws {
        let id = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1"))
        let bytes = try Backend.Coding.encoder.encode(Diagnostics.Event.playbackPaused(itemID: id, positionMs: position))
        let object = try #require(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        #expect(object["positionMs"] as? Int == written)
    }

    @Test("each record goes to the ring with the server's cap for its part")
    func eachRecordGoesToItsRing() {
        #expect(Diagnostics.Record.event(.appLaunch).ring == .events)
        #expect(Diagnostics.Record.request(.init(method: .get, route: .meta, status: 200, ms: 1)).ring == .network)
        #expect(Diagnostics.Record.failure(.init(code: .network)).ring == .failures)
        #expect(Diagnostics.Record.crash(.init(kind: .crash)).ring == .crashes)
        #expect(Diagnostics.Ring.allCases.map(\.cap) == [2000, 2000, 500, 100])
    }
}

extension Platform.Diagnostics.Event {
    /// One of every kind. The switch has no default, so a new kind doesn't
    /// compile until it has a sample here too.
    static var everyCase: [Self] {
        let item = UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!
        return Kind.allCases.map { kind in
            switch kind {
            case .appLaunch: .appLaunch
            case .appForeground: .appForeground
            case .appBackground: .appBackground
            case .screenShown: .screenShown(.journal)
            case .screenLeft: .screenLeft(.settings)
            case .controlTapped: .controlTapped(.briefPlay, on: .journal)
            case .sheetOpened: .sheetOpened(.player)
            case .sheetClosed: .sheetClosed(.sendReport)
            case .playbackStarted: .playbackStarted(itemID: item, positionMs: 0)
            case .playbackPaused: .playbackPaused(itemID: item, positionMs: 125_000)
            case .playbackEnded: .playbackEnded(itemID: item, positionMs: 4_452_000)
            case .permissionPrompted: .permissionPrompted(.microphone)
            case .permissionAnswered: .permissionAnswered(.notifications, granted: false)
            }
        }
    }
}

extension Platform.Diagnostics.Record {
    /// Every event, plus a request, a failure and a crash with every optional
    /// field filled, so the no-content check sees everything a record can hold.
    static var everyCase: [Self] {
        Platform.Diagnostics.Event.everyCase.map { .event($0) } + [
            .request(.init(method: .post, route: .meta, status: 504, code: .upstreamTimeout, ms: 30000, retries: 2, idempotency: .replayed)),
            .failure(.init(code: .server, screen: .journal)),
            .crash(.init(kind: .hang)),
        ]
    }
}

private extension Backend.Failure.Kind {
    /// Every kind that comes from the server, one each.
    static var everyBackendCase: [Self] {
        [
            .invalidRequest, .invalidCredentials, .unauthenticated, .sessionRevoked, .inviteRequired, .suspended, .notFound,
            .idempotencyMismatch, .updateRequired, .rateLimited(retryAfter: nil), .spendLimited(retryAfter: nil), .upstreamTimeout,
            .upstreamUnavailable, .internal, .inviteInvalid, .inviteUsed, .inviteExpired,
        ]
    }
}
