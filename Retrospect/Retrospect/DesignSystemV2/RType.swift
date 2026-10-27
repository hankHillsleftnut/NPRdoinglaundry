//
//  RType.swift
//  The type roles used in the approved Paper screens (design-system/tokens: --font-*, --text-*,
//  --tracking-*, --leading-*). Hand-built because type composites don't generate cleanly:
//  every size, tracking and leading value comes from RDimension / the token table below.
//
import SwiftUI

/// Font families, by their token names. PostScript names were read from the font files.
enum RFamily {
    /// --font-display: Hedvig Letters Serif.
    static let display = "HedvigLettersSerif-24ptRegular"
    /// --font-label: Geist.
    static func label(_ weight: Font.Weight) -> String {
        switch weight {
        case .medium: return "Geist-Medium"
        case .semibold, .bold: return "Geist-SemiBold"
        default: return "Geist-Regular"
        }
    }
}

/// One text role: family, size, tracking (em) and leading (multiple of size), as in Paper.
struct RTextStyle {
    enum Family { case inky(axis: Int), display, text, label, mono }

    let family: Family
    let size: CGFloat
    let weight: Font.Weight
    let tracking: CGFloat // em
    let leading: CGFloat // line height ÷ size
    let relativeTo: Font.TextStyle

    var font: Font {
        font(scaledSize: size)
    }

    /// The font at a size already scaled for Dynamic Type. Custom families scale themselves through
    /// `relativeTo`; the system families take the scaled size directly, since `.system(size:)` is fixed.
    func font(scaledSize: CGFloat) -> Font {
        switch family {
        case let .inky(axis):
            // --font-weight-ink-title / -ink-card select an Exposure axis, not a weight
            return .custom(ExposureFont.postScriptName(axis: axis, italic: false), size: size, relativeTo: relativeTo)
        case .display:
            return .custom(RFamily.display, size: size, relativeTo: relativeTo)
        case .label:
            return .custom(RFamily.label(weight), size: size, relativeTo: relativeTo)
        case .text:
            return .system(size: scaledSize, weight: weight)
        case .mono:
            return .system(size: scaledSize, weight: weight, design: .monospaced).monospacedDigit()
        }
    }

    /// The font's own line height at a scaled size, the box SwiftUI gives one line before any spacing.
    /// Measured once per family, weight and size, never on every body pass.
    func naturalLineHeight(scaledSize: CGFloat) -> CGFloat {
        let name: String? = switch family {
        case let .inky(axis): ExposureFont.postScriptName(axis: axis, italic: false)
        case .display: RFamily.display
        case .label: RFamily.label(weight)
        case .text, .mono: nil
        }
        let key = "\(name ?? (isMono ? "mono" : "text"))|\(weight.uiWeight.rawValue)|\(scaledSize)" as NSString
        if let cached = RLineHeightCache.shared.object(forKey: key) {
            return CGFloat(cached.doubleValue)
        }
        let uiFont = name.flatMap { UIFont(name: $0, size: scaledSize) }
            ?? (isMono
                ? UIFont.monospacedSystemFont(ofSize: scaledSize, weight: weight.uiWeight)
                : UIFont.systemFont(ofSize: scaledSize, weight: weight.uiWeight))
        RLineHeightCache.shared.setObject(NSNumber(value: Double(uiFont.lineHeight)), forKey: key)
        return uiFont.lineHeight
    }

    /// The ink faces whose Paper leading is tighter than the font's own line box (Exposure's is
    /// 1.2 × size, so --leading-tight 1.1): their lines are drawn at Paper's pitch (`RPaperPitch`).
    /// At the style's own leading; the modifier asks with the leading it applies at the size.
    var drawsAtPaperPitch: Bool {
        drawsAtPaperPitch(leading: leading, scaledSize: size)
    }

    /// The same question with the leading actually applied at a size (accessibility sizes cap it
    /// with `accessibilityLeading`, which can bring a looser ink style under the font's box).
    func drawsAtPaperPitch(leading applied: CGFloat, scaledSize: CGFloat) -> Bool {
        guard case .inky = family else { return false }
        return applied * scaledSize < naturalLineHeight(scaledSize: scaledSize)
    }

    private var isMono: Bool {
        if case .mono = family {
            return true
        }
        return false
    }

    /// Line height ÷ size at accessibility sizes, from the type.ax3 tokens (title 61/52, xl 52/44,
    /// body 48/40, md 43/36, sm 39/32): Paper sets about 1.2× there, not the default leading, so
    /// AX3 rows don't grow about 4pt a line beyond what Paper draws.
    var accessibilityLeading: CGFloat {
        switch relativeTo {
        case .largeTitle, .title: 61 / 52
        case .title2, .title3: 52 / 44
        case .subheadline, .footnote: 43 / 36
        case .caption, .caption2: 39 / 32
        default: 48 / 40
        }
    }

    /// `size` scaled the way iOS scales `relativeTo` at this Dynamic Type size.
    func scaledSize(at dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        return UIFontMetrics(forTextStyle: relativeTo.uiTextStyle).scaledValue(for: size, compatibleWith: traits)
    }
}

/// Measured line heights, keyed by family, weight and size (thread-safe).
private enum RLineHeightCache {
    static let shared = NSCache<NSString, NSNumber>()
}

private extension Font.Weight {
    var uiWeight: UIFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}

