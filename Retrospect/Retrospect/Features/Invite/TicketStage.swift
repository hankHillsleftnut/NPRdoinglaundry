//
//  TicketStage.swift
//  PI2.1–PI2.3: the one ticket the whole moment happens on. It prints out of the slot (a rise
//  clipped above the lip, tilted about the lip and easing flat), is torn along the perforation
//  (the torn length of the stub droops behind the finger, the holes passed fall away), and then
//  the stub drops clear: 72 below the body at -14.8 degrees, kept. One instance throughout, driven
//  by values, never swapped for another view. The handle's gesture lives outside the tilt.
//
import SwiftUI

/// What the stub is doing.
enum TicketStubState: Equatable {
    /// Whole: joined to the body (the tear may be under way).
    case joined
    /// Torn: fallen clear and kept.
    case fallen
}

struct TicketStage: View {
    let geometry: TicketGeometry
    var face: Session.TicketFace?
    var tiles: String
    var date: String
    var label: RTicketStubLabel = .admitsOne
    var typed = false
    var caretOn = true
    /// 0...1 along the perforation; the tear point is `tearProgress` of the width.
    var tearProgress: CGFloat = 0
    var stub: TicketStubState = .joined
    /// 0 = still inside the printer, 1 = printed.
    var printProgress: CGFloat = 1
    /// Reduce Motion: no tilt, no rise.
    var reduceMotion = false

    /// How far below the body the stub lands, and at what angle (board `2II6-0`, T4).
    static func dropGap(compact: Bool) -> CGFloat { compact ? 56 : 72 } // literal-ok: board T4 gap 72, SE 56
    static let fallenAngle: Double = -14.8 // literal-ok: board T4 `2II7-0`
    static let printTilt: Double = -14 // literal-ok: build note, rotation3DEffect -14 about the slot
    static let perspective: CGFloat = 0.6 // literal-ok: build note

    /// The stage's layout height: the whole ticket, or the body with the fallen stub under it.
    var height: CGFloat {
        switch stub {
        case .joined: geometry.height
        case .fallen: geometry.perforationY + Self.dropGap(compact: geometry.compact) + geometry.stubHeight
        }
    }

    private var tearX: CGFloat {
        tearProgress * geometry.width
    }

    private var hidden: Int {
        stub == .fallen ? TearMath.holeCount : TearMath.hiddenHoles(progress: tearProgress)
    }

    var body: some View {
        let rise = reduceMotion ? 0 : (1 - printProgress) * geometry.height
        ticket
            .offset(y: rise)
            .frame(width: geometry.width, height: height, alignment: .top)
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Self.printTilt * Double(1 - printProgress)),
                axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: Self.perspective
            )
            .opacity(reduceMotion ? Double(printProgress) : 1)
            .mask(alignment: .top) {
                // the paper is only ever visible above the lip; once printed nothing clips it
                Rectangle()
                    .padding(.horizontal, -RDimension.space10)
                    .padding(.top, -RDimension.space16)
                    .padding(.bottom, printProgress >= 1 ? -RDimension.space16 : RDimension.space0) // literal-ok: a fully printed ticket is unclipped
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier(stub == .fallen ? "ticket.torn" : "ticket.whole")
    }

    private var ticket: some View {
        let joined = stub == .joined
        return ZStack(alignment: .topLeading) {
            stubLayers
            RTicketBody(geometry: geometry, face: face, hiddenHoles: hidden)
                .offset(y: stub == .fallen ? -2 : 0) // the body settles back 2pt
                .rTicketShadow(enabled: !joined)
        }
        .compositingGroup()
        .rTicketShadow(enabled: joined)
    }

    @ViewBuilder private var stubLayers: some View {
        let piece = RTicketStubPiece(
            geometry: geometry, tiles: tiles, date: date, label: label, typed: typed, caretOn: caretOn, hiddenHoles: hidden
        )
        switch stub {
        case .joined:
            ZStack(alignment: .topLeading) {
                // the torn length hangs from the tear point; the rest is still attached
                piece
                    .mask(alignment: .leading) { Rectangle().frame(width: max(tearX, .zero)) }
                    .rotationEffect(
                        .degrees(-TearMath.droop(progress: tearProgress)),
                        anchor: UnitPoint(x: tearProgress, y: geometry.perforationY / geometry.height)
                    )
                    .shadow(color: RColor.depthShadowCast.opacity(tearProgress), radius: 3, y: 3) // literal-ok: soft shadow under the torn edge
                piece
                    .mask(alignment: .trailing) { Rectangle().frame(width: max(geometry.width - tearX, .zero)) }
            }
        case .fallen:
            piece
                .rotationEffect(.degrees(Self.fallenAngle), anchor: UnitPoint(x: 0.5, y: (geometry.perforationY + geometry.height) / 2 / geometry.height))
                .offset(y: Self.dropGap(compact: geometry.compact))
                .rTicketShadow(enabled: true)
        }
    }

    private var accessibilityLabel: String {
        let from = face?.from.map { "invitation from \($0)" } ?? "invitation"
        return "\(from), admits one, code \(TicketCode.spelled(tiles))"
    }
}
