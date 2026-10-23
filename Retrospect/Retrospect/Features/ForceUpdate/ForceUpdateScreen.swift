//
//  ForceUpdateScreen.swift
//  PX: when this build is too old to work, say so plainly and take the person to the update. A purpose
//  page built from design-system parts (no Paper drawing exists: screen-rules 2-3): the canvas, the
//  mark, the title, one line, and the lit "update" as the one lit object. It covers everything and
//  can't be dismissed (`rForceUpdateCover`); the content behind it is hidden from VoiceOver.
//
import SwiftUI

struct ForceUpdateScreen: View {
    let model: ForceUpdateModel
    @Environment(\.rCompactHeight) private var compact

    private var margin: CGFloat {
        compact ? RDimension.space5 : RDimension.spaceScreenMargin
    }

    var body: some View {
        ZStack {
            RColor.backgroundCanvas.ignoresSafeArea()
            GeometryReader { proxy in
                ScrollView {
                    page
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height) // min, so tall text at AX sizes scrolls
                }
                .scrollBounceBehavior(.basedOnSize)
            }
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

    private var page: some View {
        VStack(spacing: compact ? RDimension.space5 : RDimension.space6) {
            RMark()
            // title and line as Paper's purpose page (privacy `1F7Y-0`): ink title, 12 apart
            VStack(spacing: RDimension.space3) {
                Text(ForceUpdateModel.title)
                    .rText(.inkTitle)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// The force-update cover at the top of the app root: over everything, not dismissible, the content
    /// behind it unreachable. Fades in on 140 ms; no gesture or escape closes it. Limit: a sheet or alert
    /// already presented from `content` lives in its own presentation layer and stays above this cover;
    /// the app root should dismiss those (or host the cover in its own window) when the flag flips (wiring PR).
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
                .onChange(of: isRequired, initial: true) { _, required in
                    // Hit testing off does not end editing: put the keyboard away and take focus from any field behind.
                    if required {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            if isRequired {
                ForceUpdateScreen(model: model)
                    .transition(.opacity.animation(RMotion.standard(RNumber.motionDurationFast)))
                    .accessibilityAddTraits(.isModal)
                    .zIndex(RNumber.layerToast + 1)
            }
        }
        // VoiceOver: the cover replaces the screen, so focus moves to it instead of staying on what's behind.
        .onChange(of: isRequired) { _, now in
            if now {
                AccessibilityNotification.ScreenChanged().post()
            }
        }
    }
}
