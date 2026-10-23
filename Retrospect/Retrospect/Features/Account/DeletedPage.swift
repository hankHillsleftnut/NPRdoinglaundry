//
//  DeletedPage.swift
//  C50.2: the goodbye after the account is deleted. No Paper drawing exists (views.md C50.2: the design system
//  decides): a centred canvas page with the still mark, "your account is deleted." in the display face and
//  "thank you for trying retrospect." in secondary text. It is not interactive and moves on by itself (the flow
//  holds it about 2.4 s, then the phone is erased and the splash shows); VoiceOver hears it first.
//
import SwiftUI

struct DeletedPage: View {
    static let title = "your account is deleted."
    static let line = "thank you for trying retrospect."

    var body: some View {
        VStack(spacing: RDimension.space4) {
            RMark()
                .accessibilityHidden(true)
            VStack(spacing: RDimension.space2) {
                Text(Self.title)
                    .rText(.displayTitle)
                    .foregroundStyle(RColor.textPrimary)
                Text(Self.line)
                    .rText(.body)
                    .foregroundStyle(RColor.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("screen.account.deleted")
        .onAppear {
            AccessibilityNotification.Announcement("\(Self.title) \(Self.line)").post()
        }
    }
}
