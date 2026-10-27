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

    var body: some View {
        VStack(spacing: RDimension.space6) {
            // the column scrolls when the keyboard takes the room (SE, large type); "save" stays on screen
            GeometryReader { proxy in
                ScrollView {
                    column
                        .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
            RButton(title: "save", status: model.isSaving ? .pending : .rest) {
                Task { await model.save() }
            }
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.top, RDimension.space2)
        .padding(.bottom, RDimension.space4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task { await model.load() }
        .accessibilityIdentifier("share")
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: RDimension.space6) {
            grabber
            header
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
            }
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

    /// cancel · save to retrospect · (an empty 72 slot so the title sits on the centre).
    private var header: some View {
        HStack(spacing: RDimension.space0) {
            Button("cancel") { model.cancel() }
                .buttonStyle(ShareTextButtonStyle())
                .frame(minWidth: RDimension.sizeShareHeaderSlot, alignment: .leading)
            Text("save to retrospect")
                .rText(.shareSheetTitle)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            Color.clear
                .frame(width: RDimension.sizeShareHeaderSlot, height: RDimension.sizeTouchTarget)
                .accessibilityHidden(true)
        }
        .frame(minHeight: RDimension.sizeNavBar)
    }
}

/// "cancel": SF 17 in text.link, dimming while held, a 44 hit area.
private struct ShareTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .rText(.body)
            .foregroundStyle(RColor.textLink)
            .opacity(configuration.isPressed ? RNumber.opacityPressed : 1)
            .animation(
                RMotion.standard(configuration.isPressed ? RNumber.motionDurationPressIn : RNumber.motionDurationPressOut),
                value: configuration.isPressed
            )
            .frame(minHeight: RDimension.sizeTouchTarget)
            .contentShape(Rectangle())
    }
}
