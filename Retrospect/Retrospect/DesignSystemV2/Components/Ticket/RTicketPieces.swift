//
//  RTicketPieces.swift
//  C41.2–C41.5: the ticket's two halves, each drawn in the ticket's full frame so they can be
//  moved apart without re-laying anything out. The body is the gift band and the words; the stub
//  is "admits one", the 13 code tiles and the date. Both carry the perforation's holes, so a torn
//  half keeps its half-bites. Values: board `2HXP-0` (anatomy), read 21 Oct.
//
import SwiftUI

extension RTextStyle {
    /// The ticket's title (board `2HXS-0`): ink at 28, card weight, title tracking, tight leading.
    static let ticketTitle = RTextStyle(
        family: .inky(axis: -10), size: RDimension.fontSize2xl, weight: .regular,
        tracking: RNumber.fontTrackingTitle, leading: 1.1, relativeTo: .title
    )
    /// The page titles on the invite pages (30, card weight).
    static let inviteTitle = RTextStyle(
        family: .inky(axis: -10), size: RDimension.fontSize3xl, weight: .regular,
        tracking: RNumber.fontTrackingTitle, leading: 1.1, relativeTo: .largeTitle
    )
    /// The ticket's small print: Geist 11.
    static let ticketSmall = RTextStyle(
        family: .label, size: RDimension.fontSizeXs, weight: .regular,
        tracking: RNumber.fontTrackingLabel, leading: 1.3, relativeTo: .caption2
    )
    static let ticketSmallMedium = RTextStyle(
        family: .label, size: RDimension.fontSizeXs, weight: .medium,
        tracking: RNumber.fontTrackingLabel, leading: 1.3, relativeTo: .caption2
    )
    /// A printed figure: mono 11 (serial, date).
    static let ticketFigure = RTextStyle(
        family: .mono, size: RDimension.fontSizeXs, weight: .regular,
        tracking: RNumber.fontTrackingNone, leading: 1.3, relativeTo: .caption2
    )
    /// A code tile: mono 14.
    static let ticketTile = RTextStyle(
        family: .mono, size: RDimension.fontSizeMd, weight: .regular,
        tracking: RNumber.fontTrackingNone, leading: 1.3, relativeTo: .subheadline
    )
}

/// How a ticket's date and serial read on its face.
enum TicketText {
    static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    /// `2026-10-19` as "19 oct 2026"; anything else as given.
    static func date(_ iso: String?) -> String {
        guard let iso else { return "" }
        let parts = iso.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1 ... 12).contains(month)
        else { return iso }
        return "\(day) \(months[month - 1]) \(year)"
    }

    /// `412` as "no. 0412".
    static func serial(_ number: Int?) -> String {
        guard let number else { return "" }
        let digits = String(number)
        return "no. " + String(repeating: "0", count: max(0, 4 - digits.count)) + digits
    }

    static func from(_ face: Session.TicketFace?) -> String {
        guard let name = face?.from, !name.isEmpty else { return "an invitation" }
        return "an invitation · from \(name)"
    }
}

/// What the stub's top line says.
enum RTicketStubLabel: Equatable {
    case admitsOne, used, expired

    var words: String {
        switch self {
        case .admitsOne: "admits one"
        case .used: "already used"
        case .expired: "expired"
        }
    }
}

// MARK: - Holes

/// The perforation's 21 holes, space-between with 20 of padding. Holes the tear has passed are
/// gone; each half keeps the half of the others that falls inside its own shape.
struct RTicketHoles: View {
    var hidden = 0
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: RDimension.space0) {
            ForEach(0 ..< TearMath.holeCount, id: \.self) { index in
                if index > 0 {
                    Spacer(minLength: 0)
                }
                Circle()
                    .fill(RColor.backgroundSunken)
                    .overlay(Circle().strokeBorder(
                        contrast == .increased ? RColor.borderControl : RColor.depthStrokeOuter,
                        lineWidth: contrast == .increased ? RDimension.sizeBorderDefault : RDimension.sizeBorderHairline
                    ))
                    .frame(width: RDimension.sizeStepDot, height: RDimension.sizeStepDot)
                    .opacity(index < hidden ? 0 : 1)
            }
        }
        .padding(.horizontal, RDimension.space5)
        .frame(height: TicketGeometry.holeRowHeight)
        .accessibilityHidden(true)
    }
}

