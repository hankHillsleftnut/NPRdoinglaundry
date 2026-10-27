//
//  SettingsPageFrame.swift
//  V2.settings: the frame every settings page shares (Paper c:top-bar/settings/rest over a column of
//  groups; ios-handoff M9): the settings bar, the groups 32 apart (24 on a short screen), and an
//  optional danger block that sits last, at the bottom, in the thumb zone (ST-4, ST-5, ST-9). The
//  canvas runs under the status bar and home indicator; content stays inside the safe area.
//
import SwiftUI

struct SettingsPageFrame<Content: View, Danger: View>: View {
    let title: String
    /// Paper: 16 under the bar (ST-1: 8).
    var topPadding = RDimension.space4
    /// Paper: 32 between groups (ST-4: 24).
    var groupSpacing = RDimension.spaceSection
    let back: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let danger: Danger
    @Environment(\.rCompactHeight) private var compact

    var body: some View {
        VStack(spacing: RDimension.space0) {
            RTopBar(variant: .settings(title: title, back: back))
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: RDimension.space0) {
                        VStack(alignment: .leading, spacing: spacing) {
                            content
                        }
                        Spacer(minLength: spacing)
                        danger
                    }
                    .padding(.top, topPadding)
                    .padding(.bottom, RDimension.space10)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(RColor.backgroundCanvas)
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Short screens (SE) tighten the rhythm instead of shrinking anything.
    private var spacing: CGFloat {
        compact ? min(groupSpacing, RDimension.space6) : groupSpacing
    }
}

extension SettingsPageFrame where Danger == EmptyView {
    init(
        title: String,
        topPadding: CGFloat = RDimension.space4,
        groupSpacing: CGFloat = RDimension.spaceSection,
        back: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, topPadding: topPadding, groupSpacing: groupSpacing, back: back, content: content) {
            EmptyView()
        }
    }
}

/// A labelled group: the section label inside the screen margin, 4 above its rows (Paper c:label/section).
struct SettingsLabelledGroup<Rows: View>: View {
    var label: String?
    @ViewBuilder let rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space0) {
            if let label {
                RSectionLabel(title: label)
                    .padding(.horizontal, RDimension.spaceScreenMargin)
            }
            rows
        }
    }
}
