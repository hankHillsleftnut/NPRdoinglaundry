//
//  LiveAccountPage.swift
//  APP-ROOT / P33: the account page on the real platform. It reads how many entries haven't sent before the
//  page shows (so the sheet opens with the truth), then hands the sign-out sheet the live flow.
//
import SwiftUI

struct LiveAccountPage: View {
    let back: () -> Void
    @Environment(Platform.AppEnvironment.self) private var platform
    @State private var flow: LiveSignOutFlow?

    var body: some View {
        Group {
            if let flow {
                AccountPage(flow: flow, back: back)
            } else {
                RColor.backgroundCanvas.ignoresSafeArea()
            }
        }
        .task {
            if flow == nil {
                flow = await LiveSignOutFlow.make(platform: platform)
            }
        }
    }
}
