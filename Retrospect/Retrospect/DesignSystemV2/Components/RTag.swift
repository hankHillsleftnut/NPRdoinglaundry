//
//  RTag.swift
//  M14 C06: the tag (tag.md; Paper c · player sheet, "label · today"). A short word that
//  describes something and does nothing: never tappable, never a shadow or stroke of its own
//  (it is part of the surface it sits on). 20 tall, a true pill, padding 7, Geist 11.
//  status: accent.subtle fill, accent.text. guess: no fill, a 1pt dashed inference.border edge
//  and a 6pt inference.marker dot beside the words, so a guess never looks like a fact
//  without relying on colour (goal 11).
//
import SwiftUI

extension RTextStyle {
    /// Tag words (Paper label · today: --font-label, 11, regular, 14 line).
    static let tag = RTextStyle(
        family: .label,
        size: RDimension.fontSizeXs,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 14 / 11, // literal-ok: Paper's 14pt line on 11pt words
        relativeTo: .caption2
    )
}

struct RTag: View {
    enum Style { case status, guess }

    let text: String
    var style: Style = .status
    @ScaledMetric(relativeTo: .caption2) private var height = RDimension.sizeBadge

    var body: some View {
        // the dot and its gap are both 6 (Paper guess tag)
        HStack(spacing: RDimension.sizeStepDot) {
            if style == .guess {
                Circle()
                    .fill(RColor.inferenceMarker)
                    .frame(width: RDimension.sizeStepDot, height: RDimension.sizeStepDot)
            }
            Text(text)
                .rText(.tag)
                .foregroundStyle(style == .status ? RColor.accentText : RColor.textLabel)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, style == .guess ? RDimension.sizeStepDot : RDimension.sizeTagPadding)
        .padding(.trailing, RDimension.sizeTagPadding)
        .frame(minHeight: height)
        .background { RTagBody(style: style) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

private struct RTagBody: View {
    let style: RTag.Style

    var body: some View {
        switch style {
        case .status:
            RShape.pill.fill(RColor.accentSubtle)
        case .guess:
            GeometryReader { proxy in
                // the dash sits inside the shape, so the tag is the same size either way (craft 3.4)
                RShape.pill.strokeBorder(
                    RColor.inferenceBorder,
                    style: StrokeStyle(lineWidth: RDimension.sizeBorderDefault, dash: [RInferenceEdge.dash(around: proxy.size, cornerRadius: .infinity)])
                )
            }
        }
    }
}

/// A guess's dashed edge, shared by RTag and RGuessCard.
enum RInferenceEdge {
    /// The nearest dash to size.inference.dash that fits a whole number of dash-gap pairs around
    /// a rounded rectangle (a capsule when the radius is half the height), so the pattern closes
    /// without a stub where it starts. strokeBorder draws on a path inset by half the line.
    static func dash(around size: CGSize, cornerRadius: CGFloat, line: CGFloat = RDimension.sizeBorderDefault) -> CGFloat {
        let width = size.width - line
        let height = size.height - line
        let radius = min(cornerRadius, min(width, height) / 2)
        let perimeter = 2 * (width + height) - 2 * radius * (4 - .pi)
        let pairs = max(1, (perimeter / (2 * RDimension.sizeInferenceDash)).rounded())
        return perimeter / (2 * pairs)
    }
}

#if DEBUG
struct RTagGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space4) {
            Text("tag").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
            HStack(spacing: RDimension.space3) {
                RTag(text: "today")
                RTag(text: "new")
                RTag(text: "playing")
            }
            HStack(spacing: RDimension.space3) {
                RTag(text: "a guess", style: .guess)
            }
            HStack(alignment: .firstTextBaseline, spacing: RDimension.space2) {
                Text("the week you kept choosing the river")
                    .rText(.textMd)
                    .foregroundStyle(RColor.textPrimary)
                    .layoutPriority(1)
                RTag(text: "today")
            }
        }
        .padding(RDimension.spaceScreenMargin)
    }
}

#Preview("tag") { RTagGallery() }
#endif