// MARK: - Tiles

/// The 13 code tiles in groups of 4 · 4 · 4 · 1 (board `2HYN-0`): 20 × 28, `surface.control`, the
/// sunken shade, mono 14. Printed codes don't scale with Dynamic Type. In typed mode the next
/// empty tile carries the caret and the tiles not yet reached sit back.
struct RTicketTiles: View {
    var tiles: String
    var typed = false
    var caretOn = true
    var dimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private static let tileWidth = RDimension.space5
    private static let tileHeight = RDimension.fontSize2xl

    var body: some View {
        HStack(spacing: RDimension.space0) {
            ForEach(0 ..< 4, id: \.self) { group in
                if group > 0 {
                    Spacer(minLength: RDimension.space2)
                }
                HStack(spacing: 3) { // literal-ok: board 2HYN-0, tiles 3 apart inside a group
                    ForEach(groupRange(group), id: \.self) { index in
                        tile(index)
                    }
                }
            }
        }
        .opacity(dimmed ? RNumber.opacityDisabled : 1)
        .dynamicTypeSize(.large)
    }

    private func groupRange(_ group: Int) -> Range<Int> {
        let start = group * 4
        return start ..< min(start + 4, TicketCode.length)
    }

    private func tile(_ index: Int) -> some View {
        let characters = Array(tiles)
        let filled = index < characters.count
        let isCaret = typed && index == characters.count
        return ZStack {
            Text(filled ? String(characters[index]) : "")
                .rText(.ticketTile)
                .foregroundStyle(RColor.textPrimary)
                .transition(.blurReplace)
        }
        .frame(width: Self.tileWidth, height: Self.tileHeight)
        .rSunken(RDimension.radiusSmall)
        .overlay {
            if contrast == .increased {
                RShape.rect(RDimension.radiusSmall).strokeBorder(RColor.borderControl, lineWidth: RDimension.sizeBorderDefault)
            }
        }
        .overlay {
            if isCaret {
                RShape.rect(RDimension.radiusSmall)
                    .strokeBorder(RColor.textPrimary, lineWidth: RDimension.sizeBorderRing - RDimension.sizeBorderHairline) // literal-ok: 1.5 ring
                    .padding(-RDimension.sizeBorderDefault)
                    .opacity(caretOn || reduceMotion ? 1 : 0)
            }
        }
        .opacity(typed && index > characters.count ? 0.6 : 1) // literal-ok: board 2IT1-0, tiles not yet reached
        .animation(RMotion.standard(RNumber.motionDurationFast), value: filled)
    }
}

// MARK: - Body

/// The gift band and the words, in the ticket's full frame, clipped to the body's cut.
struct RTicketBody: View {
    let geometry: TicketGeometry
    var face: Session.TicketFace?
    var hiddenHoles = 0
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RTicketShape(part: .body, geometry: geometry)
        ZStack(alignment: .topLeading) {
            VStack(spacing: RDimension.space0) {
                RArtwork(recipe: RArtworkRecipes.gift(dark: scheme == .dark), width: geometry.width, height: geometry.meshHeight, cornerRadius: 0)
                faceText
            }
            RTicketHoles(hidden: hiddenHoles)
                .offset(y: geometry.perforationY - TicketGeometry.holeRowHeight / 2)
        }
        .frame(width: geometry.width, height: geometry.height, alignment: .topLeading)
        .clipShape(shape)
        .rTicketSurface(shape, shadowed: false)
    }

    private var faceText: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            HStack(alignment: .firstTextBaseline) {
                Text(TicketText.from(face)).rText(.labelMedium).foregroundStyle(RColor.textLabel)
                Spacer(minLength: RDimension.space2)
                Text(TicketText.serial(face?.serial)).rText(.ticketFigure).foregroundStyle(RColor.textTertiary)
            }
            Text("a place in retrospect, kept for you.")
                .rText(.ticketTitle)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.8) // literal-ok: the printed face is fixed in height
                .fixedSize(horizontal: false, vertical: true)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.top, RDimension.space5)
        .padding(.horizontal, RDimension.space5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentTransition(.interpolate)
        .animation(RMotion.standard(RNumber.motionDurationBase), value: face)
    }
}

