//
//  ForceUpdateScreen.swift
//  PX: when this build is too old to work, say so plainly and take the person to the update. A purpose
//  page built from design-system parts (no Paper drawing exists: screen-rules 2-3): the canvas, the
//  mark, the title, one line, and the lit "update" as the one lit object. It covers everything and
//  can't be dismissed (`rForceUpdateCover`); the content behind it is hidden from VoiceOver.
//
import SwiftUI

extension RTextStyle {
    /// The purpose page's title: ink at 30, card weight, title tracking, tight leading.
    static let forceUpdateTitle = RTextStyle(
        family: .inky(axis: -10), size: RDimension.fontSize3xl, weight: .regular,
        tracking: RNumber.fontTrackingTitle, leading: 1.1, relativeTo: .largeTitle
    )
}

struct ForceUpdateScreen: View {
    let model: ForceUpdateModel
    @Environment(\.rCompactHeight) private var compact

    private var margin: CGFloat {
        compact ? RDimension.space5 : RDimension.spaceScreenMargin
    }

    var body: some View {
        ZStack {
            RColor.backgroundCanvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: compact ? RDimension.space5 : RDimension.space6) {
                    RMark()
                    VStack(spacing: RDimension.space2) {
                        Text(ForceUpdateModel.title)
                            .rText(.forceUpdateTitle)
                            .foregroundStyle(RColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(ForceUpdateModel.line)
                            .rText(.body)
                            .foregroundStyle(RColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, margin)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: RDimension.space0) {
            if model.canUpdate {
                RButton(title: ForceUpdateModel.button) { model.update() }
                    .accessibilityLabel(ForceUpdateModel.buttonLabel)
                    .accessibilityIdentifier("forceupdate.update")
                    .padding(.horizontal, margin)
                    .padding(.bottom, compact ? RDimension.space4 : RDimension.space6)
            }
        }
        .accessibilityIdentifier("screen.PX")
    }
}

extension View {
    /// The force-update cover at the top of the app root: over everything, not dismissible, the content
    /// behind it unreachable. Fades in on 140 ms; no gesture or escape closes it.
    func rForceUpdateCover(isRequired: Bool, model: ForceUpdateModel) -> some View {
        modifier(ForceUpdateCover(isRequired: isRequired, model: model))
    }
}

private struct ForceUpdateCover: ViewModifier {
    let isRequired: Bool
    let model: ForceUpdateModel

    func body(content: Content) -> some View {
        ZStack {
            content
                .accessibilityHidden(isRequired)
                .allowsHitTesting(!isRequired)
            if isRequired {
                ForceUpdateScreen(model: model)
                    .transition(.opacity.animation(RMotion.standard(RNumber.motionDurationFast)))
                    .accessibilityAddTraits(.isModal)
                    .zIndex(RNumber.layerToast + 1)
            }
        }
    }
}
