//
//  RSheetHost.swift
//  M14 C19.1: the sheet (design-system/components/sheet-and-dialog.md, player.md's
//  choreography, reference §C19; Paper "c · player sheet" B1C-0, B9C-0, states B33-0). A custom
//  presentation, decided in the plan (§9 #20), because one progress value has to drive the
//  sheet, the page behind it and the scrim together: the sheet rises on motion.spring.sheet
//  while the page scales to motion.scale.behindSheet, rounds to radius.behindSheet and dims
//  under background.scrim, all from `p`. The sheet is the rSheet recipe (background.raised,
//  radius.sheet on top), a 36 × 5 grabber in border.strong 10 below its top, content inset 28
//  with a flexible middle so bottom controls stay on screen, at most layout.sheetMaxWidth wide.
//  A drag follows the finger 1:1, rubber-bands past the top (motion.gesture.rubberBand), and on
//  release dismisses past motion.gesture.dismissDistance or faster than
//  motion.gesture.dismissVelocity (on motion.spring.sheetDismiss), else snaps to the nearest
//  detent (sheetSnap haptic at rest). The drag defers to the content's scroll view unless it
//  sits at its top. `RSheetHost` is installed once at the root of a tab; a page presents with
//  `.rSheet(isPresented:detent:content:)`. Never two sheets at once.
//
import SwiftUI

// MARK: - The model (pure)

enum RSheetDetent: Equatable {
    /// layout.sheetDetent.medium of the host's height.
    case medium
    /// The host's height less the strip of the page that stays visible above (layout.sheetTop).
    case full

    /// The sheet's height at this detent inside a host of `hostHeight`.
    func height(in hostHeight: CGFloat) -> CGFloat {
        switch self {
        case .medium: hostHeight * RNumber.layoutSheetDetentMedium
        case .full: Swift.max(hostHeight - RDimension.layoutSheetTop, .zero)
        }
    }
}

/// Where a sheet is, as one number: 0 is closed (fully below the page), 1 is resting at its
/// detent. Everything else on screen is a function of it.
enum RSheetProgress {
    /// The page behind: 1 at rest, motion.scale.behindSheet when the sheet is open.
    static func behindScale(_ p: Double) -> Double {
        1 - (1 - RNumber.motionScaleBehindSheet) * clamp(p)
    }

    /// The page's corners: square at rest, radius.behindSheet when the sheet is open.
    static func behindRadius(_ p: Double) -> CGFloat {
        RDimension.radiusBehindSheet * clamp(p)
    }

    /// The scrim's opacity (its colour already carries 40% light, 60% dark).
    static func scrimOpacity(_ p: Double) -> Double {
        clamp(p)
    }

    /// The sheet's offset below its resting place, for a sheet `height` tall.
    static func offset(_ p: Double, height: CGFloat) -> CGFloat {
        height * (1 - Swift.min(p, 1))
    }

    /// A finger past the top: the overshoot shrinks by motion.gesture.rubberBand.
    static func rubberBanded(overshoot: CGFloat) -> CGFloat {
        overshoot * RNumber.motionGestureRubberBand
    }

    /// Whether a release closes the sheet: dragged down past motion.gesture.dismissDistance, or
    /// flicked down faster than motion.gesture.dismissVelocity from any height.
    static func dismisses(dragDown distance: CGFloat, velocity: CGFloat) -> Bool {
        distance > RDimension.motionGestureDismissDistance || velocity > RNumber.motionGestureDismissVelocity
    }

    /// Progress from a finger's drag, measured down from the resting place.
    static func progress(dragDown distance: CGFloat, height: CGFloat) -> Double {
        guard height > 0 else { return 1 }
        return 1 - Double(distance / height)
    }

    private static func clamp(_ p: Double) -> Double {
        Swift.min(Swift.max(p, .zero), 1)
    }
}

/// The host's measured frame: its own height (to the screen's bottom edge, or to the keyboard's
/// top while it is up) and the safe area's height with the keyboard left out.
struct RSheetHostFrame: Equatable {
    var height: CGFloat = 0
    var safeHeight: CGFloat = 0

    /// How much of the home-indicator strip lies inside the host: the page and the sheet's content
    /// are padded by it. Under the keyboard there is none, so nothing is padded twice.
    var bottomInset: CGFloat {
        guard height > 0, safeHeight > 0 else { return .zero }
        return Swift.max(height - safeHeight, .zero)
    }
}

// MARK: - The request a page makes

/// What a page asks the host to show. Carried up by preference so the host, installed once at
/// the root, draws the sheet over the whole tab.
struct RSheetRequest: Identifiable {
    let id: UUID
    let isPresented: Binding<Bool>
    let detent: RSheetDetent
    let content: () -> AnyView
}

private struct RSheetRequestKey: PreferenceKey {
    static let defaultValue: [RSheetRequest] = []
    static func reduce(value: inout [RSheetRequest], nextValue: () -> [RSheetRequest]) {
        value.append(contentsOf: nextValue())
    }
}

