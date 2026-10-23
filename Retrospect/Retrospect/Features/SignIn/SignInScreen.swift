//
//  SignInScreen.swift
//  PI0: sign in with Apple. The splash for a first-time phone (the promise, then one way in) and
//  "welcome back" for a returning one, from Paper `1F4Q-0` and AC-1 `1GXR-0` (values read from the
//  part generators `p47_signin_returning.py` and the handoff, Paper Desktop being closed). The map
//  behind the title (C38.1) isn't built yet: the Retrospect mark stands in. Beta 1 is Apple only.
//  No lit object: Apple's black button leads.
//
import SwiftUI

struct SignInScreen: View {
    @Bindable var model: SignInModel
    /// The sample launcher plays a tap on the button as the sign-in (Apple's sheet can't run on invented data).
    var sampleTaps = false
    @Environment(\.rCompactHeight) private var compact

    var body: some View {
        ZStack {
            RBrandWash()
            ScrollView {
                middle
                    .padding(.horizontal, RDimension.spaceScreenMargin)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: RDimension.space0) { bottomZone }
        .animation(RMotion.standard(RNumber.motionDurationSlow), value: model.phase)
        .animation(RMotion.standard(RNumber.motionDurationBase), value: model.isOnline)
        .sensoryFeedback(RHaptic.error, trigger: model.failures)
        .accessibilityIdentifier("screen.PI0")
    }

    // MARK: Title and line

    private var middle: some View {
        VStack(spacing: compact ? RDimension.space5 : RDimension.space6) {
            RMark()
            VStack(spacing: RDimension.space2) {
                Text(model.title)
                    .rText(.inkTitle)
                    .foregroundStyle(RColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                line
            }
        }
        .rAppear()
    }

    private var line: some View {
        HStack(spacing: RDimension.space2) {
            if model.phase == .signingIn {
                RSpinner(diameter: RDimension.sizeIconDefault)
                    .transition(.opacity)
            }
            Text(model.line)
                .rText(.body)
                .foregroundStyle(RColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .id(model.line)
        .transition(.blurReplace)
    }

    // MARK: Bottom zone

    private var bottomZone: some View {
        VStack(spacing: RDimension.space3) {
            if let failure = model.failure {
                HStack(alignment: .firstTextBaseline, spacing: RDimension.space2) {
                    RSymbol(name: "exclamationmark.circle", size: .small, tint: RColor.statusDanger)
                    Text(failure)
                        .rText(.textMd)
                        .foregroundStyle(RColor.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, RDimension.space2)
                .transition(.blurReplace)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("signin.failure")
            }
            RSignInButtons(state: model.buttons, onRequest: model.prepare) { result in
                Task { await model.appleFinished(result) }
            }
            .overlay {
                if sampleTaps, model.buttons == .rest {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { Task { await model.appleFinished(.failure(SampleTap())) } }
                }
            }
            .accessibilityIdentifier("signin.apple")
            Text(SignInModel.legal)
                .rText(.label)
                .foregroundStyle(RColor.textLabel)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.bottom, compact ? RDimension.space4 : RDimension.space6)
    }
}
