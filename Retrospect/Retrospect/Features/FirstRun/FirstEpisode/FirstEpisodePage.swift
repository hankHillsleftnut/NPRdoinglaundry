//
//  FirstEpisodePage.swift
//  P05.min (ON-10 + ON-11, Alpha 0.1): "your first episode". While it's made, Retro says so in one
//  line; after 15 minutes it says it's slow and offers the journal, so the page is never a dead
//  end. Once made: Retro's line, the artwork, the title, the scrubber and transport (play waits
//  for a tap), and "continue" as the one lit action. Paper has only the ON-10 mid-fi state board
//  and no ON-11 drawing: this is composed from design-system parts (screen-rules 1, 5, 14, 17, 30,
//  31; craft 8) and listed for the founder's approval.
//
import SwiftUI

struct FirstEpisodePage: View {
    let model: FirstEpisodeModel

    @Environment(\.rCompactHeight) private var compact
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase
    @State private var overflows = false
    /// False once the hero artwork was found to push the player below the first screen.
    @State private var heroFits = true

    /// 20 on the smallest phones (craft 8.4), 24 elsewhere.
    private var margin: CGFloat {
        compact ? RDimension.space5 : RDimension.spaceScreenMargin
    }

    /// The hero on a full phone; the player size on a short one or at large text, so the title and
    /// the controls stay on the first screen.
    private var artworkSize: CGFloat {
        compact || dynamicTypeSize.isAccessibilitySize || !heroFits ? RDimension.sizeArtworkPlayer : RDimension.sizeArtworkHero
    }

    var body: some View {
        VStack(spacing: RDimension.space0) {
            bar
            GeometryReader { proxy in
                ScrollView {
                    content
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                            // the player belongs on the first screen: if the hero pushes it off, step down once
                            if model.episodeTitle != nil, height > proxy.size.height {
                                heroFits = false
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height > geometry.containerSize.height
                } action: { _, now in
                    overflows = now
                }
                .rProgressiveBlur(.tabEdge, active: overflows)
            }
            // under the scroll, never over it: the controls can't slide beneath the button
            action
                .padding(.top, RDimension.space2)
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.gentle, value: model.look)
        .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.gentle, value: model.isPlayerLoaded)
        .onAppear { model.appear() }
        .onDisappear { model.leave() }
        // the app going away is leaving too (onDisappear doesn't fire on backgrounding): no audio
        // without a control on screen, no asking in the background; back on screen, asking resumes
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: model.leave()
            case .active: model.appear()
            default: break
            }
        }
        .accessibilityIdentifier("screen.ON-11")
    }

    // MARK: Bar

    /// The small centred name, as the top bar draws it; no back (first run goes forward only) and
    /// nothing on the right (screen-rules 6).
    private var bar: some View {
        Text(FirstEpisodeModel.barTitle)
            .rText(.barTitle)
            .foregroundStyle(contrast == .increased ? RColor.textPrimary : RColor.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, RDimension.space4)
            .frame(maxWidth: .infinity, minHeight: RDimension.sizeNavBar)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Content

    private var content: some View {
        VStack(alignment: .leading, spacing: compact ? RDimension.space5 : RDimension.space6) {
            if let line = headline {
                VStack(alignment: .leading, spacing: RDimension.space3) {
                    Text(line)
                        .rText(.inkTitle)
                        .foregroundStyle(RColor.textPrimary)
                        // craft 9.4: three lines, then the ellipsis; AX sizes wrap in full and scroll
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("firstepisode.headline")
                    if model.look == .slow {
                        Text(FirstEpisodeModel.slowDescription)
                            .rText(.body)
                            .foregroundStyle(RColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(line)
                .rBlurReplace()
            }
            if let title = model.episodeTitle {
                episode(title)
                    .transition(arrival)
            }
        }
        .padding(.horizontal, margin)
        .padding(.top, compact ? RDimension.space2 : RDimension.space4)
        .padding(.bottom, RDimension.space6)
    }

    /// Retro's line: the wait, the slow wait, or "it's ready"; none when the audio isn't there
    /// (the title says it all, and there's nothing to listen to).
    private var headline: String? {
        switch model.look {
        case .waiting: FirstEpisodeModel.waitingLine
        case .slow: FirstEpisodeModel.slowLine
        case .ready: FirstEpisodeModel.readyLine
        case .unavailable: nil
        }
    }

    private func episode(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: RDimension.space4) {
            RArtwork(recipe: RArtworkRecipes.weekly, size: artworkSize)
                .frame(maxWidth: .infinity)
            Text(title)
                .rText(.inkCard)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("firstepisode.title")
            if model.look == .ready, model.isPlayerLoaded {
                VStack(spacing: RDimension.space4) {
                    RScrubber(playback: model.playback)
                    RTransport(playback: model.playback)
                }
                .padding(.top, RDimension.space2)
                .transition(arrival)
            }
        }
    }

    /// New content rises a little and fades in; Reduce Motion: a fade.
    private var arrival: AnyTransition {
        reduceMotion ? .opacity : .offset(y: RDimension.motionAppearRise).combined(with: .opacity)
    }

    // MARK: Action

    /// The bottom third: "continue" once there's an episode, the quiet journal way out on a slow
    /// wait, nothing while it's simply being made.
    @ViewBuilder private var action: some View {
        switch model.look {
        case .waiting:
            EmptyView()
        case .slow:
            RButton(title: FirstEpisodeModel.journalButton, variant: .text) { model.journalTapped() }
                .accessibilityIdentifier("firstepisode.journal")
                .padding(.horizontal, margin)
                .padding(.bottom, compact ? RDimension.space4 : RDimension.space6)
                .transition(.opacity)
        case .ready, .unavailable:
            RButton(title: FirstEpisodeModel.continueButton) { model.continueTapped() }
                .accessibilityIdentifier("firstepisode.continue")
                .padding(.horizontal, margin)
                .padding(.bottom, compact ? RDimension.space4 : RDimension.space6)
                .transition(.opacity)
        }
    }
}

// MARK: - Lab

#if DEBUG
/// Lab page "firstepisode": the page on each sample scenario, on the real clock (becomes ready
/// after two 10 s refreshes). `-FirstEpisodeScenario <name>` opens one directly (screenshots).
struct FirstEpisodeLab: View {
    @State private var scenario: Flows.FirstEpisodeScenario = {
        let asked = UserDefaults.standard.string(forKey: "FirstEpisodeScenario") ?? ""
        return Flows.FirstEpisodeScenario(rawValue: asked) ?? .becomesReady
    }()

    var body: some View {
        VStack(spacing: RDimension.space0) {
            Picker("scenario", selection: $scenario) {
                ForEach(Flows.FirstEpisodeScenario.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .rText(.labelMedium)
            .tint(RColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RDimension.spaceScreenMargin)
            .accessibilityIdentifier("lab.firstepisode.scenario")
            FirstEpisodeLabPage(scenario: scenario)
                .id(scenario)
        }
    }
}

private struct FirstEpisodeLabPage: View {
    @State private var model: FirstEpisodeModel

    init(scenario: Flows.FirstEpisodeScenario) {
        let clock = ContinuousClock()
        _model = State(initialValue: FirstEpisodeModel(
            source: SampleFirstEpisode(scenario: scenario),
            playback: SamplePlayback(scenario: .briefPaused, clock: clock),
            clock: clock,
            finish: { _ in }
        ))
    }

    var body: some View {
        FirstEpisodePage(model: model)
    }
}

#Preview("first episode") { FirstEpisodeLab() }
#endif