private struct RSheetModifier<Sheet: View>: ViewModifier {
    @Binding var isPresented: Bool
    let detent: RSheetDetent
    @ViewBuilder let sheet: () -> Sheet
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content.preference(
            key: RSheetRequestKey.self,
            value: isPresented ? [RSheetRequest(id: id, isPresented: $isPresented, detent: detent, content: { AnyView(sheet()) })] : []
        )
    }
}

extension View {
    /// Presents `content` as the tab's sheet while `isPresented` is true. The nearest
    /// `RSheetHost` above draws it; a second request while one is open waits its turn (never
    /// two sheets stacked).
    func rSheet(isPresented: Binding<Bool>, detent: RSheetDetent = .medium, @ViewBuilder content: @escaping () -> some View) -> some View {
        modifier(RSheetModifier(isPresented: isPresented, detent: detent, sheet: content))
    }
}

// MARK: - The host

/// Installed once at the root of each tab: the page as `content`, the sheet over it.
struct RSheetHost<Content: View>: View {
    @ViewBuilder let content: () -> Content

    /// Where the sheet is, 0 closed to 1 at rest (past 1 while rubber-banding).
    @State private var progress: Double = 0
    /// The request being shown; kept while it closes so the content doesn't vanish mid-motion.
    @State private var shown: RSheetRequest?
    @State private var frame = RSheetHostFrame()
    @State private var contentAtTop = true
    @State private var dragging = false
    /// Counts settles, so the snap haptic fires once per rest.
    @State private var settled = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        content()
            // The host runs to the screen's bottom edge (so the sheet does, at its own height); the
            // page gets the home-indicator strip back as safe area, so its controls stay above it
            // while a background that ignores the safe area still reaches the edge.
            .safeAreaPadding(.bottom, frame.bottomInset)
            .overlayPreferenceValue(RSheetRequestKey.self) { requests in
                Color.clear
                    .onChange(of: requests.first?.id, initial: true) { _, _ in
                        take(requests.first)
                    }
            }
            .scaleEffect(reduceMotion ? 1 : RSheetProgress.behindScale(progress))
            // the clip runs to the screen edges: no bare band under the status bar
            .mask {
                RShape.rect(RSheetProgress.behindRadius(progress)).ignoresSafeArea()
            }
            .overlay {
                scrim
            }
            .overlay(alignment: .bottom) {
                if let shown {
                    sheet(shown)
                }
            }
            // the host's own height, as on main: to the screen's edge, or to the keyboard's top
            .background {
                Color.clear.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { frame.height = $0 }
            }
            .sensoryFeedback(RHaptic.sheetSnap, trigger: settled)
            .ignoresSafeArea(.container, edges: .bottom)
            // the safe area's height with the keyboard left out, measured outside the host
            .background {
                Color.clear
                    .ignoresSafeArea(.keyboard)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { frame.safeHeight = $0 }
            }
    }

    // MARK: Opening and closing

    private var sheetHeight: CGFloat {
        (shown?.detent ?? .medium).height(in: frame.height)
    }

    /// A new request opens once the current sheet has closed; the same request is left alone.
    private func take(_ request: RSheetRequest?) {
        if let request {
            guard shown?.id != request.id, shown == nil else { return }
            shown = request
            progress = 0
            open()
        } else if shown != nil {
            close()
        }
    }

    private func open() {
        withAnimation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.sheet) {
            progress = 1
        } completion: {
            settled += 1
        }
    }

    /// The release's velocity decides whether it closes (`dismisses`); the token spring carries
    /// the motion, so a flick and a slow drag past the distance leave on the same curve.
    private func close() {
        withAnimation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.sheetDismiss) {
            progress = 0
        } completion: {
            guard progress == 0 else { return }
            shown?.isPresented.wrappedValue = false
            shown = nil
        }
    }

    private func snapBack() {
        withAnimation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.sheet) {
            progress = 1
        } completion: {
            settled += 1
        }
    }

    // MARK: The layers

    private var scrim: some View {
        RColor.backgroundScrim
            .opacity(RSheetProgress.scrimOpacity(progress))
            .ignoresSafeArea()
            .allowsHitTesting(shown != nil)
            .onTapGesture {
                close()
            }
            .accessibilityHidden(true)
    }

    private func sheet(_ request: RSheetRequest) -> some View {
        VStack(spacing: RDimension.space0) {
            grabber
            request.content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y <= 0 } action: { _, atTop in
                    contentAtTop = atTop
                }
                .scrollDisabled(dragging)
        }
        .padding(.horizontal, RDimension.layoutSheetInset)
        // the panel runs to the screen edge; its controls stop above the home indicator
        .padding(.bottom, frame.bottomInset)
        .frame(maxWidth: RDimension.layoutSheetMaxWidth)
        .frame(height: sheetHeight)
        .rSheet()
        // Increase Contrast: a 1pt control line along the top edge
        .overlay(alignment: .top) {
            RShape.top(RDimension.radiusSheet)
                .stroke(RColor.borderControl, lineWidth: contrast == .increased ? RDimension.sizeBorderDefault : RDimension.space0)
                .mask(alignment: .top) { Rectangle().frame(height: RDimension.radiusSheet) }
        }
        .offset(y: reduceMotion ? RDimension.space0 : RSheetProgress.offset(progress, height: sheetHeight))
        .opacity(reduceMotion ? RSheetProgress.scrimOpacity(progress) : 1)
        .simultaneousGesture(drag)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            close()
        }
        .accessibilityIdentifier("sheet")
    }

    private var grabber: some View {
        RShape.pill
            .fill(RColor.borderStrong)
            .frame(width: RDimension.sizeGrabberWidth, height: RDimension.sizeGrabberHeight)
            .padding(.top, RDimension.layoutSheetTop)
            .padding(.bottom, RDimension.layoutSheetGrabberGap)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }

    // MARK: The drag

    /// Follows the finger 1:1 while the content sits at its top (or the finger is on the
    /// grabber); past the top it rubber-bands. The release decides from distance and velocity.
    private var drag: some Gesture {
        DragGesture(minimumDistance: RDimension.space2, coordinateSpace: .local)
            .onChanged { value in
                guard contentAtTop || dragging else { return }
                let down = value.translation.height
                if !dragging, down <= 0 {
                    return
                }
                dragging = true
                if down >= 0 {
                    progress = RSheetProgress.progress(dragDown: down, height: sheetHeight)
                } else {
                    progress = RSheetProgress.progress(dragDown: RSheetProgress.rubberBanded(overshoot: down), height: sheetHeight)
                }
            }
            .onEnded { value in
                guard dragging else { return }
                dragging = false
                let down = value.translation.height
                if RSheetProgress.dismisses(dragDown: down, velocity: value.velocity.height) {
                    close()
                } else {
                    snapBack()
                }
            }
    }
}

