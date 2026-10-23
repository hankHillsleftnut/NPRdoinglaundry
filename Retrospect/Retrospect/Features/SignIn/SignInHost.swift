//
//  SignInHost.swift
//  APP-ROOT: mounts PI0 (the splash for a first-time phone, "welcome back" for one that has signed in here
//  before) on the real Sign in with Apple, and feeds it the phone's connection. The page needs no hand-off:
//  the session's new state is what moves the root on, and the root builds the next page fresh.
//
import SwiftUI

struct SignInHost: View {
    let returning: Bool
    @Environment(Platform.AppEnvironment.self) private var platform
    @State private var model: SignInModel?

    var body: some View {
        Group {
            if let model {
                SignInScreen(model: model)
                    .task { await model.watch(platform.reachability.changes()) }
            } else {
                RColor.backgroundCanvas.ignoresSafeArea()
            }
        }
        .task {
            if model == nil {
                model = SignInModel(look: returning ? .returning : .splash, coordinator: LiveSignIn(platform.signIn))
            }
        }
    }
}
