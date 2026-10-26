//
//  RVoiceComposerPaper.swift
//  SH.composer: the voice composer's surface exactly as Paper draws it, next to today's
//  (RVoiceComposer's own `surface`), chosen with `RVoiceComposer(look: .paper)`. Behaviour, words,
//  the corner button, haptics and accessibility stay in RVoiceComposer.swift: only the surface
//  differs, so the component keeps one home.
//
//  Tokens depth.boxShadow.composer.rest / .listening. Paper (file 01M5D5J321P5X86ZT58002B7NT), first on top:
//  - at rest (speaking, muted, typing: ON-5 1F7K-0, ON-13 1FIS-0, parts B0C-0 / B0R-0 / B10-0):
//    inset 0 1 0 depth.stroke.innerTop · inset 0 0 0 1 depth.stroke.inner · 0 0 0 0.5
//    depth.stroke.outer · 0 1 2 contact · 0 12 28 −12 cast · 0 24 60 −20 ambient
//    (the last three are depth.tier.floating).
//  - listening (ON-3..9 1F6E-0, ON-10 26LI-0, part GEG-0): inset 0 1 0 innerTop · 0 0 0 0.5
//    glow.primary.ring · then depth.glow.listening (contact + four offset sky/amber glows).
//  - thinking: not drawn; it keeps the listening look, as today.
//  Fill background.raised, radius.composer.
//
import SwiftUI

extension RVoiceComposer {
    /// Which surface the bar draws (see RDepthLook): today's, or Paper's box-shadows exactly.
    typealias Look = RDepthLook
}

/// The bar's surface in Paper's look: raised at rest, the listening edge and glows while lit.
struct RComposerPaperSurface: View {
    let isLit: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    /// Paper's rest and listening stacks, whole, from tokens (depth.boxShadow.composer.*).
    static let rest = RElevation.boxShadowComposerRest
    static let listening = RElevation.boxShadowComposerListening

    var body: some View {
        let radius = RDimension.radiusComposer
        let shape = RShape.rect(radius)
        ZStack {
            shape.fill(RColor.backgroundRaised)
                .rBoxShadows(Self.rest, radius: radius)
                .opacity(isLit ? 0 : 1)
            shape.fill(RColor.backgroundRaised)
                .rBoxShadows(Self.listening, radius: radius)
                .opacity(isLit ? 1 : 0)
            // Increase Contrast: a 1pt border.control ring at rest (voice-composer.md), as today
            if contrast == .increased, !isLit {
                shape.strokeBorder(RColor.borderControl, lineWidth: RDimension.sizeBorderDefault)
            }
        }
        .animation(RMotion.standard(RNumber.motionDurationSlow), value: isLit)
        .accessibilityHidden(true)
    }
}

#if DEBUG
/// Both looks, every state, side by side: today's on the left of each pair, Paper's on the right
/// (lab page "composer"; `-DesignLab -DesignLabPage composer`). `-ComposerStage current|paper`
/// shows one speaking bar where ON-5 draws it (24 in, 40 from the bottom), for the 1:1 comparison.
struct RComposerLooksGallery: View {
    @State private var typed = "i think it's the 9am standup. i dread it, every week."
    @State private var none = ""
    @State private var live: RVoiceComposer.Mode = .listening
    @State private var liveText = ""
    @State private var liveLook = RVoiceComposer.Look.paper

    private struct Row {
        let name: String
        let mode: RVoiceComposer.Mode
        var typing = false
    }

    private static let states = [
        Row(name: "listening", mode: .listening),
        Row(name: "speaking", mode: .speaking),
        Row(name: "muted, empty", mode: .muted),
        Row(name: "muted, typing", mode: .muted, typing: true),
        Row(name: "thinking (not drawn: listening look)", mode: .thinking),
    ]

