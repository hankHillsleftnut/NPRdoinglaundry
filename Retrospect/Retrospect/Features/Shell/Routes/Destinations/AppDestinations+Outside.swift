//
//  AppDestinations+Outside.swift
//  G0: the outside group's pages in the app route table (EX-1 share, as the app shows it (lane 5: #220)).
//  Only this group builds them, and only this file lists them: build a page in `page(for:in:)` /
//  `sheet(for:in:)` (data from the environment, as in the launcher) and remove its kind from `notBuilt` in
//  the same change. AppRouteTableTests fails a kind that is built and still listed, or listed nowhere. The
//  pages themselves live in Features/Outside.
//
//  DEMO.app.c: EX-1 rises over the shell on `\.shareData` (the app's sheet stands in for the extension's
//  until W7), with the sheet host's grabber only; save or cancel closes it, and with no share data it
//  closes at once (never a blank sheet).
//
import SwiftUI

extension EnvironmentValues {
    /// EX-1's item and save, when the host has them (the demo's sample).
    @Entry var shareData: (any ShareData)?
}

extension AppDestinations {
    enum Outside: AppDestinationGroup {
        static let group = AppRouteGroup.outside

        static func page(for _: AppRoute, in _: AppRouteContext) -> AnyView? {
            nil
        }

        static func sheet(for sheet: AppSheet, in context: AppRouteContext) -> AnyView? {
            guard case .share = sheet else { return nil }
            return AnyView(ShareRouteSheet(context: context))
        }

        static let notBuilt: Set<AppRoute.Kind> = []
        static let sheetsNotBuilt: Set<AppSheet.Kind> = []
    }
}

/// EX-1 on the environment's share data, built once per rise; it closes the sheet when it is done.
private struct ShareRouteSheet: View {
    let context: AppRouteContext
    @Environment(\.shareData) private var data
    @State private var model: ShareModel?

    var body: some View {
        if let model {
            // the sheet host draws the grabber: one, not two
            SharePage(model: model, drawsGrabber: false)
                .onChange(of: model.state) { _, state in
                    if case .closed = state {
                        context.back()
                    }
                }
        } else {
            RColor.backgroundCanvas.onAppear {
                if let data {
                    model = ShareModel(data: data)
                } else {
                    context.back()
                }
            }
        }
    }
}
