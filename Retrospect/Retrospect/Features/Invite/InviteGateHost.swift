//
//  InviteGateHost.swift
//  APP-ROOT: mounts the invite gate (PI1) and the tear (PI2) on the real doors. Signed out with a code
//  waiting, it opens at the promise and signs in on the page itself; signed in, it checks the waiting code
//  (or takes a typed one). It feeds the page the phone's connection, and tells the root when the person
//  presses "begin" (or was already in), which is the one moment the gate lets go. Until then the root keeps
//  the page up even though the tear has already made the person a member.
//
import SwiftUI

struct InviteGateHost: View {
    /// "begin" pressed, or the person was already in: the root moves on to the journal.
    let finished: () -> Void
    @Environment(Platform.AppEnvironment.self) private var platform
    @State private var model: InviteModel?

    var body: some View {
        Group {
            if let model {
                InviteScreen(model: model)
                    .task { await model.watch(platform.reachability.changes()) }
                    .onChange(of: platform.invites.previewFace) { _, face in model.setPreview(face) }
                    // access changes after the page is up (a renewal, a person let in): the page hears it
                    .task(id: access) {
                        if let access {
                            await model.startSignedIn(access: access)
                        }
                    }
            } else {
                RColor.backgroundCanvas.ignoresSafeArea()
            }
        }
        .task {
            guard model == nil else { return }
            let made = Self.makeModel(platform: platform)
            made.onFinish = finished
            model = made
        }
    }

    private var access: Session.AccessState? {
        if case let .signedIn(_, access)? = platform.sessionState {
            access
        } else {
            nil
        }
    }

    /// The page for the session as it is now: the promise when signed out, the typed ticket when signed in.
    static func makeModel(platform: Platform.AppEnvironment) -> InviteModel {
        let source = LiveInviteSource(
            center: platform.invites,
            pendingCode: { [pending = platform.pendingInvite] in await pending.code() },
            onBegin: {}
        )
        let signedIn = if case .signedIn? = platform.sessionState {
            true
        } else {
            false
        }
        return InviteModel(
            phase: signedIn ? .typed : .promise, source: source, signIn: LiveSignIn(platform.signIn),
            preview: signedIn ? nil : platform.invites.previewFace
        )
    }
}
