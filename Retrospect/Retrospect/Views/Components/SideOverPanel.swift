//
//  SideOverPanel.swift
//  Retrospect
//
//  Underlay side navigation panel revealed by sliding the app screen.
//

import SwiftUI

struct SideOverPanel: View {
    @Binding var isOpen: Bool
    @Binding var selectedTab: MinimalTab
    var hasNewPodcast: Bool = false
    var progress: CGFloat = 0
    var safeAreaTop: CGFloat = 0
    var safeAreaBottom: CGFloat = 0
    var onSelectEntry: (Entry) -> Void = { _ in }
    @ObservedObject private var entryManager = EntryManager.shared

    // Panel sizing
    private let panelWidth: CGFloat = min(UIScreen.main.bounds.width * 0.69, 276)
    private let panelBackgroundColor = Color(red: 228 / 255, green: 228 / 255, blue: 226 / 255)
    private let panelMutedText = Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)

    var body: some View {
        panelContent(safeAreaTop: safeAreaTop, safeAreaBottom: safeAreaBottom)
            .frame(width: panelWidth)
            .frame(maxHeight: .infinity)
            .background(panelBackground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(0.18 + 0.82 * progress)
            .offset(x: -8 * (1 - progress))
    }

    // MARK: - Panel Content

    private func panelContent(safeAreaTop: CGFloat, safeAreaBottom: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: close) {
                ZStack {
                    Circle()
                        .fill(Color(red: 244 / 255, green: 242 / 255, blue: 238 / 255))
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.20), radius: 4, x: 0, y: 2)

                    Image("retrospect-loading-mark")
                        .resizable()
                        .scaledToFit()
                        .opacity(0.35)
                        .padding(9)
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 35)
            .padding(.top, safeAreaTop + 31)

            VStack(alignment: .leading, spacing: 29) {
                ForEach([MinimalTab.journal, .goals, .entries, .podcasts, .settings], id: \.self) { tab in
                    SideOverPanelRow(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        hasNotification: tab == .podcasts && hasNewPodcast
                    ) {
                        select(tab)
                    }
                }
            }
            .padding(.leading, 35)
            .padding(.top, 61)

            if !recentEntries.isEmpty {
                Text("recents")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(panelMutedText.opacity(0.68))
                    .padding(.leading, 35)
                    .padding(.top, 42)
                    .padding(.bottom, 12)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(recentEntries) { entry in
                        SideOverPanelEntryRow(entry: entry) {
                            HapticManager.shared.playLightImpact()
                            onSelectEntry(entry)
                            close()
                        }
                    }
                }
                .padding(.leading, 35)
                .padding(.trailing, 24)
                .padding(.bottom, 20)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .regular))
                Text("v\(appVersion)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
            }
            .foregroundColor(panelMutedText.opacity(0.58))
            .padding(.leading, 35)
            .padding(.bottom, safeAreaBottom + 22)
        }
    }

    // MARK: - Background

    private var panelBackground: some View {
        panelBackgroundColor
    }

    // MARK: - Derived values

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var recentEntries: [Entry] {
        entryManager.getAllEntries()
            .filter { $0.type != .video }
            .sorted { $0.date > $1.date }
            .prefix(50)
            .map { $0 }
    }

    // MARK: - Actions

    private func select(_ tab: MinimalTab) {
        HapticManager.shared.playLightImpact()
        withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.06)) {
            selectedTab = tab
        }
        // Slight delay so the user sees the selection update before the panel closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            close()
        }
    }

    private func close() {
        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.88, blendDuration: 0.08)) {
            isOpen = false
        }
    }
}

// MARK: - Row

private struct SideOverPanelRow: View {
    let tab: MinimalTab
    let isSelected: Bool
    var hasNotification: Bool = false
    let action: () -> Void
    private let mutedText = Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)
    private let selectedText = Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(tab.title.lowercased())
                    .font(.system(size: 18, weight: isSelected ? .medium : .regular, design: .monospaced))
                    .tracking(-0.2)

                if hasNotification {
                    Circle()
                        .fill(selectedText.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .offset(y: -1)
                }

                Spacer()
            }
            .foregroundColor(isSelected ? selectedText : mutedText)
            .opacity(isSelected ? 1 : 0.82)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SideOverPanelEntryRow: View {
    let entry: Entry
    let action: () -> Void
    private let mutedText = Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)

    var body: some View {
        Button(action: action) {
            Text(entry.displayTitle)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(mutedText.opacity(0.72))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Hamburger Button

struct HamburgerButton: View {
    var size: CGFloat = 58
    let action: () -> Void

    private var iconSize: CGFloat {
        size <= 48 ? 15 : 17
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.playLightImpact()
            action()
        }) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(LinearColors.Minimal.textSecondary)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(LinearColors.Minimal.backgroundCard.opacity(0.92))
                        .overlay(
                            Circle()
                                .strokeBorder(LinearColors.Minimal.border.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 6)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview("Open") {
    StatefulPreviewWrapper(true) { isOpen in
        ZStack {
            LinearColors.Minimal.background.ignoresSafeArea()
            VStack {
                Text("How do you\nwant to rewire\nthe mind\ntoday?")
                    .font(.minimalHeadline)
                    .foregroundColor(.white.opacity(0.6))
                    .padding()
                Spacer()
            }
            SideOverPanel(
                isOpen: isOpen,
                selectedTab: .constant(.journal),
                hasNewPodcast: true
            )
        }
        .preferredColorScheme(.dark)
    }
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content
    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }
    var body: some View { content($value) }
}
