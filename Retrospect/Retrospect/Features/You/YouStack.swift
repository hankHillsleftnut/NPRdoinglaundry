//
//  YouStack.swift
//  V2.you: the You tab's pushes as typed routes (ios-navigation-and-flows): YO-3 a source and YO-5 what
//  i know about you push over the tab page; back pops. Another group's screen (a goal, settings) is not
//  pushed from here: the registry holds those groups' launchers (each with its own stack and tab bar), not
//  pushable pages, so those controls aren't buttons until the wiring PR connects the groups (YO-D14).
//  The system bar is hidden: every page draws its own RTopBar; the edge swipe still goes back.
//
import SwiftUI

enum YouRoute: Hashable {
    /// YO-5.
    case whatIKnow
    /// YO-3, by source id.
    case source(String)
}

@MainActor
@Observable
final class YouNavigator {
    var path: [YouRoute]

    init(path: [YouRoute] = []) {
        self.path = path
    }

    func push(_ route: YouRoute) {
        path.append(route)
    }

    func pop() {
        _ = path.popLast()
    }

    /// What a "this supports" row opens: YO-5 for an answer; a goal (GL-2, another group) nothing yet.
    func opener(for supported: Flows.Supported) -> (() -> Void)? {
        switch supported.kind {
        case .knowledge:
            return { [weak self] in self?.push(.whatIKnow) }
        case .goal:
            return nil
        }
    }
}

struct YouStack<Root: View>: View {
    let data: any YouData
    @Bindable var navigator: YouNavigator
    @ViewBuilder let root: () -> Root

    var body: some View {
        NavigationStack(path: $navigator.path) {
            root()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: YouRoute.self) { route in
                    YouDestination(route: route, data: data, navigator: navigator)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
    }
}

/// One pushed page; each owns its model for as long as it is on the stack.
private struct YouDestination: View {
    let route: YouRoute
    let data: any YouData
    let navigator: YouNavigator

    var body: some View {
        switch route {
        case .whatIKnow:
            WhatIKnowDestination(data: data, back: navigator.pop)
        case let .source(id):
            SourceScreen(sourceID: id, data: data, navigator: navigator)
        }
    }
}

private struct WhatIKnowDestination: View {
    @State private var model: WhatIKnowModel
    let back: () -> Void

    init(data: any YouData, back: @escaping () -> Void) {
        _model = State(initialValue: WhatIKnowModel(data: data))
        self.back = back
    }

    var body: some View {
        WhatIKnowPage(model: model, back: back)
    }
}

/// YO-3 with its own model, pushed or (in the launcher) at the stack's root.
struct SourceScreen: View {
    @State private var model: SourceModel
    let navigator: YouNavigator

    init(sourceID: String, data: any YouData, navigator: YouNavigator, editing: Bool = false) {
        _model = State(initialValue: SourceModel(sourceID: sourceID, data: data, startsEditing: editing))
        self.navigator = navigator
    }

    var body: some View {
        SourcePage(model: model, back: navigator.pop, open: navigator.opener(for:))
    }
}