#if DEBUG
/// Lab page "sheet": a page with a long sheet (scrolls; controls stay on screen) and a short one
/// at the medium detent. `-DesignLabAutoplay` opens, closes and reopens the medium sheet.
struct RSheetHostGallery: View {
    @State private var long = false
    @State private var short = false

    var body: some View {
        RSheetHost {
            ScrollView {
                VStack(alignment: .leading, spacing: RDimension.space6) {
                    Text("a page behind").rText(.inkTitle).foregroundStyle(RColor.textPrimary)
                    Text("open a sheet: the page recedes and dims in step with it; drag the sheet, flick it, or tap the scrim.")
                        .rText(.bodyReading)
                        .foregroundStyle(RColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: RDimension.space2) {
                        RPill(title: "long, full", style: .raised) { long = true }
                            .accessibilityIdentifier("sheet.openLong")
                        RPill(title: "short, medium", style: .raised) { short = true }
                            .accessibilityIdentifier("sheet.openShort")
                    }
                    ForEach(0 ..< 12, id: \.self) { index in
                        RShape.rect(RDimension.radiusCard)
                            .fill(RColor.surfaceWash)
                            .frame(height: RDimension.sizeRowDefault)
                            .accessibilityLabel("row \(index + 1)")
                    }
                }
                .padding(RDimension.spaceScreenMargin)
            }
            .background(RColor.backgroundCanvas)
            .rSheet(isPresented: $long, detent: .full) { longSheet }
            .rSheet(isPresented: $short, detent: .medium) { shortSheet }
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            for _ in 0 ..< 2 {
                do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
                short = true
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                short = false
            }
        }
    }

    /// A flexible middle that scrolls, and a control row that never leaves the screen.
    private var longSheet: some View {
        VStack(spacing: RDimension.space4) {
            Text("why this is here").rText(.displayTitle).foregroundStyle(RColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView {
                VStack(alignment: .leading, spacing: RDimension.space3) {
                    ForEach(0 ..< 20, id: \.self) { index in
                        Text("line \(index + 1) of what it rests on")
                            .rText(.body)
                            .foregroundStyle(RColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .scrollClipDisabled()
            .frame(minHeight: RDimension.space0, maxHeight: .infinity)
            RPill(title: "done", style: .raised) { long = false }
                .accessibilityIdentifier("sheet.done")
        }
        .padding(.bottom, RDimension.spaceScreenMargin)
    }

    private var shortSheet: some View {
        VStack(spacing: RDimension.space4) {
            Text("sign out?").rText(.displayTitle).foregroundStyle(RColor.textPrimary)
            Text("your entries and episodes stay on the server.")
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: RDimension.space0)
            RPill(title: "cancel", style: .raised) { short = false }
                .accessibilityIdentifier("sheet.cancel")
        }
        .padding(.bottom, RDimension.spaceScreenMargin)
    }
}

#Preview("sheet host") { RSheetHostGallery() }
#endif
