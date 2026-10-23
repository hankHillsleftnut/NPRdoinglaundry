//
//  SignInScreen.swift
//  PI0: sign in with Apple. The splash for a first-time phone (the promise, then one way in) and
//  "welcome back" for a returning one, from Paper `1F4Q-0` and AC-1 `1GXR-0` (values read from the
//  part generators `p47_signin_returning.py` and the handoff, Paper Desktop being closed). The You map
//  at rest (C38.1, RYouMapRest) sits behind the words. Beta 1 is Apple only.
//  No lit object: Apple's black button leads.
//
import SwiftUI

struct SignInScreen: View {
    @Bindable var model: SignInModel
    /// The sample launcher plays a tap on the button as the sign-in (Apple's sheet can't run on invented data).
    var sampleTaps = false
    @Environment(\.rCompactHeight) private var compact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RBrandWash()
            GeometryReader { proxy in
                ScrollView {
                    page
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top) // min, so big text scrolls
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: RDimension.space0) { bottomZone }
        .animation(RMotion.standard(reduceMotion ? RNumber.motionDurationFast : RNumber.motionDurationSlow), value: model.phase)
        .animation(RMotion.standard(reduceMotion ? RNumber.motionDurationFast : RNumber.motionDurationBase), value: model.isOnline)
        .sensoryFeedback(RHaptic.error, trigger: model.failures)
        // Every failure is said as well as felt (checklist 2), each time, not only the first.
        .rErrorAnnouncement(SignInModel.failureLine, attempt: model.failures)
        .onChange(of: model.phase) { _, phase in
            if phase == .signingIn {
                AccessibilityNotification.Announcement(model.waitLine).post()
            }
        }
        .onChange(of: model.isOnline, initial: true) { _, online in
            if !online {
                AccessibilityNotification.Announcement(SignInModel.offlineReason).post()
            }
        }
        .accessibilityIdentifier("screen.PI0")
    }

    // MARK: Title and line

    private var mapScale: CGFloat {
        compact ? 0.78 : 1
    } // literal-ok: build notes, SE scale

    /// Splash (Paper `1F4Q-0`): the map in a 400 slot under the status bar, the words leading and
    /// anchored above the bottom zone. Welcome back (`1GXR-0`): map then centred words, from the top.
    /// Both are top-anchored to the map, and the bottom zone reserves its failure slot, so nothing
    /// glides when a failure line comes and goes.
    @ViewBuilder private var page: some View {
        if model.look == .splash {
            VStack(alignment: .leading, spacing: RDimension.space0) {
                RYouMapRest(scale: mapScale)
                    .frame(maxWidth: .infinity, minHeight: 400 * mapScale, maxHeight: 400 * mapScale, alignment: .bottom) // literal-ok: Paper map slot 400
                    .ignoresSafeArea(edges: .top)
                Spacer(minLength: RDimension.space0)
                words(alignment: .leading)
                    .padding(.horizontal, RDimension.spaceScreenMargin)
                    .padding(.bottom, RDimension.space8)
            }
            .rAppear()
        } else {
            VStack(spacing: RDimension.space4) {
                RYouMapRest(scale: mapScale)
                words(alignment: .center)
                    .padding(.horizontal, RDimension.spaceScreenMargin)
            }
            .padding(.top, RDimension.space10)
            .rAppear()
        }
    }

    private func words(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: model.look == .splash ? RDimension.space3 : RDimension.space2) {
            Text(model.title)
                .rText(.inkTitle)
                .foregroundStyle(RColor.textPrimary)
                .multilineTextAlignment(alignment == .leading ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            line(alignment: alignment)
        }
    }

    /// The rest line and the wait share one slot sized for the taller of the two (both are laid
    /// out, hidden), so the title and the mark never move when one becomes the other.
    private func line(alignment: HorizontalAlignment) -> some View {
        ZStack(alignment: alignment == .leading ? .topLeading : .top) {
            lineRow(model.restLine, waiting: false).hidden()
            lineRow(model.waitLine, waiting: true).hidden()
            lineRow(model.line, waiting: model.phase == .signingIn)
                .id(model.line)
                .rBlurReplace()
        }
        .accessibilityElement(children: .combine)
    }

    /// Paper AC-1 restoring: the 16 syncing ring, 8 before the words.
    private func lineRow(_ text: String, waiting: Bool) -> some View {
        HStack(spacing: RDimension.space2) {
            if waiting {
                RSpinner(diameter: RDimension.sizeIconSmall)
            }
            Text(text)
                .rText(.body)
                .foregroundStyle(RColor.textSecondary)
                .multilineTextAlignment(model.look == .splash ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Bottom zone

    private var bottomZone: some View {
        VStack(spacing: RDimension.space3) {
            RSignInButtons(state: model.buttons, onRequest: model.prepare) { result in
                Task { await model.appleFinished(result) }
            }
            #if DEBUG // SampleTap lives in the DEBUG-only launcher
            .overlay {
                if sampleTaps, model.buttons == .rest {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { Task { await model.appleFinished(.failure(SampleTap())) } }
                }
            }
            #endif
            .accessibilityIdentifier("signin.apple")
            Text(SignInModel.legal)
                .rText(.label)
                .foregroundStyle(RColor.textLabel)
                .multilineTextAlignment(.center)
        }
        .overlay(alignment: .top) {
            // The failure line floats above the button without taking layout space, so the words
            // and the button hold still when it comes and goes (QA task 4).
            Color.clear.frame(height: RDimension.space0).overlay(alignment: .bottom) { failureLine }
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.bottom, compact ? RDimension.space4 : RDimension.space2) // Paper: 40 from the screen edge on a 17 Pro (34 safe area + 6)
    }

    @ViewBuilder private var failureLine: some View {
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
            .rBlurReplace()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("signin.failure")
            .offset(y: -RDimension.space3)
        }
    }
}
