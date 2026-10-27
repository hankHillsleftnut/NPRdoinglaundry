//
//  StackingScrollView.swift
//  Retrospect
//
//  Apple-style stacking cards animation for scroll views
//  Cards compress and stack behind each other as you scroll
//

import SwiftUI

struct StackingScrollView<Content: View>: View {
    let content: Content
    let itemHeight: CGFloat
    let itemSpacing: CGFloat

    init(
        itemHeight: CGFloat = 80,
        itemSpacing: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.itemHeight = itemHeight
        self.itemSpacing = itemSpacing
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
        }
    }
}

// MARK: - Stacking Card Modifier

struct StackingCardModifier: ViewModifier {
    let index: Int
    let scrollOffset: CGFloat
    let itemHeight: CGFloat
    let collapsedHeight: CGFloat
    let maxVisibleCards: Int

    init(
        index: Int,
        scrollOffset: CGFloat,
        itemHeight: CGFloat = 80,
        collapsedHeight: CGFloat = 8,
        maxVisibleCards: Int = 4
    ) {
        self.index = index
        self.scrollOffset = scrollOffset
        self.itemHeight = itemHeight
        self.collapsedHeight = collapsedHeight
        self.maxVisibleCards = maxVisibleCards
    }

    private var cardOffset: CGFloat {
        let itemPosition = CGFloat(index) * (itemHeight + 12) // 12 is spacing
        let relativeOffset = itemPosition + scrollOffset

        // Only apply effect when card is near the top (negative relative offset means scrolled up)
        if relativeOffset < 0 {
            // Card is above the visible area threshold
            let compressionProgress = min(1.0, abs(relativeOffset) / (itemHeight * 2))

            // Compress the offset - cards stack tighter
            return relativeOffset * (1 - compressionProgress * 0.7)
        }

        return 0
    }

    private var cardScale: CGFloat {
        let itemPosition = CGFloat(index) * (itemHeight + 12)
        let relativeOffset = itemPosition + scrollOffset

        if relativeOffset < 0 {
            let compressionProgress = min(1.0, abs(relativeOffset) / (itemHeight * 3))
            // Scale down as card goes up
            return 1.0 - (compressionProgress * 0.15)
        }

        return 1.0
    }

    private var cardOpacity: Double {
        let itemPosition = CGFloat(index) * (itemHeight + 12)
        let relativeOffset = itemPosition + scrollOffset

        if relativeOffset < -itemHeight * 2 {
            let fadeProgress = min(1.0, abs(relativeOffset + itemHeight * 2) / (itemHeight * 2))
            return 1.0 - (fadeProgress * 0.6)
        }

        return 1.0
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(cardScale, anchor: .top)
            .offset(y: cardOffset)
            .opacity(cardOpacity)
            .zIndex(Double(1000 - index))
    }
}

// MARK: - Stacking List View

/// Note: ScrollOffsetPreferenceKey is defined in SettingsView.swift
struct StackingListView<Item: Identifiable, ItemView: View>: View {
    let items: [Item]
    let itemHeight: CGFloat
    let itemSpacing: CGFloat
    let itemView: (Item, Int) -> ItemView

    @State private var scrollOffset: CGFloat = 0

    init(
        items: [Item],
        itemHeight: CGFloat = 80,
        itemSpacing: CGFloat = 12,
        @ViewBuilder itemView: @escaping (Item, Int) -> ItemView
    ) {
        self.items = items
        self.itemHeight = itemHeight
        self.itemSpacing = itemSpacing
        self.itemView = itemView
    }

    var body: some View {
        ScrollView {
            // Offset tracker
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("stackingScroll")).minY
                )
            }
            .frame(height: 0)

            LazyVStack(spacing: itemSpacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    itemView(item, index)
                        .modifier(StackingCardModifier(
                            index: index,
                            scrollOffset: scrollOffset,
                            itemHeight: itemHeight
                        ))
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .coordinateSpace(name: "stackingScroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value - 20 // Adjust for top padding
        }
    }
}

// MARK: - Simple Stacking Modifier for existing ForEach

extension View {
    func stackingEffect(
        index: Int,
        scrollOffset: CGFloat,
        itemHeight: CGFloat = 80
    ) -> some View {
        modifier(StackingCardModifier(
            index: index,
            scrollOffset: scrollOffset,
            itemHeight: itemHeight
        ))
    }
}

#Preview {
    struct PreviewItem: Identifiable {
        let id = UUID()
        let title: String
    }

    let items = (0 ..< 20).map { PreviewItem(title: "Item \($0)") }

    return ZStack {
        LinearColors.Minimal.background.ignoresSafeArea()

        StackingListView(items: items, itemHeight: 70, itemSpacing: 12) { item, _ in
            HStack {
                Text(item.title)
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                Spacer()
            }
            .padding()
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearColors.Minimal.border)
            )
            .padding(.horizontal, 20)
        }
    }
}
