//
//  ForceUpdateScreens+Launcher.swift
//  PX in the launcher (T02): `-Screen PX -State rest|offline|noStoreLink|cover`, on sample data. `offline`
//  is the same page (the button still opens the store, no extra line); `noStoreLink` is the build with no
//  App Store id yet: the words stay and the button is hidden; `cover` is the journal with the cover
//  arriving over it 1.5 s in, the way a 426 lands mid-session (for the fade and the nothing-behind check).
//
#if DEBUG
import SwiftUI

enum ForceUpdateScenario: String, CaseIterable {
    case rest, offline, noStoreLink, cover
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
    @State private var required = false

    /// an invented id: the sample never holds the real one
    private var model: ForceUpdateModel {
        ForceUpdateModel(storeURL: scenario == .noStoreLink ? nil : AppStoreLink.url(id: "0000000000"), open: { _ in })
    }

    var body: some View {
        if scenario == .cover {
            JournalLaunch(scenario: .full)
                .rForceUpdateCover(isRequired: required, model: model)
                .task {
                    try? await Task.sleep(for: .milliseconds(1500))
                    required = true
                }
        } else {
            ForceUpdateScreen(model: model)
        }
    }
}

#Preview("force update") { ForceUpdateLaunch(scenario: .rest) }
#Preview("force update · no link") { ForceUpdateLaunch(scenario: .noStoreLink) }
#endif
