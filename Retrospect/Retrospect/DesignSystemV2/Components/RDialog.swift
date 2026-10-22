//
//  RDialog.swift
//  M14 C19.2: the dialog (design-system/components/sheet-and-dialog.md, reference §C19; Paper
//  entry master "c · entry page · what i took · delete" E20-0 / E25-0, part 24 A5L-0). One
//  question that must be answered, over a dimmed page: an overlay card (rOverlay) the width of
//  the screen inside its margins, radius.field, padded 24 / 24 / 16; the title in the display
//  serif at 22, one plain line saying exactly what happens (8 below), then two stacked actions
//  16 below: the confirming one as the only destructive lit button in the app (48, rLitDanger)
//  above a plain "keep it" (44), 4 apart. It appears scaled up from motion.scale.enter with a
//  fade on motion.spring.popover (a 140 cross-fade under Reduce Motion), the `warning` haptic
//  fires on touch-down of the destructive button, pending shows the dots over the kept label
//  with cancel disabled, an error keeps the dialog with one line under the actions, and
//  offline disables confirm with "needs a connection". Pages present it with
//  `.rDialog(isPresented:) { RDialog(…) }`.
//
import SwiftUI

struct RDialog: View {
    enum Status: Equatable {
        case rest
        /// The confirming action is running: dots over its label, cancel disabled.
        case pending
        /// It failed: the dialog stays, with the failure's plain message under the actions.
        case error(message: String)
        /// No connection: confirm is disabled and says why.
        case offline
    }

    /// The question ("delete this entry?").
    let title: String
    /// Exactly what happens ("this removes it and what retro took from it. it can't be undone.").
    let line: String
    /// The destructive action's words ("delete it").
    let confirmTitle: String
    /// The way out ("keep it").
    var cancelTitle = "keep it"
    var status: Status = .rest
    let confirm: () -> Void
    let cancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The words VoiceOver hears first, as an alert: the question, then what happens.
    static func spoken(title: String, line: String) -> String {
        "\(title) \(line)"
    }

    /// Whether the confirming action can be taken now.
    static func canConfirm(_ status: Status) -> Bool {
        switch status {
        case .rest, .error: true
        case .pending, .offline: false
        }
    }

    private var isPending: Bool {
        status == .pending
    }

    private var isError: Bool {
        if case .error = status {
            return true
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space4) {
            // the words scroll only when they don't fit (accessibility sizes)
            ViewThatFits(in: .vertical) {
                words
                ScrollView { words }
                    .scrollBounceBehavior(.basedOnSize)
            }
            VStack(spacing: RDimension.space1) {
                confirmButton
                cancelButton
            }
            footnote
        }
        .padding(.top, RDimension.space6)
        .padding(.horizontal, RDimension.space6)
        .padding(.bottom, RDimension.space4)
        .frame(maxWidth: .infinity)
        .rOverlay(RDimension.radiusField)
        .animation(RMotion.standard(RNumber.motionDurationFast), value: status)
        .sensoryFeedback(RHaptic.error, trigger: isError) { old, new in !old && new }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.spoken(title: title, line: line))
        // the way out, unless the confirming action is running (the same rule as the cancel button)
        .accessibilityAction(.escape) {
            if !isPending {
                cancel()
            }
        }
        .accessibilityIdentifier("dialog")
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            Text(title)
                .rText(.dialogTitle)
                .foregroundStyle(RColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(line)
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // the container speaks these words once; the actions stay reachable
        .accessibilityHidden(true)
    }

    /// The one destructive lit button in the app: 48, rLitDanger; the `warning` haptic on
    /// touch-down; pending keeps the words' width under the dots.
    private var confirmButton: some View {
        Button(action: confirm) {
            Text(confirmTitle)
                .rText(.dialogAction)
                .foregroundStyle(RColor.glowDangerForeground)
                .opacity(isPending ? 0 : 1)
                .overlay {
                    if isPending {
                        RPendingDots()
                            .foregroundStyle(RColor.glowDangerForeground)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: RDimension.sizeControlLarge)
                .contentShape(Rectangle())
        }
        .buttonStyle(RDangerStyle())
        .disabled(!Self.canConfirm(status))
        .accessibilityValue(isPending ? "busy" : "")
        .accessibilityIdentifier("dialog.confirm")
    }

    /// The way out, plain words, 44 tall; the default action for VoiceOver (escape).
    private var cancelButton: some View {
        Button(action: cancel) {
            Text(cancelTitle)
                .rText(.dialogCancel)
                .foregroundStyle(RColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: RDimension.sizeTouchTarget)
                .contentShape(Rectangle())
        }
        .rPress()
        .disabled(isPending)
        .opacity(isPending ? RNumber.opacityDisabled : 1)
        .accessibilityIdentifier("dialog.cancel")
    }

    /// Under the actions: the failure's own words, or why confirm can't be used.
    @ViewBuilder
    private var footnote: some View {
        switch status {
        case let .error(message):
            Text(message)
                .rText(.metaLine)
                .foregroundStyle(RColor.statusDangerText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .rBlurReplace()
        case .offline:
            Text("needs a connection")
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
                .frame(maxWidth: .infinity, alignment: .center)
                .rBlurReplace()
        case .rest, .pending:
            EmptyView()
        }
    }
}

/// The destructive button: the danger glow, pressed shade and 0.98 on touch down, the `warning`
/// haptic as the finger lands; disabled it dims (and keeps its shape).
private struct RDangerStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .rLitDanger(pressed: pressed)
            .compositingGroup()
            .opacity(isEnabled ? 1 : RNumber.opacityDisabled)
            .scaleEffect(pressed && !reduceMotion ? RNumber.motionScalePress : 1)
            .animation(pressed ? RMotion.standard(RNumber.motionDurationPressIn) : RMotion.snappy, value: pressed)
            .sensoryFeedback(trigger: pressed) { _, down in
                down ? RHaptic.warning : nil
            }
    }
}

