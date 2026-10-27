//
//  YouStack.swift
//  V2.you: the You tab's pushes as typed routes (ios-navigation-and-flows): YO-3 a source and YO-5 what
//  i know about you push over the tab page; back pops. A screen of another group (a goal, settings) is
//  pushed only when this build has it: the launcher hands in `elsewhere`, which looks the id up in the
//  screen registry; without it the control isn't a button (integrator rule, DISCREPANCIES YO-D14).
//  The system bar is hidden: every page draws its own RTopBar; the edge swipe still goes back.
//
import SwiftUI

enum YouRoute: Hashable {
    /// YO-5.
    case whatIKnow
    /// YO-3, by source id.
    case source(String)
    /// Another group's screen, by its launcher id ("GL-2").
    case elsewhere(String)
}

@MainActor
@Observable
final class YouNavigator {
    var path: [YouRoute]
    /// Whether this build has another group's screen, by id (a plain registry lookup, nothing built).
    let has: (String) -> Bool
    /// Builds another group's screen by id, only when it is pushed.
    let elsewhere: (String) -> AnyView?

    init(
        path: [YouRoute] = [],
        has: @escaping (String) -> Bool = { _ in false },
        elsewhere: @escaping (String) -> AnyView? = { _ in nil }
    ) {
        self.path = path
        self.has = has
        self.elsewhere = elsewhere
    }

    func push(_ route: YouRoute) {
        path.append(route)
    }

    func pop() {
        _ = path.popLast()
    }

    /// The goal screen's launcher id (the goals group, GL-2).
    static let goalScreenID = "GL-2"

    /// What a "this supports" row opens: YO-5 for an answer; a goal only when GL-2 is in this build.
    func opener(for supported: Flows.Supported) -> (() -> Void)? {
        switch supported.kind {
        case .knowledge:
            return { [weak self] in self?.push(.whatIKnow) }
        case .goal:
            guard has(Self.goalScreenID) else { return nil }
            return { [weak self] in self?.push(.elsewhere(Self.goalScreenID)) }
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
        case let .elsewhere(id):
            navigator.elsewhere(id)
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
