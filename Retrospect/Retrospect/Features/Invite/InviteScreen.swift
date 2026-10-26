//
//  InviteScreen.swift
//  PI1, the invite gate. Signed out with a link: the promise ("priya kept a place for you.") and Sign
//  in with Apple. Signed in with no code: the ticket takes a typed one, or the person joins the
//  waitlist. A used or expired code prints with that on its stub, and nobody meets a dead end: every
//  refusal offers the waitlist. Layout from Paper round 2 (T1, T-alt; board `2HXA-0`), 24 margins, 20
//  on SE. The page owns nothing but looks: `InviteModel` owns what is true.
//
//  PI2 (M14) lives on the same page: a usable code prints out of the slot, the person tears it along the
//  perforation, the stub drops clear and it reads "you're in". One ticket instance throughout.
//
import AuthenticationServices
import SwiftUI

struct InviteScreen: View {
    @Bindable var model: InviteModel
    /// The sample launcher plays the sign-in on a tap (Apple's sheet can't run on invented data).
    var sampleTaps = false

    @State private var stage: InviteStageController
    @State private var caretOn = true
    @State private var toast: RToastItem?
    /// The page's bottom safe-area inset as laid out (see `bottomPadding`).
    @State private var bottomInset: CGFloat = 0
    @FocusState private var typing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rCompactHeight) private var compact
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase

    /// Paper T1 `2I01-0`, on the 874-tall artboard: the words block starts 200 down, is 300 tall with its
    /// contents bottom-aligned 32 above the slot; the same shares of the screen on any height.
    private static let promiseTopShare: CGFloat = 200.0 / 874.0 // literal-ok: Paper T1 `2I01-0`
    /// The ticket's own coordinate space, declared on the stage and read by the tear drag.
    static let ticketSpace = "ticket"
    private static let promiseBlockShare: CGFloat = 300.0 / 874.0 // literal-ok: Paper T1 `2IGY-0`
    /// Paper T-alt `2ISE-0` / T5 `2IN3-0`: the ticket's top edge, from the screen's top.
    private static let ticketTop: CGFloat = 104 // literal-ok: Paper stage padding-top 104

    init(model: InviteModel, sampleTaps: Bool = false, printStill: CGFloat? = nil, tear: CGFloat = 0) {
        self.model = model
        self.sampleTaps = sampleTaps
        _stage = State(initialValue: InviteStageController(model: model, printStill: printStill, tear: tear))
    }

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
            // the bottom inset the page is actually laid out with: 0 while the sheet host lays it under the
            // home indicator (main today), the indicator's 34 once the host keeps to the safe area (#200)
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
            // the full detent: at medium the keyboard (typing a note) pushed the sheet's words up over the
            // page behind and cut "cancel", and SE cut the line to "when there'…"
            .rSheet(isPresented: sheetBinding, detent: .full) { InviteWaitlistSheet(model: model) }
            .rToast($toast, bottomInset: RDimension.space4)
        }
        // The sheet host clips the page to its safe area, which left a white band under the status
        // bar; the same wallpaper behind it fills the band (seamless: both span the whole screen),
        // and shows round the page when the waitlist sheet makes it recede.
        .background { RInviteWallpaper() }
        .animation(RMotion.standard(RNumber.motionDurationSlow), value: model.phase)
        .animation(RMotion.standard(RNumber.motionDurationBase), value: model.notice)
        .animation(RMotion.standard(RNumber.motionDurationBase), value: model.waitlist)
        .sensoryFeedback(RHaptic.select, trigger: stage.ticks)
        .sensoryFeedback(RHaptic.select, trigger: stage.landings)
        .sensoryFeedback(TicketFeedback.rip, trigger: model.rips)
        .sensoryFeedback(RHaptic.reveal, trigger: model.reveals)
        .sensoryFeedback(RHaptic.warning, trigger: model.warnings)
        .sensoryFeedback(RHaptic.confirm, trigger: model.confirms)
        .onChange(of: model.phase, initial: true) { old, new in
            stage.phaseChanged(reduceMotion: reduceMotion)
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
                announce("code accepted. swipe along the line to tear, or use the tear action.")
            }
            if new == .youreIn, old == .torn || old == .sealing {
                announce("it's yours. you're in.")
            }
            // a link's refused or waiting check speaks on arrival (a tear's refusal speaks through `warnings`)
            if old != .sealing, new != old, model.isRefusedOrWaiting, let words = model.spokenFailure {
                announce(words)
            }
        }
        .onChange(of: scenePhase) { _, now in
            if now != .active {
                stage.dragCancelled()
                stage.holdReleased(completed: false)
            }
            if now == .active {
                stage.finishPrintNow()
                Task { await model.retry() }
            }
        }
        // every failure is said as well as felt, each time (a second wrong code in a row too)
        .onChange(of: model.warnings) { announceFailure() }
        .onChange(of: model.wrongCodes) { announceFailure() }
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
                    case .ticket: ticketColumn(page: proxy)
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
                        .rBlurReplace()
                }
                Text(model.promiseTitle)
                    .rText(.inviteTitle)
                    .foregroundStyle(RColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .id(model.promiseTitle)
                    .rBlurReplace()
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
        .rBlurReplace()
    }

    // MARK: T-alt · the ticket

    private func ticketWidth(page: CGFloat) -> CGFloat {
        page - 2 * margin // literal-ok: two margins
    }

    private func geometry(page: CGFloat) -> TicketGeometry {
        TicketGeometry(width: min(ticketWidth(page: page), RDimension.layoutSheetMaxWidth), compact: compact)
    }

    private func ticketColumn(page: GeometryProxy) -> some View {
        VStack(spacing: RDimension.space0) {
            ticketStage(width: page.size.width)
                // Paper T-alt/T5 `2ISE-0`/`2IN3-0`: the ticket's top is 104 from the screen's top edge
                .padding(.top, compact ? RDimension.space8 : max(Self.ticketTop - page.safeAreaInsets.top, RDimension.space8))
            if hasCaption {
                captionBlock
                    .padding(.top, RDimension.space6)
            }
            if model.phase == .youreIn || model.phase == .torn {
                youreInWords
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func ticketStage(width: CGFloat) -> some View {
        let geometry = geometry(page: width)
        let fallen = model.phase == .torn || model.phase == .youreIn
        return TicketStage(
            geometry: geometry,
            face: model.face,
            tiles: model.shownTiles,
            date: model.stubDate,
            label: model.stubLabel,
            typed: model.phase == .typed,
            caretOn: caretOn,
            tearProgress: stage.holdProgress > 0 && reduceMotion ? 0 : stage.tearProgress,
            stub: fallen ? .fallen : .joined,
            printProgress: stage.printProgress,
            reduceMotion: reduceMotion
        )
        .animation(RMotion.settle, value: fallen)
        .overlay(alignment: .bottom) { slotOverlay(geometry) }
        .overlay(alignment: .topLeading) { holdFill(geometry) }
        .overlay(alignment: .topLeading) { handleLayer(geometry) }
        .overlay(alignment: .topLeading) { codeField(geometry) }
        // the tear drag reads its finger here: x from the left notch, y from the ticket's top (an
        // undeclared name falls back to global coordinates, which put every drag 44pt+ off the line)
        .coordinateSpace(.named(Self.ticketSpace))
        .rShake(trigger: model.wrongCodes)
        .accessibilityActions {
            // only offered when it can work: outside .ready the action would do nothing, silently
            if stage.canTear {
                Button("tear ticket") { Task { await stage.tearByAction() } }
            }
        }
        .frame(width: geometry.width)
    }

    /// The slot at the ticket's lip while it prints, with the bend where the paper curls in.
    private func slotOverlay(_ geometry: TicketGeometry) -> some View {
        let showing = stage.slotPrinting && stage.printProgress < 1
        return ZStack(alignment: .bottom) {
            RPrinterBend()
                .frame(width: geometry.width)
                .offset(y: -RDimension.space2)
                .opacity(showing && stage.printProgress < 0.9 ? 1 : 0) // literal-ok: the band leaves as the print nears its end
            RPrinterSlot(ticketWidth: geometry.width, state: .printing)
                .offset(y: RPrinterSlot.mouth - RDimension.space2)
        }
        .opacity(showing ? 1 : 0)
        .animation(RMotion.exit(RNumber.motionDurationBase), value: showing)
        .allowsHitTesting(false)
    }

    /// The handle on the left notch, riding the tear point. Its gesture lives here, outside the tilt.
    @ViewBuilder private func handleLayer(_ geometry: TicketGeometry) -> some View {
        let available = model.phase == .ready || model.phase == .sealing
        RTicketHandle(held: stage.held)
            .offset(x: stage.tearProgress * geometry.width - RDimension.sizeTouchTarget / 2, y: geometry.perforationY - RDimension.sizeTouchTarget / 2)
            .gesture(reduceMotion ? nil : tearDrag(geometry))
            .simultaneousGesture(reduceMotion ? holdGesture : nil)
            .opacity(available ? 1 : 0)
            .allowsHitTesting(model.phase == .ready)
            .accessibilityHidden(true)
            .animation(RMotion.standard(RNumber.motionDurationBase), value: available)
    }

    /// The hidden field the tiles read from: any tap on the stub focuses it, never selecting text.
    @ViewBuilder private func codeField(_ geometry: TicketGeometry) -> some View {
        if model.phase == .typed {
            // Bound straight to the model: whatever the field holds is read whole and normalised onto
            // the tiles, so a refused character (a dash, a space) never leaves the field and the tiles
            // disagreeing. (A separate @State copy written back in onChange lost later keystrokes.)
            TextField("", text: Binding(get: { model.tiles }, set: { model.setCode($0) }))
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.none)
                .focused($typing)
                .disabled(model.codeLocked)
                .foregroundStyle(Color.clear) // the tiles show the characters; the field's own never show through
                .tint(Color.clear)
                .opacity(0.02) // literal-ok: a field must stay in the hierarchy to keep focus
                .frame(width: geometry.width, height: geometry.stubHeight)
                .contentShape(Rectangle())
                .offset(y: geometry.perforationY + TicketGeometry.holeRowHeight / 2)
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
                    .rBlurReplace()
                    .accessibilityIdentifier("invite.caption")
            }
            if let sub = model.subcaption {
                Text(sub)
                    .rText(.body)
                    .foregroundStyle(RColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .rBlurReplace()
            }
            if let hint = model.hint {
                // Paper T-alt `2ISF-0`: caption and hint 4 apart (the block's own gap)
                hintPill(hint)
                    .rBlurReplace()
            }
            if model.offersWaitlist {
                RButton(title: "no invitation? join the waitlist", variant: .text) { model.openWaitlist() }
                    .accessibilityIdentifier("invite.waitlist")
            }
        }
    }

    private func hintPill(_ text: String) -> some View {
        Text(text)
            .rText(.pillAction) // Paper `2ISJ-0`: Geist 12 medium, leading snug, no tracking
            .foregroundStyle(RColor.textSecondary)
            .padding(.horizontal, RDimension.space3)
            .frame(minHeight: RDimension.sizeControlSmall)
            .rWash()
            .id(text)
    }

    private var youreInWords: some View {
        VStack(spacing: RDimension.space2) {
            if model.phase == .youreIn {
                Text(model.youreInTitle)
                    .rText(.inviteTitle)
                    .foregroundStyle(RColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .rAppear()
                Text(model.youreInLine)
                    .rText(.body)
                    .foregroundStyle(RColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .rAppear(index: 1)
            }
        }
        .padding(.top, RDimension.space8)
        .padding(.bottom, RDimension.space6)
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
        .padding(.bottom, bottomPadding)
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
        if model.phase == .youreIn, model.beginVisible {
            RButton(title: "begin") { model.begin() }
                .padding(.horizontal, margin)
                // Paper T5 `2IMI-0`: 40 from the screen's edge, clear of the home indicator (was 16 from it)
                .padding(.bottom, bottomPadding)
                .transition(.blurReplace)
                .accessibilityIdentifier("invite.begin")
        } else if let footer = model.footer, !typing { // the footer gives way to the keyboard: above it, it would sit on the caption
            Text(footer)
                .rText(.metaLine) // Paper `2IRU-0`: Geist 12, leading snug, no tracking
                .foregroundStyle(RColor.textLabel)
                .multilineTextAlignment(.center)
                .padding(.bottom, bottomPadding)
                .id(footer)
                .rBlurReplace()
        }
    }

    private func announce(_ words: String) {
        AccessibilityNotification.Announcement(words).post()
    }

    private func announceFailure() {
        if let words = model.spokenFailure {
            announce(words)
        }
    }
}

/// Stands in for Apple's result when the launcher plays the sign-in on sample data.
struct SampleSignInTap: Error {}

enum TicketFeedback {
    /// The rip: a rigid impact on the frame the stub lets go (FR0.1's `haptic.rip`).
    static let rip: SensoryFeedback = .impact(flexibility: .rigid, intensity: 0.8) // literal-ok: FR0.1 token, not yet generated
}

/// Layout values read from Paper, kept out of the struct body.
extension InviteScreen {
    /// Paper T1/T-alt/T5: the bottom zone ends 40 above the screen's edge, whatever the host does with
    /// the home indicator: the inset the page is laid out with counts toward the 40 (16 on SE, which has
    /// none). Never a fixed number standing in for the inset (plan-screens §10).
    var bottomPadding: CGFloat {
        compact ? RDimension.space4 : max(RDimension.space10 - bottomInset, RDimension.space1)
    }

    /// Paper T5 draws nothing between the fallen stub and "you're in": an empty caption block takes no room.
    var hasCaption: Bool {
        model.caption != nil || model.subcaption != nil || model.hint != nil || model.offersWaitlist
    }
}

/// The tear and hold gestures, kept out of the struct body.
extension InviteScreen {
    /// Reduce Motion: the 0.6 s hold fills along the tear line from the left, so the wait is seen
    /// (it empties again when the finger lifts early).
    @ViewBuilder private func holdFill(_ geometry: TicketGeometry) -> some View {
        if reduceMotion {
            RShape.pill
                .fill(RColor.glowPrimaryGradientBottom)
                .frame(width: geometry.width * stage.holdProgress, height: RDimension.sizeBorderRing)
                .offset(y: geometry.perforationY - RDimension.sizeBorderRing / 2)
                .opacity(stage.holdProgress > 0 ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func tearDrag(_ geometry: TicketGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.ticketSpace))
            .onChanged { value in
                stage.dragChanged(x: value.location.x, dy: value.location.y - geometry.perforationY, width: geometry.width)
            }
            .onEnded { value in
                stage.dragEnded(x: value.location.x, velocity: value.velocity.width, width: geometry.width)
            }
    }

    /// Reduce Motion: a touch starts the 0.6 s hold (the controller completes it itself); lifting early empties it.
    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in stage.holdBegan() }
            .onEnded { _ in stage.holdReleased(completed: false) }
    }
}
