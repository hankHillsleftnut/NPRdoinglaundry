//
//  SignInScreen.swift
//  PI0: sign in with Apple. The splash for a first-time phone (the promise, then one way in) and
//  "welcome back" for a returning one, from Paper `1F4Q-0` and AC-1 `1GXR-0` (values read from the
//  part generators `p47_signin_returning.py` and the handoff, Paper Desktop being closed). The You map
//  at rest (C38.1, RYouMapRest) sits behind the words, with Paper's orb names on the splash. Live is
//  Apple only; on sample data "Continue with Google" is there too, as Paper draws it (decision 12).
//  Welcome back ends with "new here? get started" (AC-1 `1GY6-0`, founder 27 Oct), which opens the
//  splash; the splash ends with the legal line. No lit object: Apple's black button leads.
//
import SwiftUI

struct SignInScreen: View {
    @Bindable var model: SignInModel
    /// The sample launcher plays a tap on the button as the sign-in (Apple's sheet can't run on invented data).
    var sampleTaps = false
    @Environment(\.rCompactHeight) private var compact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The home indicator's inset, read from the layout: Paper ends the bottom zone 40 from the screen's
    /// edge, which is this inset plus the rest.
    @State private var bottomInset: CGFloat = 0

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
                        page
                        if largeType {
                            Spacer(minLength: RDimension.space6)
                            bottomZone
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: RDimension.space0) {
            if !largeType {
                bottomZone
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
        .animation(RMotion.standard(reduceMotion ? RNumber.motionDurationFast : RNumber.motionDurationSlow), value: model.phase)
        // "new here?" turns welcome back into the splash in place: the same crossfade as a phase change
        .animation(RMotion.standard(reduceMotion ? RNumber.motionDurationFast : RNumber.motionDurationSlow), value: model.look)
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

    /// Splash (Paper `1F4Q-0`): the map from the top of the safe area, the words leading and anchored
    /// above the bottom zone. Welcome back (`1GXR-0`): map then centred words, from the top.
    /// The failure line floats above the button at normal sizes, so nothing glides when it comes and
    /// goes; at large type it takes its room (and the map shrinks) so it never sits on the words.
    @ViewBuilder private var page: some View {
        if model.look == .splash {
            VStack(alignment: .leading, spacing: RDimension.space0) {
                // Paper bleeds the map under the status bar (slot `1F5J-0`: 400 from the screen's top
                // edge). The founder's safe-area rule (26 Oct) wins: the whole map starts below the
                // status bar / Dynamic Island, and only the wash behind it bleeds (QUESTION card).
                RYouMapRest(scale: mapScale, labels: true)
                    .frame(maxWidth: .infinity)
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
                .modifier(SplashBalance(on: model.look == .splash))
            line(alignment: alignment)
                .modifier(SplashBalance(on: model.look == .splash))
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
            RSignInButtons(
                state: model.buttons,
                onRequest: model.prepare,
                onCompletion: { result in Task { await model.appleFinished(result) } },
                onGoogle: googleAction
            )
            #if DEBUG // SampleTap lives in the DEBUG-only launcher
            .overlay(alignment: .top) {
                // over Apple's button only (Google, under it, is a real Button with its own action)
                if sampleTaps, model.buttons == .rest {
                    Color.clear.contentShape(Rectangle())
                        .frame(height: RDimension.sizeControlHero)
                        .onTapGesture { Task { await model.appleFinished(.failure(SampleTap())) } }
                }
            }
            #endif
            if let newHereAction {
                newHereLink(newHereAction)
            } else {
                Text(SignInModel.legal)
                    .rText(.metaLine) // Paper `1F53-0`: Geist 12, leading snug, no tracking
                    .foregroundStyle(RColor.textLabel)
                    .multilineTextAlignment(.center)
            }
        }
        .overlay(alignment: .top) {
            // The failure line floats above the button without taking layout space, so the words
            // and the button hold still when it comes and goes (QA task 4).
            if !largeType {
                Color.clear.frame(height: RDimension.space0).overlay(alignment: .bottom) { failureLine.offset(y: -RDimension.space3) }
            }
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        // Paper `1F52-0`: the zone ends 40 from the screen's edge (34 home indicator + 6 on a 17 Pro);
        // SE, short and with no indicator, keeps 16
        .padding(.bottom, compact ? RDimension.space4 : max(RDimension.space10 - bottomInset, RDimension.space1))
    }

    /// AC-1 `1GY6-0` in its 44pt row `1GY5-0`: text-md medium, text-link, centred, 12 under the buttons.
    /// It opens the splash (founder, 27 Oct); held still while Apple's answer is being checked.
    private func newHereLink(_ action: @escaping () -> Void) -> some View {
        Button(SignInModel.newHere, action: action)
            .rText(.textMdMedium)
            .foregroundStyle(RColor.textLink)
            .multilineTextAlignment(.center)
            .frame(minHeight: RDimension.sizeTouchTarget)
            .padding(.horizontal, RDimension.space3)
            .contentShape(Rectangle())
            .rPress(small: true)
            .disabled(!model.newHereEnabled)
            .accessibilityRemoveTraits(.isButton)
            .accessibilityAddTraits(.isLink)
            .accessibilityHint("starts retrospect from the beginning")
            .accessibilityIdentifier("signin.newHere")
    }

    /// What "new here? get started" does, or nil where it isn't drawn (the splash has the legal line).
    var newHereAction: (() -> Void)? {
        guard model.offersNewHere else { return nil }
        return { [model] in model.startFresh() }
    }

    /// "Continue with Google" exists only where it works: on sample taps (`-Flow sample`, the launcher,
    /// decision 12), where it signs the sample person in exactly as the Apple tap does. No real Google
    /// sign-in exists yet, so a live screen has no Google button at all.
    static func offersGoogle(sampleTaps: Bool) -> Bool {
        #if DEBUG
        sampleTaps
        #else
        false
        #endif
    }

    /// What the Google button does here, or nil when it isn't there.
    var googleAction: (() -> Void)? {
        guard Self.offersGoogle(sampleTaps: sampleTaps) else { return nil }
        #if DEBUG
        return { [model] in Task { await Self.sampleGoogle(model) } }
        #else
        return nil
        #endif
    }

    #if DEBUG
    /// The sample Google tap: the same sample sign-in as the Apple tap, once, from rest only.
    static func sampleGoogle(_ model: SignInModel) async {
        guard model.buttons == .rest else { return }
        await model.appleFinished(.failure(SampleTap()))
    }
    #endif

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

/// The splash sets its words balanced (Paper `1F5H-0`, `1F5G-0`: `text-wrap: balance`); welcome back
/// keeps the plain wrap until its own pass.
private struct SplashBalance: ViewModifier {
    let on: Bool

    func body(content: Content) -> some View {
        if on {
            content.rBalancedLines()
        } else {
            content
        }
    }
}
