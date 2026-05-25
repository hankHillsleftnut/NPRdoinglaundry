//
//  DarkPageScaffold.swift
//  Retrospect
//
//  Shared page chrome for all dark-UI tabs.
//  Owns the standard header (hamburger + title + accessory + trailing slot)
//  and the top safe-area inset, so every page has a consistent shape.
//
//  Pages opt into the scaffold by wrapping their content; they no longer
//  build bespoke header HStacks or manage top safe-area themselves.
//

import SwiftUI

// MARK: - Environment Keys

private struct DynamicSafeAreaTopKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct DynamicSafeAreaBottomKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct SidePanelProgressKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct OpenSidePanelKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// The real top safe-area inset, resolved even when an ancestor uses
    /// `.ignoresSafeArea`. Set by `DarkAppContainer`.
    var dynamicSafeAreaTop: CGFloat {
        get { self[DynamicSafeAreaTopKey.self] }
        set { self[DynamicSafeAreaTopKey.self] = newValue }
    }

    /// The real bottom safe-area inset, resolved similarly.
    var dynamicSafeAreaBottom: CGFloat {
        get { self[DynamicSafeAreaBottomKey.self] }
        set { self[DynamicSafeAreaBottomKey.self] = newValue }
    }

    /// 0...1 progress of the side panel open animation.
    /// Used by the scaffold to fade out the hamburger continuously.
    var sidePanelProgress: CGFloat {
        get { self[SidePanelProgressKey.self] }
        set { self[SidePanelProgressKey.self] = newValue }
    }

    /// Trigger to open the side panel; invoked by the hamburger button inside the scaffold.
    var openSidePanel: () -> Void {
        get { self[OpenSidePanelKey.self] }
        set { self[OpenSidePanelKey.self] = newValue }
    }
}

// MARK: - DarkPageScaffold

struct DarkPageScaffold<Title: View, Accessory: View, Trailing: View, Content: View>: View {
    private let title: Title
    private let accessory: Accessory
    private let trailing: Trailing
    private let content: Content
    private let hideHeader: Bool

    @Environment(\.dynamicSafeAreaTop) private var dynamicSafeAreaTop
    @Environment(\.sidePanelProgress) private var sidePanelProgress
    @Environment(\.openSidePanel) private var openSidePanel

    init(
        hideHeader: Bool = false,
        @ViewBuilder title: () -> Title,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.hideHeader = hideHeader
        self.title = title()
        self.accessory = accessory()
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if !hideHeader {
                header
            } else {
                Spacer()
                    .frame(height: dynamicSafeAreaTop)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            HamburgerButton(size: 44) {
                openSidePanel()
            }
            .opacity(1 - sidePanelProgress)
            .allowsHitTesting(sidePanelProgress < 0.05)

            title
                .layoutPriority(1)

            accessory

            Spacer(minLength: 8)

            trailing
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.top, dynamicSafeAreaTop + 6)
        .padding(.bottom, 6)
    }
}

// MARK: - Convenience initializers

extension DarkPageScaffold where Accessory == EmptyView, Trailing == EmptyView {
    init(
        hideHeader: Bool = false,
        @ViewBuilder title: () -> Title,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            hideHeader: hideHeader,
            title: title,
            accessory: { EmptyView() },
            trailing: { EmptyView() },
            content: content
        )
    }
}

extension DarkPageScaffold where Trailing == EmptyView {
    init(
        hideHeader: Bool = false,
        @ViewBuilder title: () -> Title,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            hideHeader: hideHeader,
            title: title,
            accessory: accessory,
            trailing: { EmptyView() },
            content: content
        )
    }
}

extension DarkPageScaffold where Title == EmptyView, Accessory == EmptyView, Trailing == EmptyView {
    init(
        hideHeader: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            hideHeader: hideHeader,
            title: { EmptyView() },
            accessory: { EmptyView() },
            trailing: { EmptyView() },
            content: content
        )
    }
}

// MARK: - Shared header pieces

/// Standard serif page title used by every tab.
struct DarkPageTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("HedvigLettersSerif-24ptRegular", size: 40))
            .foregroundColor(LinearColors.Minimal.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// Standard count pill rendered to the right of a page title.
struct DarkPageCountPill: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(LinearColors.Minimal.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        Capsule()
                            .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                    )
            )
    }
}