// MARK: - Presenting

private struct RDialogModifier<Dialog: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let dialog: () -> Dialog
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    if isPresented {
                        RColor.backgroundScrim
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .accessibilityHidden(true)
                        dialog()
                            .padding(RDimension.spaceScreenMargin)
                            // modal only while presented: a dialog drawn in place (the lab) isn't one
                            .accessibilityAddTraits(.isModal)
                            .transition(reduceMotion
                                ? .opacity
                                : .scale(scale: RNumber.motionScaleEnter).combined(with: .opacity))
                    }
                }
                .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.popover, value: isPresented)
            }
    }
}

extension View {
    /// Shows `dialog` centred over this page, dimmed, while `isPresented` is true. The dialog's
    /// own cancel (or the VoiceOver escape) is the way out: the scrim doesn't dismiss a question.
    func rDialog(isPresented: Binding<Bool>, @ViewBuilder dialog: @escaping () -> some View) -> some View {
        modifier(RDialogModifier(isPresented: isPresented, dialog: dialog))
    }
}

extension RTextStyle {
    /// The dialog's question (Paper E25-0: --font-display, --text-xl, --tracking-card, snug).
    static let dialogTitle = RTextStyle(
        family: .display,
        size: RDimension.fontSizeXl,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: 1.3,
        relativeTo: .title2
    )
    /// The destructive button's words (c:button/destructive-compact: Geist 16 medium, --tracking-label).
    static let dialogAction = RTextStyle(
        family: .label,
        size: RDimension.fontSizeBase,
        weight: .medium,
        tracking: RNumber.fontTrackingLabel,
        leading: 1.3,
        relativeTo: .body
    )
    /// "keep it" (c:button/link: Geist 14 medium, no tracking).
    static let dialogCancel = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .subheadline
    )
}

#if DEBUG
/// Lab page "dialog": a page that presents the delete dialog (confirm runs, fails once, then
/// works), and the dialog bare in its states. `-DesignLabAutoplay` opens it for recordings.
struct RDialogGallery: View {
    @State private var presented = false
    @State private var status: RDialog.Status = .rest
    @State private var attempts = 0

    private let title = "delete this entry?"
    private let line = "this removes it and what retro took from it. it can't be undone."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                caption("a page · delete entry (the first try fails)")
                RPill(title: "delete entry", symbol: "trash", style: .raised) {
                    status = .rest
                    presented = true
                }
                .accessibilityIdentifier("dialog.open")
                caption("rest (E25-0)")
                RDialog(title: title, line: line, confirmTitle: "delete it", confirm: {}, cancel: {})
                caption("pending")
                RDialog(title: title, line: line, confirmTitle: "delete it", status: .pending, confirm: {}, cancel: {})
                caption("error")
                RDialog(
                    title: title,
                    line: line,
                    confirmTitle: "delete it",
                    status: .error(message: "retro couldn't be reached. try again."),
                    confirm: {},
                    cancel: {}
                )
                caption("offline")
                RDialog(title: title, line: line, confirmTitle: "delete it", status: .offline, confirm: {}, cancel: {})
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .rDialog(isPresented: $presented) {
            RDialog(title: title, line: line, confirmTitle: "delete it", status: status) {
                Task { await confirm() }
            } cancel: {
                presented = false
            }
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            presented = true
        }
    }

    /// Pending for a moment; the first attempt fails, the next closes the dialog.
    private func confirm() async {
        attempts += 1
        status = .pending
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        if attempts % 2 == 1 {
            status = .error(message: "retro couldn't be reached. try again.")
        } else {
            status = .rest
            presented = false
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("dialog") { RDialogGallery() }
#endif
