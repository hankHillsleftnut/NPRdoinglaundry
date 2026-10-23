//
//  ForceUpdateScreens+Launcher.swift
//  PX in the launcher (T02): `-Screen PX -State rest|offline|noStoreLink`, on sample data. `offline` is
//  the same page (the button still opens the store, no extra line); `noStoreLink` is the build with no
//  App Store id yet: the words stay and the button is hidden.
//
#if DEBUG
import SwiftUI

enum ForceUpdateScenario: String, CaseIterable {
    case rest, offline, noStoreLink
}

extension ScreenRegistry {
    static let forceUpdateScreens: [LaunchableScreen] = [
        LaunchableScreen(id: "PX", states: ForceUpdateScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(ForceUpdateLaunch(scenario: ForceUpdateScenario(rawValue: arguments.state) ?? .rest))
        },
    ]
}

struct ForceUpdateLaunch: View {
    let scenario: ForceUpdateScenario

    var body: some View {
        // an invented id: the sample never holds the real one
        ForceUpdateScreen(model: ForceUpdateModel(storeURL: scenario == .noStoreLink ? nil : AppStoreLink.url(id: "0000000000"), open: { _ in }))
    }
}

#Preview("force update") { ForceUpdateLaunch(scenario: .rest) }
#Preview("force update · no link") { ForceUpdateLaunch(scenario: .noStoreLink) }
#endif
