//
//  BriefWidgets.swift
//  V2.outside · EX-4 the home-screen widgets (Paper 1H4D-0: c:widget/164x164 1H55-0, c:widget/344x164
//  1H4L-0). The views only: the widget extension (target, App Group, timeline) is founder paperwork
//  (EX-D9); these views take their words as values so a target can show them as they are. Both: padding
//  16, the 16 mark top-left. Small: "tell me…" in the inky face over "talk to retro". Medium: the mark
//  and "today's brief · 4 min" (Geist Mono 11), the brief's line in the inky face, then "play" and "talk".
//  The surface (background.raised, radius.widget) is the system's container in a target; the preview
//  page draws it. Taps open the app (journey map rows 96p/96q): the views carry where to as a value
//  (`WidgetDestination`) for the target's links; nothing in them is a button.
//
import SwiftUI

extension RTextStyle {
    /// The widgets' words: the inky card face at text-lg (1H57-0, 1H4T-0).
    static let widgetLine = RTextStyle(
        family: .inky(axis: -10),
        size: RDimension.fontSizeLg,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 1.1,
        relativeTo: .title3
    )
}

/// Where a widget tap lands in the app (journey map 96p / 96q). Wired by the target and a wiring PR.
enum WidgetDestination: Equatable {
    /// "tell me…" and "talk": the journal with the composer listening (JR-1).
    case talk
    /// "play": today's brief (JR-2).
    case playBrief
}

/// c:widget/164x164: "tell me…".
struct BriefWidgetSmall: View {
    static let destination = WidgetDestination.talk

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space0) {
            RMark.widget
            Spacer(minLength: RDimension.space0)
            Text("tell me…")
                .rText(.widgetLine)
                .foregroundStyle(RColor.textPrimary)
            Text("talk to retro")
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(RDimension.layoutWidgetPadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("retrospect, tell me…, talk to retro")
    }
}

/// c:widget/344x164: today's brief, with "play" and "talk".
struct BriefWidgetMedium: View {
    let brief: WidgetBrief
    static let destinations: [WidgetDestination] = [.playBrief, .talk]

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space0) {
            HStack(spacing: RDimension.space2) {
                RMark.widget
                Text(brief.label)
                    .rText(.figure)
                    .foregroundStyle(RColor.textLabel)
                    .lineLimit(1)
            }
            Text(brief.line)
                .rText(.widgetLine)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(2)
                .padding(.top, RDimension.space2)
            Spacer(minLength: RDimension.space0)
            // Paper writes "▶ play" with a text glyph; the design system draws glyphs as symbols (EX-D12)
            HStack(spacing: RDimension.space2) {
                OutsidePillLabel(title: "play", symbol: "play.fill")
                OutsidePillLabel(title: "talk")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(RDimension.layoutWidgetPadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("retrospect, \(brief.label.replacingOccurrences(of: " · ", with: ", ")), \(brief.line), play or talk")
    }
}

/// The surface a target's container gives a widget, for the preview: background.raised, radius.widget,
/// the 0.5 outer line and the soft cast Paper draws on the home screen.
struct WidgetPreviewSurface: ViewModifier {
    let width: CGFloat
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: width, height: height)
            .background(RColor.backgroundRaised, in: RShape.rect(RDimension.radiusWidget))
            .overlay(RShape.rect(RDimension.radiusWidget).stroke(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
            .shadow(color: RColor.depthShadowCast, radius: 12, y: 8) // literal-ok: Paper 1H55-0 cast 0 8 24 -8 (preview only)
    }
}

/// The launcher's look at both widgets at their system sizes on the page colour (EX-4 `rest`). Paper's
/// home-screen icons around them are the system's, so they aren't drawn.
struct WidgetsPreviewPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space6) {
            BriefWidgetSmall()
                .modifier(WidgetPreviewSurface(width: RDimension.sizeWidgetSmall, height: RDimension.sizeWidgetSmall))
            BriefWidgetMedium(brief: SampleWidgets.brief)
                .modifier(WidgetPreviewSurface(width: RDimension.sizeWidgetMediumWidth, height: RDimension.sizeWidgetSmall))
        }
        .padding(.horizontal, RDimension.spaceScreenMargin)
        .padding(.top, RDimension.space6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RColor.backgroundCanvas.ignoresSafeArea())
        .accessibilityIdentifier("widgets")
    }
}