    var body: some View {
        if let stage = Self.stage {
            RComposerStage(look: stage)
        } else if let pill = Self.pillStage {
            RPillStage(look: pill)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: RDimension.space8) {
                    ForEach(Self.states.indices, id: \.self) { index in
                        let state = Self.states[index]
                        pair(state.name, state.mode, typing: state.typing)
                    }
                    pills
                    liveBar
                }
                .padding(.horizontal, RDimension.spaceScreenMargin)
                .padding(.vertical, RDimension.space8)
            }
            .scrollClipDisabled()
            .background(RColor.backgroundCanvas)
        }
    }

    private func pair(_ name: String, _ mode: RVoiceComposer.Mode, typing: Bool) -> some View {
        VStack(alignment: .leading, spacing: RDimension.space3) {
            Text(name).rText(.labelMedium).foregroundStyle(RColor.textSecondary)
            ForEach([RVoiceComposer.Look.current, .paper], id: \.self) { look in
                VStack(alignment: .leading, spacing: RDimension.space2) {
                    Text(look == .paper ? "paper" : "today").rText(.label).foregroundStyle(RColor.textTertiary)
                    RVoiceComposer(mode: .constant(mode), text: typing ? $typed : $none, look: look)
                }
            }
        }
    }

    private var pills: some View {
        VStack(alignment: .leading, spacing: RDimension.space3) {
            Text("raised pill (connect)").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
            HStack(spacing: RDimension.space4) {
                RPill(title: "connect", symbol: "plus", style: .raised) {}
                RPill(title: "connect", symbol: "plus", style: .raised, look: .paper) {}
            }
            HStack(spacing: RDimension.space4) {
                RPill(title: "connect", style: .action) {}
                RPill(title: "connect", style: .action, look: .paper) {}
            }
        }
    }

    private var liveBar: some View {
        VStack(alignment: .leading, spacing: RDimension.space3) {
            Text("live").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
            RVoiceComposer(mode: $live, text: $liveText, look: liveLook)
            HStack(spacing: RDimension.space2) {
                Button("listen") { live = .listening }
                Button("speak") { live = .speaking }
                Button("think") { live = .thinking }
                Button("mute") { live = .muted }
                Button(liveLook == .paper ? "today" : "paper") {
                    liveLook = liveLook == .paper ? .current : .paper
                }
            }
            .rText(.label)
            .foregroundStyle(RColor.textLink)
        }
    }

    /// `-ComposerStage current|paper`.
    static var stage: RVoiceComposer.Look? {
        switch UserDefaults.standard.string(forKey: "ComposerStage") {
        case "paper": .paper
        case "current": .current
        default: nil
        }
    }

    /// `-ComposerStage pill-current|pill-paper`.
    static var pillStage: RVoiceComposer.Look? {
        switch UserDefaults.standard.string(forKey: "ComposerStage") {
        case "pill-paper": .paper
        case "pill-current": .current
        default: nil
        }
    }
}

/// The `+ connect` pill alone, where ON-6 · connect (2190-0) draws its first one (c:pill/raised/rest
/// 219H-0: 284 from the left, 624.5 from the top of the screen), for paper-compare at 4x.
private struct RPillStage: View {
    let look: RVoiceComposer.Look
    private static let paperX: CGFloat = 284 // literal-ok: Paper 219H-0 position on 2190-0
    private static let paperY: CGFloat = 624.5 // literal-ok: Paper 219H-0 position on 2190-0

    var body: some View {
        // The lab's page picker sits above the stage, so place the pill against the screen, not the stage.
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            RPill(title: "connect", symbol: "plus", style: .raised, look: look) {}
                .fixedSize()
                .offset(x: Self.paperX - origin.x, y: Self.paperY - origin.y)
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
    }
}

/// One speaking bar on the canvas where ON-5 (16FA-0) draws it: 24 in from each side and 40 above
/// the screen's bottom edge (1F7J-0), with nothing else in the lower half, for paper-compare.
private struct RComposerStage: View {
    let look: RVoiceComposer.Look
    @State private var none = ""

    private static let paperX: CGFloat = 24 // literal-ok: Paper 1F7K-0 frame on 16FA-0
    private static let paperY: CGFloat = 778 // literal-ok: Paper 1F7K-0 frame on 16FA-0
    private static let paperWidth: CGFloat = 354 // literal-ok: Paper 1F7K-0 frame on 16FA-0

    var body: some View {
        // The lab's page picker and safe area wrap the stage, so place the bar against the screen.
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            RVoiceComposer(mode: .constant(.speaking), text: $none, look: look)
                .frame(width: Self.paperWidth)
                .offset(x: Self.paperX - origin.x, y: Self.paperY - origin.y)
        }
        .background(RColor.backgroundCanvas.ignoresSafeArea())
    }
}

#Preview("composer looks") { RComposerLooksGallery() }
#endif
