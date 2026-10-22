import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct AppVersionTests {
    @Test("versions parse as the contract writes them, and nothing else", arguments: [
        ("1.0 (42)", "1.0 (42)"), ("1.10 (5)", "1.10 (5)"), ("2 (7)", "2 (7)"), ("1.2.3 (99.1)", "1.2.3 (99)"), ("01.0 (042)", "1.0 (42)"),
    ])
    func versionsParse(_ text: String, _ canonical: String) {
        #expect(Backend.AppVersion(text)?.description == canonical)
    }

    @Test("strings that aren't versions don't parse", arguments: ["1.0", "1.0 42", "(42)", "", "0 (0) extra", "a.b (1)", "1.0 (x)"])
    func nonVersionsDontParse(_ text: String) {
        #expect(Backend.AppVersion(text) == nil)
    }

    @Test("1.10 (5) is newer than 1.9 (99), never compared as text")
    func versionsCompareNumerically() throws {
        let newer = try #require(Backend.AppVersion("1.10 (5)"))
        let older = try #require(Backend.AppVersion("1.9 (99)"))
        #expect(older < newer)
        #expect(!(newer < older))
        #expect(try #require(Backend.AppVersion("1.0 (42)")) < #require(Backend.AppVersion("1.0.1 (1)")))
        #expect(try #require(Backend.AppVersion("1.0 (42)")) < #require(Backend.AppVersion("1.0 (43)")))
        #expect(try #require(Backend.AppVersion("1 (3)")) == #require(Backend.AppVersion("1 (3)")))
    }

    @Test("the floor compares builds, as the server does: a newer marketing version with an older build is still below it")
    func theFloorComparesBuilds() throws {
        let floor = try #require(Backend.AppVersion("1.0 (40)"))
        #expect(try #require(Backend.AppVersion("1.0 (39)")).isBelow(floor: floor))
        #expect(try #require(Backend.AppVersion("2.0 (39)")).isBelow(floor: floor))
        #expect(try !#require(Backend.AppVersion("0.9 (40)")).isBelow(floor: floor))
        #expect(try !#require(Backend.AppVersion("1.0 (41)")).isBelow(floor: floor))
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct VersionFloorTests {
    private let session = URLSession.stubbed()
    private let recorder = Platform.Log.Recorder()
    private let uptime = Platform.Box(TimeInterval(100))
    private let reachability = ManualReachability()

    private struct NoTokens: Backend.TokenProviding {
        func accessToken() async throws -> String { "t" }
        func refreshAfterUnauthorized(failedToken _: String) async throws -> String { "t" }
    }

    private func floor(running: String = "1.0 (42)") -> Platform.VersionFloor {
        let uptime = uptime
        return Platform.VersionFloor(runningVersion: running, log: recorder, uptime: { uptime.value })
    }

    private func client(floor: Platform.VersionFloor) -> Backend.Client {
        Backend.Client(
            configuration: .resolve(.local, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"], isRelease: false),
            session: session, tokens: NoTokens(), reachability: reachability, clock: TestClock(), log: recorder,
            onUpdateRequired: { Task { @MainActor in floor.serverRequiresUpdate() } }
        )
    }

    private func serveMeta(min: String, latest: String = "1.1 (55)") {
        let body = Data(
            #"{"success":true,"data":{"minVersion":"\#(min)","latestVersion":"\#(latest)","serverTime":"2026-10-21T08:00:04.200Z","environment":"local"}}"#
                .utf8
        )
        StubProtocol.register(on: session) { (HTTPURLResponse.stub($0), body) }
    }

    private func settle() async {
        for _ in 0 ..< 5 {
            await Task.yield()
        }
    }

    @Test("a 426 on any call sets updateRequired, and it never goes back")
    func a426SetsUpdateRequired() async throws {
        defer { StubProtocol.clear(session) }
        let floor = floor()
        let client = client(floor: floor)
        let body = try Fixtures.data("00", "error.update_required")
        StubProtocol.register(on: session) { (HTTPURLResponse.stub($0, status: 426), body) }
        #expect(!floor.updateRequired)

        await #expect(throws: Backend.Failure(.updateRequired)) { _ = try await client.send(Backend.Endpoints.Meta()) }
        await settle()

        #expect(floor.updateRequired)
        #expect(recorder.events.contains(.versionFloor(.updateRequired)))
        serveMeta(min: "1.0 (1)")
        await floor.checkIfDue(using: client)
        #expect(floor.updateRequired, "a later meta with a low floor doesn't clear it")
    }

    @Test("a 426 with no contract body still sets it")
    func a426WithNoBodyStillSetsIt() async {
        defer { StubProtocol.clear(session) }
        let floor = floor()
        let client = client(floor: floor)
        StubProtocol.register(on: session) { (HTTPURLResponse.stub($0, status: 426), Data()) }

        _ = try? await client.send(Backend.Endpoints.Meta())
        await settle()

        #expect(floor.updateRequired)
    }

    @Test("meta with a higher minVersion sets updateRequired; a floor at or below the running build doesn't")
    func metaWithAHigherFloorSetsIt() async {
        defer { StubProtocol.clear(session) }
        let floor = floor()
        let client = client(floor: floor)
        serveMeta(min: "1.0 (42)")
        await floor.checkIfDue(using: client)
        #expect(!floor.updateRequired)
        #expect(recorder.events.contains(.versionFloor(.current)))
        #expect(floor.latestVersion == Backend.AppVersion("1.1 (55)"))

        let later = self.floor()
        serveMeta(min: "1.0 (43)")
        await later.checkIfDue(using: self.client(floor: later))
        #expect(later.updateRequired)
    }

    @Test("meta is asked at most every six hours, and again after a failed ask")
    func metaIsAskedAtMostEverySixHours() async {
        defer { StubProtocol.clear(session) }
        let floor = floor()
        let client = client(floor: floor)
        serveMeta(min: "1.0 (1)")

        await floor.checkIfDue(using: client)
        uptime.value += 5 * 60 * 60
        await floor.checkIfDue(using: client)
        #expect(StubProtocol.requests(on: session).count == 1)

        uptime.value += 60 * 60 + 1
        await floor.checkIfDue(using: client)
        #expect(StubProtocol.requests(on: session).count == 2)

        reachability.set(online: false)
        uptime.value += 7 * 60 * 60
        await floor.checkIfDue(using: client)
        #expect(recorder.events.contains(.versionFloor(.askFailed)))
        reachability.set(online: true)
        await floor.checkIfDue(using: client)
        #expect(StubProtocol.requests(on: session).count == 3, "a failed ask doesn't start the six hours")
    }

    @Test("two active scenes at once ask meta once")
    func twoActiveScenesAskOnce() async {
        defer { StubProtocol.clear(session) }
        let floor = floor()
        let client = client(floor: floor)
        serveMeta(min: "1.0 (1)")

        async let first: Void = floor.checkIfDue(using: client)
        async let second: Void = floor.checkIfDue(using: client)
        _ = await (first, second)

        #expect(StubProtocol.requests(on: session).count == 1)
    }

    @Test("an unparseable version never sets updateRequired and logs once", arguments: [("nonsense", "1.0 (40)"), ("1.0 (42)", "soon")])
    func anUnparseableVersionLogsOnce(_ running: String, _ min: String) {
        let floor = floor(running: running)

        floor.apply(floor: min)
        floor.apply(floor: min)

        #expect(!floor.updateRequired)
        let unreadable = recorder.events.filter {
            if case .versionUnreadable = $0 {
                true
            } else {
                false
            }
        }
        #expect(unreadable.count == 1)
    }

    @Test("the live environment's floor runs the bundle's version and asks meta on an active scene")
    func theEnvironmentsFloor() {
        let environment = Platform.AppEnvironment.preview()
        #expect(!environment.updateRequired)
        environment.floor.serverRequiresUpdate()
        #expect(environment.updateRequired)
    }
}
