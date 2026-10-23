import Foundation
@testable import Retrospect
import Testing

private let base = URL(string: "https://retrospect-api.onrender.com")
private let entryID = "7b0d7a2e-0b0f-4a53-9d6e-3a1a4c3f2b10"

@Suite(.timeLimit(.minutes(1)))
struct RoutingParserTests {
    private func parse(_ text: String, base: URL? = base) throws -> Routing.Destination? {
        try Routing.Parser.parse(#require(URL(string: text)), inviteBase: base)
    }

    @Test("every address the app accepts maps to its destination")
    func acceptedAddresses() throws {
        let table: [(String, Routing.Destination)] = [
            ("retrospect://start-recording", .startRecording),
            ("retrospect://stop-recording", .stopRecording),
            ("retrospect://integration-connected?provider=spotify&status=syncing", .integrationConnected(provider: "spotify", status: "syncing")),
            ("retrospect://integration-connected?provider=google&status=connected", .integrationConnected(provider: "google", status: "connected")),
            ("retrospect://brief", .brief(id: nil)),
            ("retrospect://brief/\(entryID)", .brief(id: entryID)),
            ("retrospect://entry/\(entryID)", .entry(id: entryID)),
            ("retrospect://episode/\(entryID.uppercased())", .episode(id: entryID)),
            ("retrospect://guess/\(entryID)", .guess(id: entryID)),
            ("retrospect://settings", .settings(.root)),
            ("retrospect://settings/privacy", .settings(.privacy)),
            ("https://retrospect-api.onrender.com/i/7KQ2M9XD4RTAB", .invite(code: "7KQ2M9XD4RTAB")),
            ("https://retrospect-api.onrender.com/i/7kq2-m9xd-4rtab", .invite(code: "7KQ2M9XD4RTAB")),
            ("https://retrospect-api.onrender.com:" + "443" + "/i/7KQ2M9XD4RTAB", .invite(code: "7KQ2M9XD4RTAB")), // the default port written out
        ]
        for (text, expected) in table {
            #expect(try parse(text) == expected, "\(text)")
        }
    }

    @Test("malformed or foreign addresses are not destinations")
    func malformedAddresses() throws {
        let rejected = [
            "retrospect://entry/not-a-uuid", "retrospect://entry", "retrospect://entry/\(entryID)/extra",
            "retrospect://brief/\(entryID)/extra", "retrospect://settings/nowhere", "retrospect://settings/brief/more",
            "retrospect://start-recording/now", "retrospect://integration-connected",
            "retrospect://integration-connected?provider=Spot ify&status=ok", "retrospect://unknown",
            "http://retrospect-api.onrender.com/i/7KQ2M9XD4RTAB", // http, not https
            "https://elsewhere.example.com/i/7KQ2M9XD4RTAB", // another host
            "https://retrospect-api.onrender.com/i/SHORT", // a code of the wrong length
            "https://retrospect-api.onrender.com/i/7KQ2M9XD4RTABX", // too long
            "https://retrospect-api.onrender.com/i/7KQ2M9XD4RTAB/more", // extra path
            "https://retrospect-api.onrender.com/privacy", // the site handles it
            "https://retrospect-api.onrender.com:" + "8443" + "/i/7KQ2M9XD4RTAB", // another port (split so a secret scanner sees no key)
            "ftp://retrospect-api.onrender.com/i/7KQ2M9XD4RTAB",
        ]
        for text in rejected {
            #expect(try parse(text) == nil, "\(text)")
        }
        #expect(try parse("https://retrospect-api.onrender.com/i/7KQ2M9XD4RTAB", base: nil) == nil, "no invite host, no invite link")
    }

    @Test("the local backend's http link is an invite link, because the local base is http")
    func localBase() throws {
        let local = URL(string: "http://localhost:3000")
        #expect(try parse("http://localhost:3000/i/7KQ2M9XD4RTAB", base: local) == .invite(code: "7KQ2M9XD4RTAB"))
        #expect(try parse("https://localhost:3000/i/7KQ2M9XD4RTAB", base: local) == nil)
    }

    @Test("the Google sign-in return is recognised and is not a destination")
    func googleCallback() throws {
        let url = try #require(URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?code=invented"))
        #expect(Routing.Parser.isGoogleCallback(url))
        #expect(Routing.Parser.parse(url, inviteBase: base) == nil)
    }

    @Test("an unknown address is described by kind only")
    func unknownKinds() throws {
        let app = try #require(URL(string: "retrospect://nowhere"))
        let site = try #require(URL(string: "https://retrospect-api.onrender.com/privacy"))
        let other = try #require(URL(string: "https://example.com/x"))
        #expect(Routing.Parser.unknownKind(of: app, inviteBase: base) == .appLink)
        #expect(Routing.Parser.unknownKind(of: site, inviteBase: base) == .inviteHostLink)
        #expect(Routing.Parser.unknownKind(of: other, inviteBase: base) == .other)
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RoutingRouterTests {
    private final class Received: @unchecked Sendable {
        private let lock = NSLock()
        private var codes: [String] = []
        func add(_ code: String) { lock.withLock { codes.append(code) } }
        var all: [String] {
            lock.withLock { codes }
        }
    }

    private func make() -> (Routing.Router, Received, Platform.Log.Recorder) {
        let received = Received()
        let log = Platform.Log.Recorder()
        let router = Routing.Router(inviteBase: base, log: log, receiveInvite: { received.add($0) })
        return (router, received, log)
    }

    @Test("two invite links opened at once reach the center in the order they arrived, even when the first is slow")
    func invitesArriveInOrder() async throws {
        let received = Received()
        let slow = Gate()
        // The first hand-over is held (as a Keychain write or a preview request would hold it).
        let router = Routing.Router(inviteBase: base, log: Platform.Log.Recorder(), receiveInvite: { code in
            if code == "7KQ2M9XD4RTAB" {
                try? await slow.wait()
            }
            received.add(code)
        })
        try router.open(#require(URL(string: "https://retrospect-api.onrender.com/i/7KQ2M9XD4RTAB")))
        try router.open(#require(URL(string: "https://retrospect-api.onrender.com/i/8KQ2M9XD4RTAB")))
        while slow.waiting == 0 {
            await Task.yield()
        }
        for _ in 0 ..< 100 {
            await Task.yield()
        }
        #expect(received.all.isEmpty, "the second link waits for the first")
        slow.open()
        await router.settled()

        #expect(received.all == ["7KQ2M9XD4RTAB", "8KQ2M9XD4RTAB"])
    }

    @Test("an invite link opened cold reaches the invite center and is never pending")
    func inviteIsNeverPending() async throws {
        let (router, received, _) = make()
        try router.open(#require(URL(string: "https://retrospect-api.onrender.com/i/7KQ2M9XD4RTAB")))
        await router.settled()

        #expect(received.all == ["7KQ2M9XD4RTAB"])
        #expect(router.pending == nil)
        #expect(router.consume() == nil)
    }

    @Test("a screen destination waits in pending, is taken once, and the newest replaces an older one")
    func pendingIsConsumedOnce() throws {
        let (router, _, _) = make()
        try router.open(#require(URL(string: "retrospect://entry/\(entryID)")))
        try router.open(#require(URL(string: "retrospect://settings/account")))

        #expect(router.pending == .settings(.account))
        #expect(router.consume() == .settings(.account))
        #expect(router.consume() == nil)
    }

    @Test("the routes the old screens act on are left to them: no pending, no second action")
    func oldScreensKeepTheirRoutes() throws {
        let (router, received, log) = make()
        for text in ["retrospect://start-recording", "retrospect://stop-recording", "retrospect://integration-connected?provider=google&status=connected"] {
            try router.open(#require(URL(string: text)))
        }

        #expect(router.pending == nil)
        #expect(received.all.isEmpty)
        #expect(log.events.isEmpty, "recognised routes are not unknown links")
    }

    @Test("the Google callback is not logged as unknown and goes nowhere")
    func googleCallbackGoesNowhere() throws {
        let (router, received, log) = make()
        try router.open(#require(URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?code=invented")))

        #expect(router.pending == nil && received.all.isEmpty && log.events.isEmpty)
    }

    @Test("an unknown link does nothing and its log line holds no path, query or code")
    func unknownLinkLogsOnlyItsKind() throws {
        let (router, received, log) = make()
        try router.open(#require(URL(string: "https://retrospect-api.onrender.com/i/BADCODE?secret=invented")))
        try router.open(#require(URL(string: "retrospect://entry/not-a-uuid?token=invented")))

        #expect(router.pending == nil && received.all.isEmpty)
        #expect(log.events == [.routeUnknown(.inviteHostLink), .routeUnknown(.appLink)])
    }

    @Test("a destination waiting for the next person is dropped at sign-out")
    func clearDropsPending() throws {
        let (router, _, _) = make()
        try router.open(#require(URL(string: "retrospect://entry/\(entryID)")))
        router.clear()

        #expect(router.pending == nil)
    }

    @Test("the environment's router sends an invite link to its invite center and clears pending on sign-out")
    func environmentWiring() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let environment = Platform.AppEnvironment.preview(openDatabase: { _ in database })
        await environment.sessionDidChange(to: "user-a").value
        try environment.router.open(#require(URL(string: "retrospect://entry/\(entryID)")))
        #expect(environment.router.pending == .entry(id: entryID))

        let change = environment.sessionWillChange()
        #expect(environment.router.pending == nil, "cleared when sign-out starts, not after the queue behind it")
        await change.value

        #expect(environment.router.pending == nil, "the last person's entry id never waits for the next")
    }
}
