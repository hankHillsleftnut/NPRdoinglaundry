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
    @Environment(\.dynamicTypeSize) private var typeSize

    /// From xxLarge up the failure line wraps; it then takes layout room instead of floating.
    private var largeType: Bool {
        typeSize >= .xxLarge
    }

    var body: some View {
        ZStack {
            RBrandWash()
            GeometryReader { proxy in
                ScrollView {
                    // at least the screen's height (the splash's spacer anchors the words above the
                    // buttons), and free to grow. At large type the buttons join the page and scroll
                    // with it: pinned, the words ran under them (SE at AX3)
                    VStack(spacing: RDimension.space0) {
                        page(topInset: proxy.safeAreaInsets.top)
                        if largeType {
                            Spacer(minLength: RDimension.space6)
                            bottomZone
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollClipDisabled() // the splash's map runs up under the status bar, as in Paper
            }
        }
        .safeAreaInset(edge: .bottom, spacing: RDimension.space0) {
            if !largeType {
                bottomZone
            }
        }
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
        // the words keep their room and the map gives it up: 0.78 on SE (build notes), 0.6 at large type
        largeType ? 0.6 : (compact ? 0.78 : 1)
    } // literal-ok: map scales

    /// Splash (Paper `1F4Q-0`): the map in a 400 slot under the status bar, the words leading and
    /// anchored above the bottom zone. Welcome back (`1GXR-0`): map then centred words, from the top.
    /// The failure line floats above the button at normal sizes, so nothing glides when it comes and
    /// goes; at large type it takes its room (and the map shrinks) so it never sits on the words.
    @ViewBuilder private func page(topInset: CGFloat) -> some View {
        if model.look == .splash {
            VStack(alignment: .leading, spacing: RDimension.space0) {
                // Paper's 400 slot is measured from the screen's top edge, status bar included: the
                // slot here starts under the status bar, so it is shorter by it and the map spills up
                RYouMapRest(scale: mapScale)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(400 * mapScale - topInset, RDimension.space0), alignment: .bottom) // literal-ok: Paper map slot 400
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
            if largeType {
                // at large sizes the line wraps and would float over the words: it takes its room
                failureLine
            }
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
            if !largeType {
                Color.clear.frame(height: RDimension.space0).overlay(alignment: .bottom) { failureLine.offset(y: -RDimension.space3) }
            }
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
        }
    }
}
