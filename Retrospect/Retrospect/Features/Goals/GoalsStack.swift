//
//  GoalsStack.swift
//  V2.goals · the goals tab's stack: GL-1 at the root, GL-2 pushed by a typed route (SCREEN-MAP row 92).
//  Back pops; "turn off" pops and GL-1 reads its list again (row 95). The host says whether the tab
//  bar may show (`onDepthChange`): pushed pages hide it (SCREEN-MAP §5). An entry (JR-4) from GL-2's
//  your-words row is pushed onto the same stack when the host can build one (`entryPage`).
//
import SwiftUI

enum GoalsRoute: Hashable {
    case goal(id: String)
    /// An entry the host builds (JR-4 is the journal group's).
    case entry(id: String)
}

struct GoalsStack: View {
    let model: GoalsModel
    @State private var path: [GoalsRoute]
    /// Builds an entry (JR-4) for GL-2's "your words" row; nil while there is nowhere to show one.
    let entryPage: ((String) -> AnyView)?
    /// Which goals have a GL-2 (the host's data knows); the others are plain cards.
    let canOpen: (String) -> Bool
    /// Whether a page is pushed (the host hides its tab bar).
    let onDepthChange: (Bool) -> Void

    init(
        model: GoalsModel,
        path: [GoalsRoute] = [],
        entryPage: ((String) -> AnyView)? = nil,
        canOpen: @escaping (String) -> Bool = { _ in true },
        onDepthChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.model = model
        _path = State(initialValue: path)
        self.entryPage = entryPage
        self.canOpen = canOpen
        self.onDepthChange = onDepthChange
    }

    var body: some View {
        NavigationStack(path: $path) {
            GoalsPage(model: model, openGoal: { goal in
                path.append(.goal(id: goal.id))
            }, canOpen: { canOpen($0.id) })
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: GoalsRoute.self) { route in
                    switch route {
                    case let .goal(id):
                        GoalDestination(
                            id: id,
                            data: model.data,
                            back: pop,
                            openEntry: entryPage.map { _ in { path.append(.entry(id: $0)) } },
                            turnedOff: {
                                pop()
                                Task { await model.refresh() }
                            }
                        )
                    case let .entry(id):
                        entryPage?(id)
                    }
                }
        }
        .onChange(of: path.isEmpty, initial: true) { _, isEmpty in
            onDepthChange(!isEmpty)
        }
    }

    private func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
}

/// GL-2 for one route: keeps its model for as long as the page is pushed.
private struct GoalDestination: View {
    @State private var model: GoalModel
    let back: () -> Void
    let openEntry: ((String) -> Void)?
    let turnedOff: () -> Void

    init(id: String, data: any GoalsData, back: @escaping () -> Void, openEntry: ((String) -> Void)?, turnedOff: @escaping () -> Void) {
        _model = State(initialValue: GoalModel(goalID: id, data: data))
        self.back = back
        self.openEntry = openEntry
        self.turnedOff = turnedOff
    }

    var body: some View {
        GoalPage(model: model, back: back, openEntry: openEntry, turnedOff: turnedOff)
    }
}
