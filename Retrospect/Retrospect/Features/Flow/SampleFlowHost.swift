//
//  SampleFlowHost.swift
//  FLOW.host: `-Flow sample` (debug) opens the app here instead of the live root. One switch on the flow's
//  step mounts the existing screens exactly as their launcher scenarios do (no new views, nothing drawn of
//  its own): PI0 with sample taps (a tap signs in a sample person: no Apple sheet, no backend; the real
//  Apple path in `SignInHost` is unchanged), PI1/PI2 on the sample source, ON-3–9 on the sample seam, ON-5
//  on the sample read-aloud (a fresh model per visit). The invite page keeps one identity from the gate to
//  "you're in", so the tear plays on one ticket. The flow ends at the last merged screen: a step with no next
//  edge simply stays. Debug builds only.
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
            case .questions:
                QuestionsPageContainer(
                    data: flow.firstRun,
                    kept: flow.answers,
                    onAnswered: { key, words in flow.answered(key, words: words) },
                    cameBack: flow.cameBack,
                    onDone: { flow.send(.questionsDone) }
                )
            case .privacy:
                FlowPrivacyVisit(flow: flow)
            case .gettingReady:
                GettingReadyPageContainer(
                    firstRun: flow.firstRun,
                    episode: flow.gettingReadyEpisode(),
                    listening: flow.listening,
                    kept: flow.answers[.thisWeek],
                    onAnswered: { key, words in flow.answered(key, words: words) },
                    onReady: { flow.send(.episodeReady) }
                )
            }
        }
        // the same move between pages as the live root's
        .animation(RMotion.snappy, value: flow.step)
        // the kept model only: a model SwiftUI built and dropped never writes
        .onAppear { flow.started() }
    }
}

/// ON-5 for one visit: the model is made when the page arrives and kept while it shows; leaving the step
/// drops it, so a return (back from connect, later) reads again on a fresh one.
private struct FlowPrivacyVisit: View {
    let flow: SampleFlowModel
    @State private var model: PrivacyModel?

    var body: some View {
        if let model {
            PrivacyPage(model: model)
        } else {
            // one model per visit, made as the page arrives (as `PrivacyLaunch` does)
            RColor.backgroundCanvas
                .ignoresSafeArea()
                .onAppear { model = flow.makePrivacy() }
        }
    }
}

#Preview("flow · from the splash") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .splash)) }
#Preview("flow · questions") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .questions)) }
#Preview("flow · privacy") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .privacy)) }
#Preview("flow · getting ready") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .gettingReady)) }
#endif
