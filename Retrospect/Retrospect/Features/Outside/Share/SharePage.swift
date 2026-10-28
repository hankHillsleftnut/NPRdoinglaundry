//
//  SharePage.swift
//  V2.outside · EX-1 share to retrospect (Paper 1H1M-0, slot 16LJ-0): the sheet's content, built to be
//  the share extension's view later (the target is founder paperwork). background.canvas, padding 24 at
//  the sides, 8 on top, 24 between parts: Paper's 36 × 5 grabber (border.strong); the header (cancel ·
//  "save to retrospect" centred over 72 slots); the item card; a flexible gap; "add why (optional)"
//  over the compact composer; the lit "save" (size.control-hero). The sheet's paper, its corners and
//  the space under the home indicator are the host's. The mic focuses the field, so the keyboard's dictation is the voice way
//  in (EX-D10): voice capture inside an extension isn't built.
//
import SwiftUI
import UIKit

extension RTextStyle {
    /// "save to retrospect": Geist 14 semibold, leading snug (1H2F-0).
    static let shareSheetTitle = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .semibold,
        tracking: RNumber.fontTrackingNone,
        leading: RTextStyle.textMd.leading,
        relativeTo: .headline
    )
}

struct SharePage: View {
    @Bindable var model: ShareModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Three bands, 24 apart (QA batch 9, #220): the grabber and header stay pinned at the top; only the
    /// card and the "why" field scroll, inside their own clipped area (so nothing ever slides under the
    /// status bar or under "save"); "save" is pinned below, above the keyboard when it's up. At rest the
    /// positions are Paper's: the flexible gap inside the scroll area pushes the field down to save.
    var body: some View {
        VStack(spacing: RDimension.space6) {
            VStack(spacing: RDimension.space6) {
                grabber
                header
            }
            .padding(.horizontal, RDimension.spaceScreenMargin)
            GeometryReader { proxy in
                ScrollViewReader { scroller in
                    ScrollView {
                        column
                            // the screen margin sits inside the scroll area, so the card's shadow has room
                            // and isn't cut by the clip
                            .padding(.horizontal, RDimension.spaceScreenMargin)
                            .frame(minHeight: proxy.size.height, alignment: .top)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDismissesKeyboard(.interactively)
                    // while you write (keyboard up, the words growing) the whole field stays in view above save
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                        revealWhy(scroller)
                    }
                    .onChange(of: model.why) { revealWhy(scroller) }
                }
            }
            RButton(title: "save", status: model.isSaving ? .pending : .rest) {
                Task { await model.save() }
            }
            .accessibilityIdentifier("share.save")
            .padding(.horizontal, RDimension.spaceScreenMargin)
        }
        .padding(.top, RDimension.space2)
        // Paper keeps save 40 above the screen edge, which is mostly the home indicator: 8 above the safe area
        .padding(.bottom, RDimension.space2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task { await model.load() }
    }

    /// What scrolls: the card, the flexible gap and the "why" field.
    private var column: some View {
        VStack(alignment: .leading, spacing: RDimension.space6) {
            if let item = model.item {
                ShareItemCard(item: item)
                    .padding(.top, RDimension.space2)
            }
            Spacer(minLength: RDimension.space0)
            VStack(alignment: .leading, spacing: RDimension.space2) {
                Text("add why (optional)")
                    .rText(.claimGuessLabel)
                    .foregroundStyle(RColor.textLabel)
                    .accessibilityHidden(true)
                RComposer(label: "add why", placeholder: "for the raise, the bit on angels…", text: $model.why)
                    .accessibilityIdentifier("share.why")
            }
            // the field keeps its own height (48 at rest, growing with the words); the gap above takes
            // the room, not the field (QA 1, #220: it stretched to fill the sheet)
            .fixedSize(horizontal: false, vertical: true)
            .id(Self.whyID)
        }
    }

    private static let whyID = "share.why.group"

    /// Scrolls the "why" group's bottom into view (the system only keeps the caret in view).
    private func revealWhy(_ scroller: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : RMotion.standard(RNumber.motionDurationFast)) {
            scroller.scrollTo(Self.whyID, anchor: .bottom)
        }
    }

    /// Paper draws its own grabber (1H2H-0): 36 × 5, border.strong, centred.
    private var grabber: some View {
        RShape.pill
            .fill(RColor.borderStrong)
            .frame(width: RDimension.sizeGrabberWidth, height: RDimension.sizeGrabberHeight)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    /// cancel · save to retrospect · (an empty 72 slot so the title sits on the centre). At accessibility
    /// sizes the 72 slots can't hold the words: cancel takes its own row and the title its own, so they
    /// never touch (QA batch 9).
    @ViewBuilder private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: RDimension.space1) {
                cancelButton
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(spacing: RDimension.space0) {
                cancelButton
                    .frame(minWidth: RDimension.sizeShareHeaderSlot, alignment: .leading)
                title
                    .frame(maxWidth: .infinity)
                Color.clear
                    .frame(width: RDimension.sizeShareHeaderSlot, height: RDimension.sizeTouchTarget)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: RDimension.sizeNavBar)
        }
    }

    private var cancelButton: some View {
        Button("cancel") { model.cancel() }
            .buttonStyle(ShareTextButtonStyle())
            .accessibilityIdentifier("share.cancel")
    }

    private var title: some View {
        Text("save to retrospect")
            .rText(.shareSheetTitle)
            .foregroundStyle(RColor.textPrimary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("share.title")
    }
}

/// "cancel": SF 17 in ink (Paper: text.link; blue is only for links inside text, founder 27 Oct, EX-D15),
/// dimming while held, a 44 hit area.
private struct ShareTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .rText(.body)
            .foregroundStyle(RColor.textPrimary)
            .opacity(configuration.isPressed ? RNumber.opacityPressed : 1)
            .animation(
                RMotion.standard(configuration.isPressed ? RNumber.motionDurationPressIn : RNumber.motionDurationPressOut),
                value: configuration.isPressed
            )
            .frame(minHeight: RDimension.sizeTouchTarget)
            .contentShape(Rectangle())
    }
}
