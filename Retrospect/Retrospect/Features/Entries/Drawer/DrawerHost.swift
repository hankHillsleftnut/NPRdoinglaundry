//
//  DrawerHost.swift
//  V2.journal (dark) · JR-3: the journal and its drawer (Paper 1FOQ-0; build notes, journal pages
//  M4; screen rule 29). Closed, the journal fills the screen. Open, the journal slides right until
//  74 of its edge is left (the way back), rounded to radius.sheet with the overlay shadow (Paper
//  1FP7-0), and the drawer lies behind it on background.underlay, as wide as the screen less 74.
//  The status bar stays over both layers. Opens from the journal's drawer button or a swipe from
//  the screen's leading edge; closes from a tap or a swipe on the journal's edge, or VoiceOver's
//  escape. Moves on the sheet spring; with Reduce Motion it fades instead of sliding far.
//
import SwiftUI

struct DrawerHost<Drawer: View, Journal: View>: View {
    @Binding var isOpen: Bool
    @ViewBuilder let drawer: (_ onHomeIndicator: Bool) -> Drawer
    @ViewBuilder let journal: () -> Journal

    /// How much of the journal stays in view when the drawer is open (build notes: screen − 74).
    static var journalEdge: CGFloat {
        74
    } // literal-ok: Paper 1FP7-0 sits at 328 on a 402 screen; no size token yet (J-27)
    /// Where a swipe can start to open the drawer: the screen's leading edge.
    static var edgeSwipeWidth: CGFloat {
        RDimension.space5
    }

    @GestureState private var drag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let width = proxy.size.width + insets.leading + insets.trailing
            let travel = max(width - Self.journalEdge, RDimension.space0)
            let offset = min(max((isOpen ? travel : 0) + drag, 0), travel)
            let progress = travel > 0 ? offset / travel : 0

            ZStack(alignment: .topLeading) {
                RColor.backgroundUnderlay
                    .ignoresSafeArea()

                drawer(insets.bottom > 0)
                    .frame(width: travel)
                    .frame(maxHeight: .infinity)
                    .ignoresSafeArea(.keyboard)
                    .opacity(reduceMotion ? progress : 1)
                    .allowsHitTesting(isOpen)
                    .accessibilityHidden(!isOpen)

                journalLayer(insets: insets, progress: progress)
                    .offset(x: reduceMotion ? (isOpen ? travel : 0) : offset)
                    .overlay(alignment: .leading) { gestureStrip(travel: travel, offset: offset) }
            }
            .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.sheet, value: isOpen)
            // VoiceOver's two-finger scrub closes the drawer
            .accessibilityAction(.escape) { isOpen = false }
        }
    }

    /// The journal, drawn as a card while it is pushed: a canvas card with the overlay shadow
    /// behind it, and the page masked to the card's corners (the card runs under the status bar
    /// and the home indicator, as Paper draws it).
    private func journalLayer(insets: EdgeInsets, progress: CGFloat) -> some View {
        let radius = RDimension.radiusSheet * progress
        let card = RShape.rect(radius)
        return journal()
            .allowsHitTesting(!isOpen)
            .accessibilityHidden(isOpen)
            .mask {
                card.padding(.top, -insets.top).padding(.bottom, -insets.bottom)
            }
            .background {
                card.fill(RColor.backgroundCanvas)
                    .overlay(card.stroke(RColor.depthStrokeOuter, lineWidth: 0.5))
                    .shadow(color: RColor.shadowOverlay2.opacity(progress), radius: 6, y: 4)
                    .shadow(color: RColor.shadowOverlay1.opacity(progress), radius: 18, y: 24)
                    .padding(.top, -insets.top)
                    .padding(.bottom, -insets.bottom)
                    .opacity(progress > 0 ? 1 : 0)
            }
    }

    /// Closed: a thin strip on the leading edge takes the swipe that opens the drawer. Open: the
    /// journal's visible edge takes the tap or swipe that closes it, and is VoiceOver's way back.
    @ViewBuilder
    private func gestureStrip(travel: CGFloat, offset: CGFloat) -> some View {
        if isOpen {
            Color.clear
                .frame(width: Self.journalEdge)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .offset(x: offset)
                .onTapGesture { isOpen = false }
                .gesture(swipe(travel: travel))
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel("back to the journal")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { isOpen = false }
                .accessibilityIdentifier("drawer.close")
        } else {
            Color.clear
                .frame(width: Self.edgeSwipeWidth)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(swipe(travel: travel))
                .accessibilityHidden(true)
        }
    }

    private func swipe(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: RDimension.space2, coordinateSpace: .global)
            .updating($drag) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let moved = value.predictedEndTranslation.width
                // past a third of the way, it goes; otherwise it springs back
                if isOpen, moved < -travel / 3 {
                    isOpen = false
                } else if !isOpen, moved > travel / 3 {
                    isOpen = true
                }
            }
    }
}
