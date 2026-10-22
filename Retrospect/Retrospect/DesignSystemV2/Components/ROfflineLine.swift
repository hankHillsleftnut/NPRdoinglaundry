//
//  ROfflineLine.swift
//  M14 C39.4: the offline line (design-system/components/loading-and-empty.md, reference §C39).
//  One grey line, never red: the offline glyph in icon.muted and the words in Geist 12
//  text.label, 4 apart, 12 in from the edge (Paper JR-3 drawer · offline, the line under search).
//  It sits above whatever is still showing from the phone. It blur-replaces in and out (exit
//  faster than entrance) and is announced once when it appears. The host page moves the
//  content below with `.animation(RMotion.snappy, value: isOffline)`, so nothing jumps.
//
import SwiftUI

struct ROfflineLine: View {
    /// The two approved lines. Pages keep showing what's saved; the drawer says new notes wait.
    enum Copy: CaseIterable {
        case page, drawer

        var text: String {
            switch self {
            case .page: "you're offline · showing what's saved"
            case .drawer: "offline · new notes send when you're back"
            }
        }
    }

    let copy: Copy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The glyph takes the label's font, so it sits on the label's baseline and grows with
        // Dynamic Type; first-baseline keeps it beside the first line when the words wrap.
        HStack(alignment: .firstTextBaseline, spacing: RDimension.space1) {
            Image(systemName: "wifi.slash")
                .imageScale(.small)
                .foregroundStyle(RColor.iconMuted)
                .accessibilityHidden(true)
            Text(copy.text)
                .foregroundStyle(RColor.textLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .rText(.offlineLine)
        .padding(.horizontal, RDimension.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .transition(transition)
        .onAppear {
            AccessibilityNotification.Announcement(copy.text).post()
        }
    }

    /// In on curve.standard 280; out on curve.exit 200, faster than it came (craft 1.8).
    /// Reduce Motion: a 140ms cross-fade, no blur.
    private var transition: AnyTransition {
        if reduceMotion {
            return AnyTransition.opacity.animation(RMotion.standard(RNumber.motionDurationFast))
        }
        return .asymmetric(
            insertion: AnyTransition(.blurReplace).animation(RMotion.standard(RNumber.motionDurationSlow)),
            removal: AnyTransition(.blurReplace).animation(RMotion.exit(RNumber.motionDurationBase))
        )
    }
}

extension RTextStyle {
    /// Paper's offline line: Geist 12 regular, leading snug, no tracking (unlike `.label`).
    static let offlineLine = RTextStyle(
        family: .label,
        size: RDimension.fontSizeSm,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: RTextStyle.label.leading,
        relativeTo: .caption
    )
}

#if DEBUG
/// Lab page "offline": both copies at rest, then the line coming and going above saved content.
/// `-DesignLabAutoplay` toggles it a few times (twice mid-motion), for recordings.
struct ROfflineLineGallery: View {
    @State private var offline = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space8) {
                VStack(alignment: .leading, spacing: RDimension.space4) {
                    caption("offline line · page")
                    ROfflineLine(copy: .page)
                    caption("offline line · drawer")
                    ROfflineLine(copy: .drawer)
                }
                VStack(alignment: .leading, spacing: RDimension.space3) {
                    caption("coming and going")
                    RPill(title: offline ? "back online" : "go offline", symbol: "wifi") { offline.toggle() }
                        .accessibilityIdentifier("offline.toggle")
                    VStack(alignment: .leading, spacing: RDimension.space2) {
                        if offline {
                            ROfflineLine(copy: .page)
                        }
                        // stands in for the saved content the line sits above
                        RShape.rect(RDimension.radiusCard)
                            .fill(RColor.surfaceWash)
                            .frame(height: RDimension.sizeBriefCardMinHeight)
                            .accessibilityHidden(true)
                    }
                    // the host moves what's below on a spring; the line brings its own blur timing
                    .animation(RMotion.snappy, value: offline)
                }
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            // every other change lands mid-motion, to show it reverses from where it is
            for pause in [2.0, 2.0, 0.15, 2.0, 0.15] {
                do { try await Task.sleep(for: .seconds(pause)) } catch { return }
                offline.toggle()
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.labelMedium).foregroundStyle(RColor.textSecondary)
    }
}

#Preview("offline line") { ROfflineLineGallery() }
#endif
