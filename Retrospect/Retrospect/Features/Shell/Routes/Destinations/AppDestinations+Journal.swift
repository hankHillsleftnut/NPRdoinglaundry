//
//  AppDestinations+Journal.swift
//  G0: the journal group's pages in the app route table (JR-2 today's brief, JR-4 one entry (lane 1: #233 /
//  #235)). Only this group builds them, and only this file lists them: build a page in `page(for:in:)` /
//  `sheet(for:in:)` (data from the environment, as in the launcher) and remove its kind from `notBuilt` in
//  the same change. AppRouteTableTests fails a kind that is built and still listed, or listed nowhere. The
//  pages themselves live in JournalV2 (Features/Entries).
//
//  DEMO.app.b: JR-4 is pushed from any stack (the drawer's rows, GL-2's "your words") on `\.entriesData`,
//  in the app's cut (EntryCapabilities.cut); JR-2 rises over the shell (the brief card) on
//  `\.briefSheetSource`, and its collapse goes back down (SCREEN-MAP row 52; no mini-player: not drawn).
//
import SwiftUI

extension EnvironmentValues {
    /// The entries JR-3 and JR-4 read, for pages opened from any stack (the demo's sample).
    @Entry var entriesData: (any EntriesData)?
    /// What JR-2 plays and shows when the brief card raises it (the demo's sample player and brief).
    @Entry var briefSheetSource: BriefSheetSource?
}

/// JR-2's player and words, from the host.
struct BriefSheetSource {
    let playback: any Flows.Playback
    let content: BriefSheetContent
}

extension AppDestinations {
    enum Journal: AppDestinationGroup {
        static let group = AppRouteGroup.journal

        static func page(for route: AppRoute, in context: AppRouteContext) -> AnyView? {
            guard case let .entry(id) = route else { return nil }
            return AnyView(EntryRoutePage(id: id, context: context))
        }

        static func sheet(for sheet: AppSheet, in context: AppRouteContext) -> AnyView? {
            guard case .brief = sheet else { return nil }
            return AnyView(BriefRouteSheet(context: context))
        }

        static let notBuilt: Set<AppRoute.Kind> = []
        static let sheetsNotBuilt: Set<AppSheet.Kind> = []
    }
}

/// JR-4 on the environment's entries; back pops it. Without the entries it is the canvas.
private struct EntryRoutePage: View {
    let id: String
    let context: AppRouteContext
    @Environment(\.entriesData) private var data

    var body: some View {
        Group {
            if let data {
                EntryScreen(id: id, data: data, back: context.back)
            } else {
                RColor.backgroundCanvas.ignoresSafeArea()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// JR-2 on the environment's player and brief, built once per rise; the collapse closes the sheet.
private struct BriefRouteSheet: View {
    let context: AppRouteContext
    @Environment(\.briefSheetSource) private var source
    @State private var model: BriefSheetModel?

    var body: some View {
        if let model {
            BriefSheet(model: model)
                .rMenuHost()
        } else if let source {
            RColor.backgroundCanvas
                .onAppear {
                    model = BriefSheetModel(playback: source.playback, content: source.content, onCollapse: context.back)
                }
        } else {
            RColor.backgroundCanvas
        }
    }
}
