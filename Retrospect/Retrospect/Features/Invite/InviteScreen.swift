//
//  InviteScreen.swift
//  PI1, the invite gate. Signed out with a link: the promise ("priya kept a place for you.") and Sign
//  in with Apple. Signed in with no code: the ticket takes a typed one, or the person joins the
//  waitlist. A used or expired code prints with that on its stub, and nobody meets a dead end: every
//  refusal offers the waitlist. Layout from Paper round 2 (T1, T-alt; board `2HXA-0`), 24 margins, 20
//  on SE. The page owns nothing but looks: `InviteModel` owns what is true.
//
//  A usable code (`ready`) is where PI2 takes over: the print, the tear and "you're in" (M14). Until
//  that PR lands this page shows the accepted ticket whole and still.
//
import AuthenticationServices
import SwiftUI

struct InviteScreen: View {
    @Bindable var model: InviteModel
    /// The sample launcher plays the sign-in on a tap (Apple's sheet can't run on invented data).
    var sampleTaps = false

    @State private var field = ""
    @State private var caretOn = true
    @State private var toast: RToastItem?
    @FocusState private var typing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rCompactHeight) private var compact
    @Environment(\.colorScheme) private var scheme

    /// Paper T1 `2I01-0`, on the 874-tall artboard: the words block starts 200 down, is 300 tall with its
    /// contents bottom-aligned 32 above the slot; the same shares of the screen on any height.
    private static let promiseTopShare: CGFloat = 200.0 / 874.0 // literal-ok: Paper T1 `2I01-0`
    private static let promiseBlockShare: CGFloat = 300.0 / 874.0 // literal-ok: Paper T1 `2IGY-0`

    private var margin: CGFloat {
        compact ? RDimension.space5 : RDimension.spaceScreenMargin
    }

    private enum Layout { case promise, ticket, paused, empty }

    private var layout: Layout {
        switch model.phase {
        case .promise, .signingIn, .waiting: .promise
        case .typed, .printing, .ready, .sealing, .torn, .youreIn, .refused: .ticket
        case .suspended: .paused
        case .alreadyIn: .empty
        }
    }

    var body: some View {
        RSheetHost {
            ZStack {
                RInviteWallpaper()
                page
            }
            .safeAreaInset(edge: .bottom, spacing: RDimension.space0) { bottomZone }
            .rSheet(isPresented: sheetBinding, detent: .medium) { InviteWaitlistSheet(model: model) }
            .rToast($toast, bottomInset: RDimension.space4)
        }
        .animation(RMotion.standard(RNumber.motionDurationSlow), value: model.phase)
        .animation(RMotion.standard(RNumber.motionDurationBase), value: model.notice)
        .animation(RMotion.standard(RNumber.motionDurationBase), value: model.waitlist)
        .sensoryFeedback(RHaptic.warning, trigger: model.warnings)
        .sensoryFeedback(RHaptic.confirm, trigger: model.confirms)
        .onChange(of: model.phase, initial: true) { old, new in
            if new == .alreadyIn {
                toast = RToastItem(message: InviteModel.alreadyInToast, symbol: "checkmark")
                model.onFinish()
            }
            if new == .typed, old != .typed {
                typing = true
            } else if new != .typed {
                typing = false
            }
            if new == .ready, old == .typed {
                announce("code accepted.")
            }
        }
        .onChange(of: model.tiles) { _, new in
            if field != new {
                field = new
            }
        }
        .task {
            guard !reduceMotion else { return }
            withAnimation(RMotion.standard(RNumber.motionDurationShimmer / 2).repeatForever(autoreverses: true)) { caretOn.toggle() }
        }
        .accessibilityIdentifier("screen.PI1")
    }

    private var sheetBinding: Binding<Bool> {
        Binding(
            get: { [.sheet, .joining, .failed].contains(model.waitlist) },
            set: {
                if !$0 {
                    model.closeWaitlist()
                }
            }
        )
    }

    // MARK: The page

    private var page: some View {
        GeometryReader { proxy in
            ScrollView {
                Group {
                    switch layout {
                    case .promise: promiseColumn(page: proxy)
                    case .ticket: ticketColumn(width: proxy.size.width)
                    case .paused: pausedColumn(page: proxy)
                    case .empty: Color.clear
                    }
                }
                .padding(.horizontal, margin)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: T1 · the promise

    private func promiseColumn(page: GeometryProxy) -> some View {
        let screen = page.size.height + page.safeAreaInsets.top + page.safeAreaInsets.bottom
        return VStack(spacing: RDimension.space0) {
            VStack(spacing: RDimension.space2) {
                if let label = model.promiseLabel {
                    Text(label)
                        .rText(.labelMedium)
                        .foregroundStyle(RColor.textLabel)
                        .transition(.blurReplace)
                }
                Text(model.promiseTitle)
                    .rText(.inviteTitle)
                    .foregroundStyle(RColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .id(model.promiseTitle)
                    .transition(.blurReplace)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, RDimension.space8)
            .frame(height: screen * Self.promiseBlockShare, alignment: .bottom)
            // 20 wider than the ticket, so it overhangs the margins evenly: centred in an overlay
            Color.clear
                .frame(height: RPrinterSlot.bar)
                .overlay(alignment: .top) { RPrinterSlot(ticketWidth: ticketWidth(page: page.size.width), state: .rest).fixedSize() }
            promiseLineView
                .padding(.top, RDimension.space6)
        }
        .padding(.top, max(screen * Self.promiseTopShare - page.safeAreaInsets.top, RDimension.space0))
        .rAppear()
    }

    private var promiseLineView: some View {
        HStack(spacing: RDimension.space2) {
            if model.phase == .signingIn {
                RSpinner(diameter: RDimension.sizeIconDefault)
            } else if model.phase == .waiting(.offline) {
                RSymbol(name: "wifi.slash", size: .small, tint: RColor.textLabel)
            }
            Text(model.promiseLine)
                .rText(.body)
                .foregroundStyle(model.phase == .waiting(.offline) ? RColor.textLabel : RColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .id(model.promiseLine)
        .transition(.blurReplace)
    }

    // MARK: T-alt · the ticket

    private func ticketWidth(page: CGFloat) -> CGFloat {
        page - 2 * margin // literal-ok: two margins
    }

    private func geometry(page: CGFloat) -> TicketGeometry {
        TicketGeometry(width: min(ticketWidth(page: page), RDimension.layoutSheetMaxWidth), compact: compact)
    }

    private func ticketColumn(width: CGFloat) -> some View {
        VStack(spacing: RDimension.space0) {
            ticketStage(width: width)
                .padding(.top, compact ? RDimension.space8 : RDimension.space10 + RDimension.space2)
            captionBlock
                .padding(.top, RDimension.space6)
        }
        .frame(maxWidth: .infinity)
    }

    private func ticketStage(width: CGFloat) -> some View {
        let geometry = geometry(page: width)
        return TicketStage(
            geometry: geometry,
            face: model.face,
            tiles: model.shownTiles,
            date: model.stubDate,
            label: model.stubLabel,
            typed: model.phase == .typed,
            caretOn: caretOn,
            reduceMotion: reduceMotion
        )
        .overlay(alignment: .topLeading) { codeField(geometry) }
        .rShake(trigger: model.wrongCodes)
        .frame(width: geometry.width)
    }

    /// The hidden field the tiles read from: any tap on the stub focuses it, never selecting text.
    @ViewBuilder private func codeField(_ geometry: TicketGeometry) -> some View {
        if model.phase == .typed {
            TextField("", text: $field)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.none)
                .focused($typing)
                .disabled(model.codeLocked)
                .opacity(0.02) // literal-ok: a field must stay in the hierarchy to keep focus
                .frame(width: geometry.width, height: geometry.stubHeight)
                .contentShape(Rectangle())
                .offset(y: geometry.perforationY + TicketGeometry.holeRowHeight / 2)
                .onChange(of: field) { _, new in
                    model.setCode(new)
                    if field != model.tiles {
                        field = model.tiles
                    }
                }
                .accessibilityLabel("invitation code, \(model.tiles.count) of \(TicketCode.length) characters")
                .accessibilityValue(TicketCode.spelled(model.tiles))
                .accessibilityIdentifier("ticket.field")
        }
    }

    // MARK: Words under the ticket

    private var captionBlock: some View {
        VStack(spacing: RDimension.space1) {
            if let caption = model.caption {
                Text(caption)
                    .rText(.body)
                    .foregroundStyle(RColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(caption)
                    .transition(.blurReplace)
                    .accessibilityIdentifier("invite.caption")
            }
            if let sub = model.subcaption {
                Text(sub)
                    .rText(.body)
                    .foregroundStyle(RColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.blurReplace)
            }
            if let hint = model.hint {
                hintPill(hint)
                    .padding(.top, RDimension.space2)
                    .transition(.blurReplace)
            }
            if model.offersWaitlist {
                RButton(title: "no invitation? join the waitlist", variant: .text) { model.openWaitlist() }
                    .accessibilityIdentifier("invite.waitlist")
            }
        }
    }

    private func hintPill(_ text: String) -> some View {
        Text(text)
            .rText(.labelMedium)
            .foregroundStyle(RColor.textSecondary)
            .padding(.horizontal, RDimension.space3)
            .frame(minHeight: RDimension.sizeControlSmall)
            .rWash()
            .id(text)
    }

    // MARK: Suspended

    private func pausedColumn(page: GeometryProxy) -> some View {
        let screen = page.size.height + page.safeAreaInsets.top + page.safeAreaInsets.bottom
        return Text(InviteModel.pausedTitle)
            .rText(.inkCard)
            .foregroundStyle(RColor.textPrimary)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, screen * Self.promiseTopShare)
            .rAppear()
            .accessibilityIdentifier("invite.paused")
    }

    // MARK: The bottom zone

    @ViewBuilder private var bottomZone: some View {
        switch layout {
        case .promise: promiseBottom
        case .ticket: ticketBottom
        case .paused, .empty: EmptyView()
        }
    }

    private var promiseBottom: some View {
        VStack(spacing: RDimension.space3) {
            if !isWaiting {
                RSignInButtons(
                    state: model.phase == .signingIn ? .pending : (model.isOnline ? .rest : .disabled(reason: "connect to sign in")),
                    onRequest: model.prepareApple,
                    onCompletion: { result in Task { await model.appleFinished(result) } }
                )
                .overlay {
                    if sampleTaps, model.phase == .promise {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { Task { await model.appleFinished(.failure(SampleSignInTap())) } }
                    }
                }
                .accessibilityIdentifier("invite.apple")
                Text(InviteModel.legal)
                    .rText(.label)
                    .foregroundStyle(RColor.textLabel)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, margin)
        .padding(.bottom, compact ? RDimension.space4 : RDimension.space6)
        .transition(.opacity)
    }

    private var isWaiting: Bool {
        if case .waiting = model.phase {
            true
        } else {
            false
        }
    }

    @ViewBuilder private var ticketBottom: some View {
        if let footer = model.footer {
            Text(footer)
                .rText(.label)
                .foregroundStyle(RColor.textLabel)
                .multilineTextAlignment(.center)
                .padding(.bottom, RDimension.space6)
                .id(footer)
                .transition(.blurReplace)
        }
    }

    private func announce(_ words: String) {
        AccessibilityNotification.Announcement(words).post()
    }
}

/// Stands in for Apple's result when the launcher plays the sign-in on sample data.
struct SampleSignInTap: Error {}
