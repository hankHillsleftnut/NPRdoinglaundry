//
//  RParts1.swift
//  M14 sub-components, group 1 (S01, S02, S03, S11, S15): the icon well, hairlines,
//  the source status dot and the SF Symbol wrapper. Values from the approved ON-6
//  and ST-3 boards (c:settings-row/source, c:hairline/inset-icon); tokens only.
//
import SwiftUI

// MARK: - S15 · SF Symbol wrapper

/// Icon sizes from size.icon.*.
enum RIconSize {
    case small, regular, large

    var points: CGFloat {
        switch self {
        case .small: RDimension.sizeIconSmall
        case .regular: RDimension.sizeIconDefault
        case .large: RDimension.sizeIconLarge
        }
    }
}

/// An SF Symbol at a token size and tint (founder, 21 Oct: Apple's SF Symbols for every icon).
struct RSymbol: View {
    let name: String
    var size: RIconSize = .regular
    var tint: Color = RColor.iconDefault
    var weight: Font.Weight = .regular
    /// Glyph point size as a share of the frame. Some symbols draw larger than Paper's inked
    /// set at the same frame (↗ needs 0.66 to match its 8.5pt mark), so they set their own.
    var glyphScale: CGFloat = 0.82 // literal-ok: SF Symbol point size maps to its frame

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size.points * glyphScale, weight: weight)) // literal-ok: an SF Symbol sized to its frame, not text
            .foregroundStyle(tint)
            .frame(width: size.points, height: size.points)
            .accessibilityHidden(true)
    }
}

// MARK: - S01 · Icon well

/// A 32pt wash square with a 20pt symbol (source rows, settings rows).
struct RIconWell: View {
    let symbol: String
    var tint: Color = RColor.iconDefault
    /// surface.wash, or status.dangerSubtle for a danger row (part 26).
    var fill: Color = RColor.surfaceWash
    /// The glyph's share of its 20 frame (RSymbol). Some boards draw it at 18 (evidence rows).
    var glyphScale: CGFloat = 0.82 // literal-ok: RSymbol's default glyph scale

    var body: some View {
        RSymbol(name: symbol, tint: tint, glyphScale: glyphScale)
            .frame(width: RDimension.sizeSourceIcon, height: RDimension.sizeSourceIcon)
            .background(fill, in: RShape.rect(RDimension.radiusDefault))
    }
}

// MARK: - S02 / S03 · Hairlines

/// A hairline divider: full width, or inset to start after a row's icon well.
struct RHairline: View {
    enum Inset { case full, afterIcon }
    var inset: Inset = .full
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        // Increase Contrast: a 1pt border.control line (part 22)
        (contrast == .increased ? RColor.borderControl : RColor.borderStrong)
            .frame(height: contrast == .increased ? RDimension.sizeBorderDefault : RDimension.sizeBorderHairline)
            .padding(.leading, inset == .afterIcon ? RDimension.sizeSourceIcon + RDimension.space3 : .zero)
            .accessibilityHidden(true)
    }
}

// MARK: - S11 · Source status

/// connected / problem / syncing / unavailable, as a dot (or spinner) plus its word.
enum RSourceStatus: Equatable {
    case connected, problem, syncing, unavailable

    var label: String {
        switch self {
        case .connected: "connected"
        case .problem: "reconnect"
        case .syncing: "syncing"
        case .unavailable: "unavailable"
        }
    }

    var color: Color {
        switch self {
        case .connected: RColor.sourceConnected
        case .problem: RColor.sourceProblem
        case .syncing: RColor.sourceSyncing
        case .unavailable: RColor.sourceUnavailable
        }
    }
}

struct RStatusDot: View {
    let status: RSourceStatus

    var body: some View {
        HStack(spacing: RDimension.space2) {
            if status == .syncing {
                RSpinner().accessibilityHidden(true)
            } else {
                Circle()
                    .fill(status.color)
                    .frame(width: RDimension.sizeStepDot, height: RDimension.sizeStepDot)
            }
            Text(status.label)
                .rText(.textMd)
                .foregroundStyle(RColor.textSecondary)
                .contentTransition(.interpolate)
        }
        .animation(RMotion.standard(RNumber.motionDurationFast), value: status)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
struct RParts1Gallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space4) {
            HStack(spacing: RDimension.space3) {
                RIconWell(symbol: "calendar")
                RIconWell(symbol: "heart")
                RIconWell(symbol: "music.note")
                RIconWell(symbol: "envelope")
                RIconWell(symbol: "doc.text")
            }
            RHairline(inset: .afterIcon)
            RHairline()
            VStack(alignment: .leading, spacing: RDimension.space3) {
                RStatusDot(status: .connected)
                RStatusDot(status: .problem)
                RStatusDot(status: .syncing)
                RStatusDot(status: .unavailable)
            }
        }
        .padding(RDimension.spaceScreenMargin)
    }
}

#Preview("parts 1") { RParts1Gallery() }
#endif
