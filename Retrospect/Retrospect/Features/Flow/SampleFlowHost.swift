//
//  SampleFlowHost.swift
//  FLOW.host: `-Flow sample` (debug) opens the app here instead of the live root. One switch on the flow's
//  step mounts the existing screens exactly as their launcher scenarios do (no new views, nothing drawn of
//  its own): PI0 with sample taps (a tap signs in a sample person: no Apple sheet, no backend; the real
//  Apple path in `SignInHost` is unchanged), PI1/PI2 on the sample source, ON-3–9 on the sample seam, ON-5
//  on the sample read-aloud (a fresh model per visit). The invite page keeps one identity from the gate to
//  "you're in", so the tear plays on one ticket. The flow ends at the last merged screen: a step with no next
//  edge stays, and once its page hands on to a screen not built yet, a small "start over" pill shows (the
//  host's only drawing; founder, 27 Oct). Debug builds only.
//
#if DEBUG
import SwiftUI

struct SampleFlowHost: View {
    @State private var flow: SampleFlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    seamFinished: flow.questionsFinished,
                    onDone: { flow.send(.questionsDone) }
                )
            case .privacy:
                FlowPrivacyVisit(flow: flow)
            case .connect:
                ConnectPageContainer(
                    data: flow.connect,
                    onDone: { _ in flow.send(.connectDone) },
                    onBack: { flow.send(.connectBack) }
                )
            case .gettingReady, .tease:
                // one identity for both steps: getting ready stays mounted under the tease, so nothing
                // typed there is lost when the sheet rises (review-201 m6)
                GettingReadyPageContainer(
                    firstRun: flow.firstRun,
                    episode: flow.gettingReadyEpisode(),
                    listening: flow.listening,
                    kept: flow.answers[.thisWeek],
                    onAnswered: { key, words in flow.answered(key, words: words) },
                    onReady: { flow.send(.episodeReady) }
                )
            case .paywall:
                // the tease's sheet slides away as the paywall arrives with its mini-player (PW-Q2 A)
                FlowPaywallVisit(flow: flow)
            }
        }
        // getting ready stays mounted under the tease but out of reach: VoiceOver stays on the sheet
        .accessibilityHidden(flow.sheetCoversPage)
        // and out of touch: a field still focused there lets go, so no keyboard stays up over the sheet
        .disabled(flow.sheetCoversPage)
        // ON-11: the tease rises over getting ready as the player sheet, exactly as `-Screen player` shows it;
        // modal for VoiceOver, as RSheetHost's sheets are, so nothing behind it can be reached (QA 7)
        .overlay {
            if flow.sheetCoversPage {
                PlayerSheetScreen {
                    PlayerSheet(model: flow.teaseSheet())
                }
                // the end pill sits inside the modal layer, so VoiceOver can still reach it over the sheet
                .overlay(alignment: .top) { endPill }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .animation(RMotion.sheet, value: flow.sheetCoversPage)
        // the end of what's built (sample flow only): a small pill to walk it again, so a page that handed on
        // to a screen not built yet never looks frozen (over the tease, the sheet's layer carries it)
        .overlay(alignment: .top) {
            if !flow.sheetCoversPage {
                endPill
            }
        }
        // the same move between pages as the live root's
        .animation(RMotion.snappy, value: flow.step)
        .animation(RMotion.snappy, value: flow.isAtEnd)
        // the kept model only: a model SwiftUI built and dropped never writes
        .onAppear { flow.started() }
    }

    @ViewBuilder private var endPill: some View {
        if flow.isAtEnd {
            FlowEndPill { flow = flow.startedOver() }
                .padding(.top, RDimension.space2)
                .transition(.opacity)
        }
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

/// ON-12 for one visit: the model is made as the page arrives and kept while it shows (as `PaywallLaunch`
/// does); a left paywall never fires again.
private struct FlowPaywallVisit: View {
    let flow: SampleFlowModel
    @State private var model: PaywallModel?

    var body: some View {
        if let model {
            PaywallPage(model: model)
        } else {
            RColor.backgroundCanvas
                .ignoresSafeArea()
                .onAppear { model = flow.makePaywall() }
        }
    }
}

/// "end of what's built · tap to start over": the sample flow's only own drawing, styled as the invite page's
/// hint pill (label text on a wash). Debug builds only; never in the release app.
private struct FlowEndPill: View {
    static let words = "end of what's built · tap to start over"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(Self.words)
                .rText(.pillAction)
                .foregroundStyle(RColor.textSecondary)
                .padding(.horizontal, RDimension.space3)
                .frame(minHeight: RDimension.sizeControlSmall)
                .rWash()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("flow.end")
    }
}

#Preview("flow · from the splash") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .splash)) }
#Preview("flow · questions") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .questions)) }
#Preview("flow · privacy") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .privacy)) }
#Preview("flow · connect") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .connect)) }
#Preview("flow · the tease") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .tease)) }
#Preview("flow · the paywall") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .paywall)) }
#Preview("flow · getting ready") { SampleFlowHost(flow: SampleFlowModel(store: MemoryFlowStore(), start: .gettingReady)) }
#endif
