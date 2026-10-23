import Foundation
@testable import Retrospect
import Testing

/// PX.root: once the version floor says this build is too old, the root shows the force-update page whatever
/// the session is doing, and never shows it otherwise.
struct ForceUpdateRootTests {
    private func screen(
        _ state: Session.State?, code: Bool? = false, held: Bool = false, failed: Bool = false, seen: Bool? = true, update: Bool
    ) -> NewAppRoot.Screen {
        NewAppRoot.screen(
            for: state, pendingCode: code, gateHeld: held, storeOpenFailed: failed, youreInSeen: seen, updateRequired: update
        )
    }

    private let everySession: [(name: String, state: Session.State?)] = [
        ("unread", nil),
        ("locked", .locked),
        ("signed out", .signedOut(hasSignedInBefore: false, reason: .none)),
        ("signed out, returning", .signedOut(hasSignedInBefore: true, reason: .none)),
        ("ended by the server", .signedOut(hasSignedInBefore: true, reason: .revoked)),
        ("waitlisted", .signedIn(userID: "u", access: .waitlisted)),
        ("unknown access", .signedIn(userID: "u", access: .unknown)),
        ("suspended", .signedIn(userID: "u", access: .suspended)),
        ("approved", .signedIn(userID: "u", access: .approved)),
        ("member", .signedIn(userID: "u", access: .member)),
        ("staff", .signedIn(userID: "u", access: .staff)),
    ]

    @Test("a too-old build shows the update page over every session state")
    func winsOverEverySession() {
        for (name, state) in everySession {
            #expect(screen(state, update: true) == .updateRequired, "\(name)")
            #expect(screen(state, code: nil, update: true) == .updateRequired, "\(name), Keychain not asked yet")
            #expect(screen(state, code: true, update: true) == .updateRequired, "\(name), invite waiting")
        }
    }

    @Test("it wins over the gate being held, an unknown seen flag and a store that failed to open")
    func winsOverHoldsAndFailures() {
        let approved = Session.State.signedIn(userID: "u", access: .approved)
        let member = Session.State.signedIn(userID: "u", access: .member)
        #expect(screen(approved, held: true, update: true) == .updateRequired, "the tear's gate does not outrank it")
        #expect(screen(approved, seen: nil, update: true) == .updateRequired)
        #expect(screen(approved, seen: false, update: true) == .updateRequired)
        #expect(screen(approved, failed: true, update: true) == .updateRequired)
        #expect(screen(member, failed: true, update: true) == .updateRequired)
    }

    @Test("never shown when no update is required: every session lands exactly where it did before")
    func neverWhenNotRequired() {
        for (name, state) in everySession {
            let plain = NewAppRoot.screen(for: state, pendingCode: false, gateHeld: false, storeOpenFailed: false, youreInSeen: true)
            #expect(screen(state, update: false) == plain, "\(name)")
            #expect(plain != .updateRequired, "\(name)")
        }
        #expect(screen(.signedIn(userID: "u", access: .member), update: false) == .journal)
    }

    @Test("the flag is optional: leaving it out means no update is required")
    func defaultsToNotRequired() {
        let member = Session.State.signedIn(userID: "u", access: .member)
        #expect(NewAppRoot.screen(for: member, pendingCode: false, gateHeld: false, storeOpenFailed: false) == .journal)
    }

    @Test("with no App Store id in the build the page still shows, with the button hidden and the words kept")
    @MainActor
    func noStoreIDKeepsTheWords() {
        var opened: [URL] = []
        let model = ForceUpdateModel(storeURL: AppStoreLink.url(id: nil)) { opened.append($0) }
        #expect(!model.canUpdate)
        model.update()
        #expect(opened.isEmpty)
        #expect(!ForceUpdateModel.title.isEmpty && !ForceUpdateModel.line.isEmpty)
    }
}
