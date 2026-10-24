//
//  SampleFlowHost.swift
//  FLOW.host: `-Flow sample` (debug) opens the app here instead of the live root. One switch on the flow's
//  step mounts the existing screens exactly as their launcher scenarios do (no new views, nothing drawn of
//  its own): PI0 with sample taps (a tap signs in a sample person: no Apple sheet, no backend; the real
//  Apple path in `SignInHost` is unchanged), PI1/PI2 on the sample source, ON-3–9 on the sample seam. The
//  invite page keeps one identity from the gate to "you're in", so the tear plays on one ticket. The flow
//  ends at the last merged screen: a step with no next edge simply stays. Debug builds only.
//
#if DEBUG
import SwiftUI

struct SampleFlowHost: View {
    @State private var flow: SampleFlowModel

    init(launch: FlowLaunch = .current) {
        _flow = State(initialValue: SampleFlowModel(store: UserDefaultsFlowStore(), start: launch.start))
    }

    init(flow: SampleFlowModel) {
        _flow = State(initialValue: flow)
    }

    var body: some View {
        Group {
            switch flow.step {
            case .splash:
                SignInScreen(model: flow.signIn, sampleTaps: true)
            case .inviteGate, .youreIn:
                InviteScreen(model: flow.invite, sampleTaps: true)
                    .onChange(of: flow.invite.phase) { _, phase in flow.inviteMoved(to: phase) }
            case .questions:
                QuestionsPageContainer(
                    data: flow.firstRun,
                    kept: flow.answers,
                    onAnswered: { key, words in flow.answered(key, words: words) },
                    onDone: { flow.send(.questionsDone) }
                )
            }
        }
        // the same move between pages as the live root's
        .animation(RMotion.snappy, value: flow.step)
    }
}

#Preview("flow · from the splash") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .splash)) }
#Preview("flow · questions") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .questions)) }
#endif
