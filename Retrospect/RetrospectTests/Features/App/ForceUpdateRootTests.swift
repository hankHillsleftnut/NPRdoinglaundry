import Foundation
@testable import Retrospect
import Testing

/// PX.root: once the version floor says this build is too old, the app root shows the force-update page
/// whatever the session is doing; otherwise the root is exactly as before.
@MainActor
struct ForceUpdateRootTests {
    /// One session state the root can be handed, with the inputs that steer it to its own page.
    @MainActor
    struct Case {
        let name: String
        let state: Session.State?
        var code: Bool? = false
        var held = false
        var failed = false
        var seen: Bool? = true

        func screen(update: Bool) -> NewAppRoot.Screen {
            NewAppRoot.screen(
                for: state, pendingCode: code, gateHeld: held, storeOpenFailed: failed, youreInSeen: seen, updateRequired: update
            )
        }

        /// The call every caller made before PX.root (the flag left out).
        var screenWithoutFlag: NewAppRoot.Screen {
            NewAppRoot.screen(for: state, pendingCode: code, gateHeld: held, storeOpenFailed: failed, youreInSeen: seen)
        }
    }

    private static let firstTime = Session.State.signedOut(hasSignedInBefore: false, reason: .none)

    private static let everyState: [Case] = [
        Case(name: "not read yet", state: nil),
        Case(name: "locked", state: .locked),
        Case(name: "signed out, Keychain not asked", state: firstTime, code: nil),
        Case(name: "signed out, first time", state: firstTime),
        Case(name: "signed out by the server", state: .signedOut(hasSignedInBefore: true, reason: .revoked)),
        Case(name: "signed out with a code waiting", state: firstTime, code: true),
        Case(name: "approved mid-tear", state: .signedIn(userID: "u", access: .approved), held: true),
        Case(name: "approved, moment not seen", state: .signedIn(userID: "u", access: .approved), seen: false),
        Case(name: "approved, flag unknown", state: .signedIn(userID: "u", access: .approved), seen: nil),
        Case(name: "approved, store failed", state: .signedIn(userID: "u", access: .approved), failed: true, seen: nil),
        Case(name: "member, store failed", state: .signedIn(userID: "u", access: .member), failed: true),
    ] + [Session.AccessState.waitlisted, .approved, .member, .staff, .suspended, .unknown].map {
        Case(name: "signed in, \($0.rawValue)", state: .signedIn(userID: "u", access: $0))
    }

    @Test("an old build lands on the update page from every session state, before blank, locked, sign-in, gate, paused, retry and journal")
    func updateWinsOverEverything() {
        for item in Self.everyState {
            #expect(item.screen(update: true) == .updateRequired, "\(item.name)")
        }
    }

    @Test("the update page is never shown while the build is current: every state lands where it did before")
    func neverWhenNotRequired() {
        for item in Self.everyState {
            #expect(item.screen(update: false) != .updateRequired, "\(item.name)")
            #expect(item.screen(update: false) == item.screenWithoutFlag, "\(item.name): leaving the flag out is the same as false")
        }
    }

    @Test("the pages the root already knew are unchanged with the floor down")
    func knownPagesUnchanged() {
        let expected: [(Case, NewAppRoot.Screen)] = [
            (Case(name: "nil", state: nil), .blank),
            (Case(name: "locked", state: .locked), .locked),
            (Case(name: "revoked", state: .signedOut(hasSignedInBefore: true, reason: .revoked)), .signIn(returning: true, endedByServer: true)),
            (Case(name: "code", state: Self.firstTime, code: true), .inviteGate),
            (Case(name: "suspended", state: .signedIn(userID: "u", access: .suspended)), .paused),
            (Case(name: "failed", state: .signedIn(userID: "u", access: .member), failed: true), .storeFailed),
            (Case(name: "member", state: .signedIn(userID: "u", access: .member)), .journal),
        ]
        for (item, page) in expected {
            #expect(item.screen(update: false) == page, "\(item.name)")
        }
    }

    @Test("VoiceOver hears a new screen when the update page replaces any page, and not again while it stays")
    func announcesOnlyOnArrival() {
        let pages: [NewAppRoot.Screen] = [
            .blank, .locked, .signIn(returning: false, endedByServer: false), .inviteGate, .paused, .storeFailed, .journal,
        ]
        for page in pages {
            #expect(NewAppRoot.announcesUpdatePage(from: page, to: .updateRequired), "\(page)")
            #expect(!NewAppRoot.announcesUpdatePage(from: page, to: .journal), "no announcement for ordinary moves")
        }
        #expect(!NewAppRoot.announcesUpdatePage(from: .updateRequired, to: .updateRequired))
    }

    @Test("with no App Store id the update button stays hidden and does nothing; with one it opens the store")
    func buttonFollowsTheStoreID() {
        var opened: [URL] = []
        let hidden = ForceUpdateModel(storeURL: AppStoreLink.url(id: nil)) { opened.append($0) }
        #expect(!hidden.canUpdate)
        hidden.update()
        #expect(opened.isEmpty)
        let shown = ForceUpdateModel(storeURL: AppStoreLink.url(id: "123")) { opened.append($0) }
        #expect(shown.canUpdate)
        shown.update()
        #expect(opened.map(\.absoluteString) == ["itms-apps://apps.apple.com/app/id123"])
    }

    @Test("the root reads the version floor off the app's environment: when the floor flips, the update page shows")
    func rootFollowsTheFloor() {
        let platform = Platform.AppEnvironment.preview()
        #expect(NewAppRoot.screen(on: platform, gateHeld: false, youreInSeen: true) != .updateRequired)
        platform.floor.serverRequiresUpdate() // what the client does on any 426, and meta on a floor above this build
        #expect(NewAppRoot.screen(on: platform, gateHeld: false, youreInSeen: true) == .updateRequired)
        #expect(NewAppRoot.screen(on: platform, gateHeld: true, youreInSeen: nil) == .updateRequired)
    }

    @Test("a brief left playing stops when the update page arrives, once; ordinary moves leave the player alone")
    func audioStopsOnArrival() {
        var stops = 0
        #expect(NewAppRoot.updatePageArrived(from: .journal, to: .updateRequired) { stops += 1 })
        #expect(stops == 1)
        #expect(!NewAppRoot.updatePageArrived(from: .updateRequired, to: .updateRequired) { stops += 1 })
        #expect(!NewAppRoot.updatePageArrived(from: .journal, to: .storeFailed) { stops += 1 })
        #expect(!NewAppRoot.updatePageArrived(from: .blank, to: .journal) { stops += 1 })
        #expect(stops == 1)
    }
}
