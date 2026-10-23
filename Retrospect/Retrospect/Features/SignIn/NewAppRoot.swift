//
//  NewAppRoot.swift
//  PL1.4b / PL5.2 / APP-ROOT: the app's root on the new backend, and in a release build the only root. What
//  shows comes from the new session's state and nothing else: a blank page while it is still being read, the
//  sign-in screen (PI0) when nobody is signed in, the invite gate (PI1/PI2) for a person who is not let in
//  yet or who has a code waiting, a plain "paused" page, and the journal (JR-1) on their live data for a
//  person who is. If the signed-in person's store can't be opened it says so and offers a retry.
//
//  PX.root: once the version floor says this build is too old (`platform.updateRequired`), the force-update
//  page (PX) replaces whatever was showing, signed in or not. Nothing is erased or signed out: the store and
//  the paused outbox stay as they are, so queued words send from the updated build (decision 3).
//
//  The old home, onboarding and sign-in gate are not reachable from here; debug builds can still open them
//  with `-OldHome`.
//
import SwiftUI

struct NewAppRoot: View {
    /// What the root shows for a session state.
    enum Screen: Equatable {
        /// Still being read: nothing to show yet.
        case blank
        /// The session could not be read: the phone has not been unlocked since it started, or the Keychain refused. It is read again on the next active scene.
        case locked
        /// PI0. `returning` is "welcome back"; `endedByServer` says the session ended on its own.
        case signIn(returning: Bool, endedByServer: Bool)
        /// PI1 and PI2: the promise, the ticket, the tear and "you're in" (up to the person's "begin").
        case inviteGate
        case paused
        /// The person's store could not be opened.
        case storeFailed
        case journal
        /// PX: this build is too old for the server. Shown over every other case, whatever the session is doing.
        case updateRequired
    }

    /// Which page a session lands on. `pendingCode` is nil until the Keychain has been asked (a signed-out
    /// phone waits on a blank canvas rather than flash sign-in before the gate). `gateHeld` is true from the
    /// moment the gate is up until the person presses "begin": the tear makes them a member before that, and
    /// the page must not be swapped for the journal under their finger. `updateRequired` (the version floor)
    /// wins over all of it: an old build can't do anything useful in any of those pages.
    static func screen(
        for state: Session.State?, pendingCode: Bool?, gateHeld: Bool, storeOpenFailed: Bool, youreInSeen: Bool? = true,
        updateRequired: Bool = false
    ) -> Screen {
        if updateRequired {
            return .updateRequired
        }
        return sessionScreen(for: state, pendingCode: pendingCode, gateHeld: gateHeld, storeOpenFailed: storeOpenFailed, youreInSeen: youreInSeen)
    }

    /// VoiceOver is told the screen changed when the update page replaces a page (it would otherwise keep
    /// reading where it was); never again while the page stays up.
    static func announcesUpdatePage(from old: Screen, to new: Screen) -> Bool {
        new == .updateRequired && old != .updateRequired
    }

    /// The page for the session alone (the version floor is down).
    private static func sessionScreen(
        for state: Session.State?, pendingCode: Bool?, gateHeld: Bool, storeOpenFailed: Bool, youreInSeen: Bool?
    ) -> Screen {
        guard let state else { return .blank }
        if case .locked = state {
            return .locked
        }
        if case .signedOut = state, pendingCode == nil {
            return .blank
        }
        if let early = approvedHold(state, gateHeld: gateHeld, storeOpenFailed: storeOpenFailed, youreInSeen: youreInSeen) {
            return early
        }
        switch FirstRunRoute.route(session: state, hasPendingCode: pendingCode ?? false, youreInSeen: !gateHeld && youreInSeen == true) {
        case .blank:
            return .blank
        case let .signIn(returning):
            if case let .signedOut(_, reason) = state {
                return .signIn(returning: returning, endedByServer: reason == .revoked)
            }
            return .signIn(returning: returning, endedByServer: false)
        case .inviteGate, .youreIn:
            return .inviteGate
        case .paused:
            return .paused
        case .journal:
            return storeOpenFailed ? .storeFailed : .journal
        }
    }

