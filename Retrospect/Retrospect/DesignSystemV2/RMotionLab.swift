//
//  RMotionLab.swift
//  M14 F09: every spring and curve side by side, plus each motion modifier, so the
//  ramps can be tuned and recorded before any component uses them
//  (design-system/principles/motion-system.md §9). DEBUG only, via -DesignLab.
//
import SwiftUI

#if DEBUG
// A debug lab: (name, animation, values) rows read better as tuples here.
// swiftlint:disable large_tuple
/// The lab's pages. `-DesignLabPage parts` opens one directly (for screenshots and recordings).
enum RLabPage: String, CaseIterable, Identifiable {
    case motion, foundation, parts, artwork, toast
    case offline
    case evidence
    case guess

    var id: String {
        rawValue
    }

    /// `-DesignLabToast` still opens straight on the toast page (for testing on a phone).
    static var launch: RLabPage {
        if ProcessInfo.processInfo.arguments.contains("-DesignLabToast") {
            return .toast
        }
        return UserDefaults.standard.string(forKey: "DesignLabPage").flatMap(RLabPage.init(rawValue:)) ?? .motion
    }
}

struct RDesignLab: View {
    @State private var page = RLabPage.launch

    var body: some View {
        VStack(spacing: 0) {
            Picker("lab", selection: $page) {
                ForEach(RLabPage.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, RDimension.spaceScreenMargin)
            .padding(.vertical, RDimension.space2)
            switch page {
            case .motion: RMotionLab()
            case .foundation: RFoundationGallery()
            case .parts:
                ScrollView {
                    VStack(alignment: .leading, spacing: RDimension.space8) {
                        RParts1Gallery()
                        RParts2Gallery()
                    }
                }
            case .artwork: RArtworkLab()
            case .toast: RToastGallery()
            case .offline: ROfflineLineGallery()
            case .evidence: REvidenceRowGallery()
            case .guess: RGuessCardGallery()
            }
        }
        .background(RColor.backgroundCanvas)
        .rLifeHost()
        .rReadsScreenHeight()
    }
}

struct RMotionLab: View {
    /// Toggled by "run": every track moves from left to right (and back on the next run).
    @State private var forward = false
    @State private var popCount = 0
    @State private var shakeCount = 0
    @State private var word = "a little"
    @State private var listShown = false

    private let springs: [(String, Animation, String)] = [
        ("snappy", RMotion.snappy, "0.25 · 0.82"),
        ("popover", RMotion.popover, "0.30 · 0.74"),
        ("sheetDismiss", RMotion.sheetDismiss, "0.32 · 0.90"),
        ("pop", RMotion.pop, "0.35 · 0.60"),
        ("sheet", RMotion.sheet, "0.40 · 0.86"),
        ("map", RMotion.map, "0.45 · 0.80"),
        ("settle", RMotion.settle, "0.45 · 0.70"),
        ("gentle", RMotion.gentle, "0.55 · 0.92"),
    ]
    private var curves: [(String, Animation, String)] {
        [
            ("standard 280", RMotion.standard(RNumber.motionDurationSlow), "0.16 1 0.3 1"),
            ("move 420", RMotion.move(RNumber.motionDurationTranscriptFollow), "0.65 0 0.35 1"),
            ("exit 110", RMotion.exit(RNumber.motionDurationPopoverExit), "0.4 0 1 1"),
            ("reveal", RMotion.reveal, "smooth 1.22"),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                Button("run") {
                    forward.toggle()
                    popCount += 1
                    shakeCount += 1
                    withAnimation(RMotion.standard(RNumber.motionDurationSlow)) {
                        word = word == "a little" ? "well" : "a little"
                    }
                    listShown.toggle()
                }
                .rText(.buttonLabel)
                .frame(maxWidth: .infinity, minHeight: RDimension.sizeControlHero)
                .rLit()
                .rPress(haptic: RHaptic.press)
                .accessibilityIdentifier("motionlab.run")

                section("springs") { ForEach(springs, id: \.0) { track($0.0, $0.2, $0.1) } }
                section("curves") { ForEach(curves, id: \.0) { track($0.0, $0.2, $0.1) } }

                section("modifiers") {
                    HStack(spacing: RDimension.space4) {
                        Text("pop").rText(.pill).padding(.horizontal, RDimension.space3).frame(height: 32).rSecondary()
                            .rPop(trigger: popCount)
                        Text("shake").rText(.pill).padding(.horizontal, RDimension.space3).frame(height: 32).rSunken()
                            .rShake(trigger: shakeCount)
                        Text("knows you \(word)").rText(.label).foregroundStyle(RColor.textLabel)
                            .rBlurReplace().id(word)
                    }
                    Text("toast · floats").rText(.label).padding(RDimension.space3).rRaised(RDimension.radiusControl)
                        .rFloat()
                    VStack(alignment: .leading, spacing: RDimension.space2) {
                        if listShown {
                            ForEach(0 ..< 5, id: \.self) { i in
                                Text("row \(i + 1) appears").rText(.body).rAppear(index: i)
                            }
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: RDimension.space3) {
                            ForEach(0 ..< 8, id: \.self) { i in
                                RShape.rect(RDimension.radiusPanel)
                                    .fill(RColor.surfaceWash)
                                    .frame(width: 96, height: 96)
                                    .overlay(Text("\(i + 1)").rText(.label))
                                    .rScrollLag()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, RDimension.spaceScreenMargin)
            .padding(.vertical, RDimension.space6)
        }
        .foregroundStyle(RColor.textPrimary)
    }

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: RDimension.space3) {
            Text(title).rText(.labelMedium).foregroundStyle(RColor.textLabel)
            content()
        }
    }

    /// One track: a dot that travels the full width on its animation.
    private func track(_ name: String, _ values: String, _ animation: Animation) -> some View {
        VStack(alignment: .leading, spacing: RDimension.space1) {
            HStack {
                Text(name).rText(.labelMedium)
                Spacer()
                Text(values).rText(.figure).foregroundStyle(RColor.textLabel)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RShape.pill.fill(RColor.surfaceTrack).frame(height: 2)
                    Circle()
                        .fill(RColor.glowPrimaryGradientBottom)
                        .frame(width: 16, height: 16)
                        .offset(x: forward ? geo.size.width - 16 : 0)
                        .animation(animation, value: forward)
                        .accessibilityIdentifier("motionlab.dot.\(name)")
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 20)
        }
    }
}

// swiftlint:enable large_tuple
#Preview("motion lab") { RDesignLab() }
#endif
