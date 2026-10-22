import AuthenticationServices
import Foundation
@testable import Retrospect
import Security
import Testing

@Suite(.timeLimit(.minutes(1)))
struct NonceTests {
    @Test("a nonce's hash is the lowercase SHA-256 hex of the raw value")
    func theHashIsLowercaseSHA256Hex() {
        let nonce = Session.Nonce(raw: "abc")

        #expect(nonce.hashed == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(Session.Nonce.hash("aW52ZW50ZWQtbm9uY2UtMzItYnl0ZXMtYmFzZTY0dXJs") == Session.Nonce.hash("aW52ZW50ZWQtbm9uY2UtMzItYnl0ZXMtYmFzZTY0dXJs"))
        #expect(nonce.hashed == nonce.hashed.lowercased())
    }

    @Test("the raw value is 32 random bytes as base64url: 43 characters, URL-safe, no padding")
    func theRawValueIs32BytesBase64URL() throws {
        let nonce = try Session.Nonce.make { count in (0 ..< count).map { _ in 0xFB } }

        #expect(nonce.raw.count == 43)
        #expect(nonce.raw == String(repeating: "-_v7", count: 10) + "-_s")
        #expect(Session.Nonce.base64URL([0xFB, 0xFF]) == "-_8")
        let real = try Session.Nonce.make()
        #expect(real.raw.count == 43)
        #expect(real.raw.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }

    @Test("each make gives a different nonce")
    func eachMakeGivesADifferentNonce() throws {
        let nonces = try (0 ..< 20).map { _ in try Session.Nonce.make() }

        #expect(Set(nonces.map(\.raw)).count == 20)
    }

    @Test("when the system has no random bytes, the status surfaces and nothing is made")
    func noRandomBytesSurfacesTheStatus() {
        #expect(throws: Session.Nonce.RandomUnavailable(status: errSecInternalError)) {
            try Session.Nonce.make { _ in throw Session.Nonce.RandomUnavailable(status: errSecInternalError) }
        }
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AppleSignInTests {
    private struct NoTokens: Backend.TokenProviding {
        func accessToken() async throws -> String {
            throw Backend.Failure(.unauthenticated)
        }

        func refreshAfterUnauthorized(failedToken _: String) async throws -> String {
            throw Backend.Failure(.unauthenticated)
        }
    }

    /// Remembers what it was asked to install, in order, and can refuse.
    private final class RecordingInstaller: Session.Installing, @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [Session.Credentials] = []
        var fails: (any Error)?

        var installed: [Session.Credentials] {
            lock.withLock { stored }
        }

        func install(_ credentials: Session.Credentials) async throws {
            if let fails {
                throw fails
            }
            lock.withLock { stored.append(credentials) }
        }
    }

    private let session = URLSession.stubbed()
    private let recorder = Platform.Log.Recorder()
    private let keychain = Session.MemoryKeychain()
    private let legacy = Session.MemoryKeychain()
    private let installer = RecordingInstaller()
    private let fixtureRaw = "aW52ZW50ZWQtbm9uY2UtMzItYnl0ZXMtYmFzZTY0dXJs"

    private let first = Session.AppleCredential(
        user: "001234.invented.5678", identityToken: "invented.identity.token", authorizationCode: "invented-code",
        givenName: "sam", familyName: nil, email: nil
    )
    private let later = Session.AppleCredential(
        user: "001234.invented.5678", identityToken: "invented.identity.token", authorizationCode: "invented-code",
        givenName: nil, familyName: nil, email: nil
    )

    private func client() -> Backend.Client {
        Backend.Client(
            configuration: .resolve(.local, info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"], isRelease: false),
            session: session,
            tokens: NoTokens(),
            clock: TestClock(),
            log: recorder
        )
    }

    private func signIn(installer: any Session.Installing, nonce: @escaping @Sendable () throws -> Session.Nonce) -> Session.AppleSignIn {
        Session.AppleSignIn(client: client(), installer: installer, log: recorder, makeNonce: nonce)
    }

    /// A sign-in whose nonce is the fixture's, so bodies compare to the fixtures.
    private func fixtureSignIn(installer: (any Session.Installing)? = nil) -> Session.AppleSignIn {
        let raw = fixtureRaw
        return signIn(installer: installer ?? self.installer) { Session.Nonce(raw: raw) }
    }

    private func store() -> Session.Store {
        Session.Store(keychain: keychain, legacyKeychain: legacy, defaults: UserDefaults(suiteName: "platform.tests.\(UUID().uuidString)") ?? .standard)
    }

    private func serve(status: Int = 200, _ data: Data) {
        StubProtocol.register(on: session) { (HTTPURLResponse.stub($0, status: status), data) }
    }

    private func sentBody() throws -> [String: Any] {
        let sent = try #require(StubProtocol.requests(on: session).first)
        let body = try #require(sent.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    /// A sign-in answer with the given access state.
    private func answer(access: String) -> Data {
        let user = #"{"id":"u","firstName":null,"isNew":false}"#
        let pair = #""accessToken":"a","refreshToken":"r","accessTokenExpiresAt":"2026-10-21T08:15:00.000Z""#
        return Data(#"{"success":true,"data":{\#(pair),"user":\#(user),"access":{"state":"\#(access)"}}}"#.utf8)
    }

    private func fixtureObject(_ name: String) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Fixtures.data("00", name)) as? [String: Any])
    }

    private func request() -> ASAuthorizationAppleIDRequest {
        ASAuthorizationAppleIDProvider().createRequest()
    }

    // MARK: Prepare

    @Test("prepare asks for the name and email and puts the nonce's hash on the request; each prepare makes a new one")
    func prepareBindsANewNonceEachTime() throws {
        let signIn = signIn(installer: installer) { try Session.Nonce.make() }
        let one = request()
        let two = request()

        signIn.prepare(one)
        signIn.prepare(two)

        #expect(one.requestedScopes == [.fullName, .email])
        let first = try #require(one.nonce)
        let second = try #require(two.nonce)
        #expect(first != second)
        #expect(first.count == 64)
        #expect(first == first.lowercased())
        let isHex = first.allSatisfy(\.isHexDigit)
        #expect(isHex)
    }

    @Test("the hash on the request is the hash of the raw nonce the server gets")
    func theRequestsNonceIsTheHashOfTheRawNonceSent() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response"))
        let signIn = fixtureSignIn()
        let request = request()

        signIn.prepare(request)
        _ = try await signIn.signIn(with: later)

        #expect(request.nonce == Session.Nonce.hash(fixtureRaw))
        #expect(try sentBody()["rawNonce"] as? String == fixtureRaw)
    }

