//
//  SourcePage+Launch.swift
//  V2.settings · ST-4, debug builds only (founder's sandbox rule: no test or state affordance in
//  release): the launcher can open ST-4 with one of its two questions already asked, for stills.
//  The question is spent the first time ST-4 appears, so pushing it again doesn't ask again.
//
#if DEBUG
import SwiftUI

/// The question ST-4 should open with, once.
@MainActor
final class SourcePageLaunchQuestion {
    var asking: SourcePage.Asking?

    init(_ asking: SourcePage.Asking?) {
        self.asking = asking
    }
}

extension EnvironmentValues {
    /// Set only by the launcher (`-Screen ST-4 -State disconnect|delete`).
    @Entry var sourcePageLaunchQuestion: SourcePageLaunchQuestion?
}

/// Asks the launcher's question when ST-4 first appears, then forgets it.
struct SourcePageLaunchAsk: ViewModifier {
    @Binding var asking: SourcePage.Asking?
    @Environment(\.sourcePageLaunchQuestion) private var question

    func body(content: Content) -> some View {
        content.onAppear {
            guard let launched = question?.asking else { return }
            asking = launched
            question?.asking = nil
        }
    }
}
#endif