extension RTextStyle {
    /// Exposure axes: --font-weight-ink-title → exposure.title (−20), ink-card → exposure.card (−10)
    static let inkHero = RTextStyle(
        family: .inky(axis: -20),
        size: RDimension.fontSizeHero,
        weight: .regular,
        tracking: RNumber.fontTrackingHero,
        leading: 1.1,
        relativeTo: .largeTitle
    )
    /// Screen titles and the onboarding question (--text-3xl, ink title).
    static let inkTitle = RTextStyle(
        family: .inky(axis: -20),
        size: RDimension.fontSize3xl,
        weight: .regular,
        tracking: RNumber.fontTrackingTitle,
        leading: 1.1,
        relativeTo: .largeTitle
    )
    /// Card headlines and quotes (--text-xl, ink card).
    static let inkCard = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSizeXl,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: 1.1,
        relativeTo: .title2
    )
    /// Sheet titles ("sign out?") and section display lines (--font-display, --text-2xl).
    static let displayTitle = RTextStyle(
        family: .display,
        size: RDimension.fontSize2xl,
        weight: .regular,
        tracking: RNumber.fontTrackingTitle,
        leading: 1.1,
        relativeTo: .title
    )

    /// Reading text: messages, transcripts (--text-body, leading normal).
    static let bodyReading = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: 1.45,
        relativeTo: .body
    )
    /// Controls and row titles (--text-body, leading snug).
    static let body = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .body
    )
    static let bodyMedium = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .body
    )
    static let buttonLabel = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .semibold,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .body
    )
    /// Supporting lines (--text-md).
    static let textMd = RTextStyle(
        family: .text,
        size: RDimension.fontSizeMd,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .subheadline
    )
    static let textMdMedium = RTextStyle(
        family: .text,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .subheadline
    )

    /// Geist labels: metadata, section labels, pills (founder 20 Oct: Geist for labels, mono only for figures).
    static let label = RTextStyle(
        family: .label,
        size: RDimension.fontSizeSm,
        weight: .regular,
        tracking: RNumber.fontTrackingLabel,
        leading: 1.3,
        relativeTo: .caption
    )
    static let labelMedium = RTextStyle(
        family: .label,
        size: RDimension.fontSizeSm,
        weight: .medium,
        tracking: RNumber.fontTrackingLabel,
        leading: 1.3,
        relativeTo: .caption
    )
    /// One-line meta and status lines: the offline line, an evidence row's date and kind, an
    /// error message (Paper EOL-0, 1FZ1-0, 20R-0: Geist 12, leading snug, no tracking, unlike `.label`).
    static let metaLine = RTextStyle(
        family: .label,
        size: RDimension.fontSizeSm,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .caption
    )
    /// Pill labels (Paper c:pill: --font-label, --text-md, medium, --tracking-label, --leading-tight).
    static let pill = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingLabel,
        leading: 1.1,
        relativeTo: .subheadline
    )
    /// Row-action pills: connect, play, export (Paper c:pill/raised/action: --text-sm, medium, --leading-snug).
    static let pillAction = RTextStyle(
        family: .label,
        size: RDimension.fontSizeSm,
        weight: .medium,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .footnote
    )
    /// Tab bar labels (--text-xs, --tracking-label).
    static let tab = RTextStyle(
        family: .label,
        size: RDimension.fontSizeXs,
        weight: .regular,
        tracking: RNumber.fontTrackingLabel,
        leading: 1.3,
        relativeTo: .caption2
    )
    static let tabSelected = RTextStyle(
        family: .label,
        size: RDimension.fontSizeXs,
        weight: .medium,
        tracking: RNumber.fontTrackingLabel,
        leading: 1.3,
        relativeTo: .caption2
    )

    /// Figures only: times, counts, "1 of 3".
    static let figure = RTextStyle(
        family: .mono,
        size: RDimension.fontSizeXs,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 1.3,
        relativeTo: .caption2
    )
}

private struct RTextModifier: ViewModifier {
    let style: RTextStyle
    /// Only a bare `Text` draws at Paper's pitch: the line maths needs one text and nothing else.
    var paperPitch = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        // tracking and leading are proportions of the size, so they follow the scaled size too
        let size = style.scaledSize(at: dynamicTypeSize)
        // Paper's line box is leading × size; SwiftUI gives each line the font's own height. The
        // difference goes between lines and, as in CSS, half above and half below the text, so a
        // single line is as tall as Paper draws it too. Tighter leading than the font's own
        // height can't shrink a SwiftUI line with spacing, so the ink faces draw their lines at
        // Paper's pitch instead (`RPaperPitch`); every other face keeps the font's own height.
        let leading = dynamicTypeSize.isAccessibilitySize ? min(style.leading, style.accessibilityLeading) : style.leading
        let natural = style.naturalLineHeight(scaledSize: size)
        let extra = max(0, leading * size - natural)
        let styled = content
            .font(style.font(scaledSize: size))
            .tracking(style.tracking * size)
            .lineSpacing(extra)
            .padding(.vertical, extra / 2)
        if paperPitch, style.drawsAtPaperPitch(leading: leading, scaledSize: size) {
            let pitch = RPaperPitch(pitch: leading * size, naturalLineHeight: natural)
            RPaperPitchLayout(pitch: pitch) {
                styled.textRenderer(pitch)
            }
            // Paper's line box, as CSS sets it: half of the font's extra height trims above the
            // first line and below the last (founder 26 Oct, "fit the lines to Paper")
            .padding(.vertical, pitch.halfLeading)
        } else {
            styled
        }
    }
}

extension View {
    /// Applies one of the approved text roles.
    func rText(_ style: RTextStyle) -> some View { modifier(RTextModifier(style: style)) }
}

extension Text {
    /// Applies one of the approved text roles; on a bare `Text` an ink style also sets its lines
    /// Paper's pitch apart (`RPaperPitch`). Swift picks this over the `View` one for a `Text`.
    func rText(_ style: RTextStyle) -> some View { modifier(RTextModifier(style: style, paperPitch: true)) }
}