    /// An approved person whose store failed gets the retry page; one whose flag is not known yet waits (never the
    /// journal, never the moment again), unless the gate is already up for them.
    private static func approvedHold(_ state: Session.State, gateHeld: Bool, storeOpenFailed: Bool, youreInSeen: Bool?) -> Screen? {
        guard case .signedIn(_, .approved) = state, !gateHeld else { return nil }
        if storeOpenFailed {
            return .storeFailed
        }
        return youreInSeen == nil ? .blank : nil
    }

    /// A release build always opens this root. Debug builds do too, unless `-OldHome` asks for the old app.
    static func isDefault(arguments: [String], debug: Bool) -> Bool {
        !(debug && arguments.contains("-OldHome"))
    }

    @Environment(Platform.AppEnvironment.self) private var platform
    @Environment(\.openURL) private var openURL
    @State private var gateHeld = false
    /// This person's persisted "begin pressed" flag (`PersonFlags`, per person, erased on Log Out); nil until the store is open.
    @State private var youreInSeen: Bool?

    var body: some View {
        let screen = Self.screen(
            for: platform.sessionState, pendingCode: platform.pendingInvite.hasCode,
            gateHeld: gateHeld, storeOpenFailed: platform.storeOpenFailed, youreInSeen: youreInSeen,
            updateRequired: platform.updateRequired
        )
        Group {
            switch screen {
            case .updateRequired:
                // replaces the page outright, so the journal's own covers (the account page) go with it
                ForceUpdateScreen(model: ForceUpdateModel(open: { openURL($0) }))
            case let .signIn(returning, endedByServer):
                // the splash or welcome back; the session's new state moves the app on, the page needs no hand-off
                SignInHost(returning: returning || endedByServer)
            case .inviteGate:
                InviteGateHost { begin() }
                    .onAppear { gateHeld = true }
            case .paused:
                PausedView()
            case .storeFailed:
                StoreFailedView { platform.retryOpeningStore() }
            case .journal:
                LiveJournalRoot()
                    .accessibilityIdentifier("newapp.signedin")
            case .locked:
                Text("retrospect can't read your sign-in yet. unlock your phone and open it again.")
                    .rText(.bodyReading)
                    .foregroundStyle(RColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RDimension.spaceScreenMargin)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RColor.backgroundCanvas.ignoresSafeArea())
                    .accessibilityIdentifier("newapp.locked")
            case .blank:
                RColor.backgroundCanvas.ignoresSafeArea()
            }
        }
        .animation(RMotion.snappy, value: screen)
        .onChange(of: screen) { old, new in
            if Self.announcesUpdatePage(from: old, to: new) {
                AccessibilityNotification.ScreenChanged().post()
            }
        }
        .task { await platform.pendingInvite.refresh() }
        .task(id: flagsIdentity) { youreInSeen = await platform.youreInSeen() }
        // the waiting code is read again whenever something that can change it happens
        .onChange(of: platform.sessionState) { _, state in
            if case .signedOut? = state {
                gateHeld = false // a person who left mid-tear leaves nothing held for the next
            }
            Task { await platform.pendingInvite.refresh() }
        }
        .onChange(of: platform.invites.ticket) { Task { await platform.pendingInvite.refresh() } }
        .onChange(of: platform.invites.previewFace) { Task { await platform.pendingInvite.refresh() } }
    }

    /// Changes when a different person's store (and so flags object) is open, so the flag is read for them.
    private var flagsIdentity: ObjectIdentifier? {
        platform.personFlags.map { ObjectIdentifier($0) }
    }

    /// "begin": remembered for this person on this phone, then the gate lets go.
    private func begin() {
        Task {
            // not remembered (no store open): the gate stays and "begin" can be pressed again, never dropped
            guard await platform.markYoureInSeen() else {
                platform.retryOpeningStore() // no store open: ask for it again, so 'begin' has a way forward
                return
            }
            youreInSeen = true
            gateHeld = false
        }
    }
}