// MARK: - Stub

struct RTicketStubPiece: View {
    let geometry: TicketGeometry
    var tiles: String
    var date: String
    var label: RTicketStubLabel = .admitsOne
    var typed = false
    var caretOn = true
    var hiddenHoles = 0

    var body: some View {
        let shape = RTicketShape(part: .stub, geometry: geometry)
        ZStack(alignment: .topLeading) {
            RTicketHoles(hidden: hiddenHoles)
                .offset(y: geometry.perforationY - TicketGeometry.holeRowHeight / 2)
            VStack(spacing: RDimension.space3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label.words).rText(.labelMedium).foregroundStyle(RColor.textPrimary)
                        .transition(.blurReplace)
                    Spacer(minLength: RDimension.space2)
                    Text("one use · yours alone").rText(.ticketSmall).foregroundStyle(RColor.textLabel)
                }
                RTicketTiles(tiles: tiles, typed: typed, caretOn: caretOn, dimmed: label != .admitsOne)
                HStack(alignment: .firstTextBaseline) {
                    Text(date).rText(.ticketFigure).foregroundStyle(RColor.textTertiary)
                    Spacer(minLength: RDimension.space2)
                    Text("retrospect").rText(.ticketSmallMedium).foregroundStyle(RColor.textLabel)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.top, RDimension.space3)
            .padding(.horizontal, RDimension.space5)
            .padding(.bottom, RDimension.space5)
            .frame(width: geometry.width, alignment: .top)
            .offset(y: geometry.perforationY + TicketGeometry.holeRowHeight / 2)
            .animation(RMotion.standard(RNumber.motionDurationBase), value: label)
        }
        .frame(width: geometry.width, height: geometry.height, alignment: .topLeading)
        .clipShape(shape)
        .rTicketSurface(shape, shadowed: false)
    }
}

// MARK: - Handle

/// The tear handle (board `2I67-0`): a 32 raised disc with a chevron, in a 44 hit area, sitting on
/// the left notch. Held, it lifts. It is never lit: "begin" is the one lit object.
struct RTicketHandle: View {
    var held = false

    var body: some View {
        Circle()
            .fill(RColor.backgroundRaised)
            .overlay(Circle().stroke(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
            .overlay(alignment: .top) {
                Circle().stroke(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderRing)
                    .clipShape(Circle())
                    .mask(alignment: .top) { Rectangle().frame(height: RDimension.sizeBorderDefault) }
            }
            .overlay(RSymbol(name: "chevron.right", size: .small, tint: RColor.iconDefault, weight: .semibold))
            .frame(width: RDimension.sizeControlSmall, height: RDimension.sizeControlSmall)
            .shadow(color: RColor.depthShadowContact, radius: held ? 1 : 0.75, y: held ? 2 : 1) // literal-ok: board 2IDJ-0 lifted
            .shadow(color: RColor.depthShadowCast, radius: held ? 9 : 5, y: held ? 8 : 4) // literal-ok: board 2I67-0, 2IDJ-0
            .frame(width: RDimension.sizeTouchTarget, height: RDimension.sizeTouchTarget)
            .contentShape(Rectangle())
            .accessibilityIdentifier("ticket.handle")
    }
}