    // MARK: The body

    @Test("Apple completion sends exactly the contract's keys, the name and email only on the first authorization")
    func theBodyIsExactlyTheContracts() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response"))
        let signIn = fixtureSignIn()

        signIn.prepare(request())
        _ = try await signIn.signIn(with: first)
        let firstBody = try sentBody()
        StubProtocol.clear(session)
        try serve(Fixtures.data("00", "auth.response"))
        signIn.prepare(request())
        _ = try await signIn.signIn(with: later)
        let laterBody = try sentBody()

        let firstFixture = try fixtureObject("auth-apple.request")
        let laterFixture = try fixtureObject("auth-apple.request.minimal")
        #expect(firstBody as NSDictionary == firstFixture as NSDictionary)
        #expect(Set(firstBody.keys) == ["identityToken", "authorizationCode", "rawNonce", "fullName", "email"])
        #expect(laterBody as NSDictionary == laterFixture as NSDictionary)
        #expect(Set(laterBody.keys) == ["identityToken", "authorizationCode", "rawNonce"])
    }

    @Test("an email without a name still counts as the first authorization, with null name parts")
    func anEmailAloneIsAFirstAuthorization() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response"))
        let signIn = fixtureSignIn()
        let credential = Session.AppleCredential(
            user: first.user, identityToken: first.identityToken, authorizationCode: first.authorizationCode,
            givenName: nil, familyName: nil, email: "invented@privaterelay.appleid.com"
        )

        signIn.prepare(request())
        _ = try await signIn.signIn(with: credential)

        let body = try sentBody()
        #expect(body["email"] as? String == "invented@privaterelay.appleid.com")
        let name = try #require(body["fullName"] as? [String: Any])
        #expect(name["givenName"] is NSNull)
        #expect(name["familyName"] is NSNull)
    }

    @Test("the sign-in is a public POST with no Authorization header")
    func theSignInIsPublic() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response"))
        let signIn = fixtureSignIn()

        signIn.prepare(request())
        _ = try await signIn.signIn(with: later)

        let sent = try #require(StubProtocol.requests(on: session).first)
        #expect(sent.httpMethod == "POST")
        #expect(sent.url?.path == "/v2/auth/apple")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(sent.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    // MARK: The answer

    @Test("the auth response is installed with the access state, name, provider and Apple id, and the outcome carries no token")
    func theAnswerIsInstalledWhole() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response.waitlisted"))
        let signIn = fixtureSignIn()

        signIn.prepare(request())
        let outcome = try await signIn.signIn(with: first)

        #expect(outcome == Session.SignInOutcome(userID: "00000000-0000-4000-8000-000000000001", firstName: "sam", isNew: true, access: .waitlisted))
        let installed = try #require(installer.installed.first)
        #expect(installer.installed.count == 1)
        #expect(installed.accessToken == "invented.access.token")
        #expect(installed.refreshToken == "invented-refresh-token")
        #expect(installed.accessTokenExpiresAt == Date(timeIntervalSince1970: 1_792_570_500))
        #expect(installed.userID == "00000000-0000-4000-8000-000000000001")
        #expect(installed.access == .waitlisted)
        #expect(installed.firstName == "sam")
        #expect(installed.provider == .apple)
        #expect(installed.appleUserID == "001234.invented.5678")
        #expect(recorder.events.last == .signedIn(provider: .apple, isNew: true))
    }

    @Test("the store installs a session by saving it, then marking signed in before")
    func theStoreInstallsThenMarks() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response"))
        let store = store()
        let signIn = fixtureSignIn(installer: store)

        signIn.prepare(request())
        _ = try await signIn.signIn(with: first)

        #expect(try await store.hasSignedInBefore)
        let saved = try #require(try await store.credentials())
        #expect(saved.provider == .apple)
        #expect(saved.access == .member)
        #expect(saved.appleUserID == "001234.invented.5678")
    }

    @Test("a save that fails leaves nothing marked and throws the Keychain status")
    func aFailedSaveMarksNothing() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response"))
        keychain.failCall(1, with: errSecInteractionNotAllowed)
        let store = store()
        let signIn = fixtureSignIn(installer: store)

        signIn.prepare(request())
        await #expect(throws: Session.KeychainError(status: errSecInteractionNotAllowed)) { _ = try await signIn.signIn(with: first) }

        #expect(keychain.contents.isEmpty)
        #expect(!recorder.events.contains {
            if case .signedIn = $0 {
                true
            } else {
                false
            }
        })
    }

    @Test("a suspended account still signs in, with its state")
    func aSuspendedAccountStillSignsIn() async throws {
        defer { StubProtocol.clear(session) }
        serve(answer(access: "suspended"))
        let signIn = fixtureSignIn()

        signIn.prepare(request())
        let outcome = try await signIn.signIn(with: later)

        #expect(outcome.access == .suspended)
        #expect(installer.installed.first?.access == .suspended)
    }

    @Test("an access state the app doesn't know installs as unknown, never failing the sign-in")
    func anUnknownAccessStateInstallsAsUnknown() async throws {
        defer { StubProtocol.clear(session) }
        serve(answer(access: "brand_new"))
        let signIn = fixtureSignIn()

        signIn.prepare(request())
        let outcome = try await signIn.signIn(with: later)

        #expect(outcome.access == .unknown)
    }

    // MARK: Refusals

    @Test("a cancelled Apple sheet throws cancelled and sends nothing")
    func aCancelledSheetSendsNothing() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response"))
        let signIn = fixtureSignIn()
        signIn.prepare(request())
        let cancelled = NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.canceled.rawValue)

        await #expect(throws: Session.SignInError.cancelled) { _ = try await signIn.complete(.failure(cancelled)) }

        #expect(StubProtocol.requests(on: session).isEmpty)
        #expect(installer.installed.isEmpty)
    }

    @Test("another Apple failure carries only its code")
    func anotherAppleFailureCarriesItsCode() async {
        let signIn = fixtureSignIn()
        let failed = NSError(
            domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.failed.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "invented words"]
        )

        await #expect(throws: Session.SignInError.appleFailed(code: ASAuthorizationError.failed.rawValue)) { _ = try await signIn.complete(.failure(failed)) }
        #expect(Session.AppleSignIn.signInError(for: URLError(.badURL)) == .appleFailed(code: URLError.badURL.rawValue))
    }

    @Test("a completion without a prepare sends nothing, and a nonce is used up by one completion")
    func noNonceSendsNothing() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response"))
        let signIn = fixtureSignIn()

        await #expect(throws: Session.SignInError.notPrepared) { _ = try await signIn.signIn(with: first) }
        #expect(StubProtocol.requests(on: session).isEmpty)

        signIn.prepare(request())
        _ = try await signIn.signIn(with: first)
        await #expect(throws: Session.SignInError.notPrepared) { _ = try await signIn.signIn(with: first) }

        #expect(StubProtocol.requests(on: session).count == 1)
        #expect(installer.installed.count == 1)
    }

    @Test("a cancelled sheet uses the nonce up too: the next tap prepares again")
    func aCancelledSheetUsesTheNonceUp() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response"))
        let signIn = fixtureSignIn()
        signIn.prepare(request())
        let cancelled = NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.canceled.rawValue)
        _ = try? await signIn.complete(.failure(cancelled))

        await #expect(throws: Session.SignInError.notPrepared) { _ = try await signIn.signIn(with: first) }

        #expect(StubProtocol.requests(on: session).isEmpty)
    }

    @Test("when no nonce can be made, prepare logs the status and the token is never sent")
    func noNonceMeansNoSend() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response"))
        let signIn = signIn(installer: installer) { throw Session.Nonce.RandomUnavailable(status: errSecInternalError) }
        let request = request()

        signIn.prepare(request)
        await #expect(throws: Session.SignInError.notPrepared) { _ = try await signIn.signIn(with: first) }

        #expect(request.nonce == nil)
        #expect(recorder.events == [.nonceUnavailable(status: errSecInternalError)])
        #expect(StubProtocol.requests(on: session).isEmpty)
    }

    @Test("a nonce the server refuses surfaces as invalid credentials, with nothing installed, and the next tap needs a fresh nonce")
    func aRefusedNonceSurfacesAsInvalidCredentials() async throws {
        defer { StubProtocol.clear(session) }
        try serve(status: 401, Fixtures.data("00", "error.invalid_credentials"))
        let signIn = fixtureSignIn()
        signIn.prepare(request())

        await #expect(throws: Backend.Failure(.invalidCredentials)) { _ = try await signIn.signIn(with: first) }

        #expect(installer.installed.isEmpty)
        await #expect(throws: Session.SignInError.notPrepared) { _ = try await signIn.signIn(with: first) }
        #expect(StubProtocol.requests(on: session).count == 1)
    }

    @Test("offline, the failure is offline and nothing is installed")
    func offlineInstallsNothing() async throws {
        defer { StubProtocol.clear(session) }
        StubProtocol.register(on: session) { _ in throw URLError(.notConnectedToInternet) }
        let signIn = fixtureSignIn()
        signIn.prepare(request())

        await #expect(throws: Backend.Failure(.offline)) { _ = try await signIn.signIn(with: first) }

        #expect(installer.installed.isEmpty)
    }

    @Test("an installer that refuses fails the sign-in and logs no sign-in")
    func anInstallerThatRefusesFailsTheSignIn() async throws {
        defer { StubProtocol.clear(session) }
        try serve(Fixtures.data("00", "auth.response"))
        installer.fails = Session.KeychainError(status: errSecIO)
        let signIn = fixtureSignIn()
        signIn.prepare(request())

        await #expect(throws: Session.KeychainError(status: errSecIO)) { _ = try await signIn.signIn(with: first) }

        #expect(!recorder.events.contains {
            if case .signedIn = $0 {
                true
            } else {
                false
            }
        })
    }

    // MARK: Reading Apple's credential

    @Test("the credential's first authorization is anything Apple gave once")
    func firstAuthorizationIsAnythingGivenOnce() {
        #expect(first.isFirstAuthorization)
        #expect(!later.isFirstAuthorization)
        let familyOnly = Session.AppleCredential(user: "u", identityToken: "t", authorizationCode: "c", givenName: nil, familyName: "n", email: nil)
        #expect(familyOnly.isFirstAuthorization)
    }

    @Test("a credential that isn't an Apple ID credential is unreadable")
    func aNonAppleCredentialIsUnreadable() {
        let password = ASPasswordCredential(user: "invented", password: "invented")

        #expect(throws: Session.SignInError.unreadableCredential) {
            try Session.AppleSignIn.credential(from: password)
        }
    }
}
