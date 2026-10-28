//
//  PlayerSheet.swift
//  PS.sheet.a: the player sheet as Paper ON-11 draws it (26NO-0; the same sheet as PC-2 1FV9-0), built
//  from the player parts that exist: the header, the transcript (flexes and scrolls), "correct this
//  part", RScrubber and RTransport, with Paper's gaps (16, 20, 24). The scrubber names the chapter by
//  its title alone, as ON-11 does, over the grey downloaded stretch (founder Q4 = B). Founder answers,
//  26 Oct: "correct this part" is drawn as Paper draws it and does nothing yet (Q1 = C); "…" opens the
//  build note's menu, whose rows only close it for now (Q2 = B); share opens the system share sheet
//  (Q3 = B). The space under the transport is the caller's: it depends on the safe area
//  (`PlayerSheetScreen`) or on the host.
//  `PlayerSheetScreen` stands the sheet on the underlay for a screen that opens as a sheet (the tease);
//  inside the app the RSheetHost presents the same `PlayerSheet` (PS.sheet.c).
//
import SwiftUI

/// The "…" menu opens through the nearest `rMenuHost()` above the sheet, installed at screen level
/// (`PlayerSheetScreen` here; the page under RSheetHost in PS.sheet.c), never on the padded content.
struct PlayerSheet: View {
    let model: PlayerSheetModel
    /// How the scrubber names the chapter: ON-11's title alone by default; PC-2's episode mode passes
    /// `.counted` ("2 of 4 · the river", PCD-12) until RScrubber has Paper's "chapter 2 · the river".
    var partLabel: RScrubber.PartLabel = .title
    /// A tap on a transcript line (PC-2, SCREEN-MAP row 76: why this is here); nil keeps the lines
    /// plain text, as ON-11 draws them.
    var onTapLine: ((Int) -> Void)?

    var body: some View {
        VStack(spacing: RDimension.space0) {
            PlayerSheetHeader(title: model.title, shareText: model.shareText, onCollapse: model.collapse)
                .padding(.top, RDimension.space1)
            TranscriptColumn(transcript: model.transcript, current: model.currentLine, onTapLine: onTapLine)
                .frame(maxHeight: .infinity)
            CorrectThisPart()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, RDimension.space4)
            RScrubber(playback: model.playback, partLabel: partLabel)
                .padding(.top, RDimension.space5)
            RTransport(playback: model.playback, more: moreRows)
                .padding(.top, RDimension.space6)
        }
        .accessibilityAction(.escape) { model.collapse() }
    }

    /// The "…" rows (founder Q2 = B): drawn as the build note describes them; choosing one only closes
    /// the menu until chapters and downloads exist, and VoiceOver says so.
    private var moreRows: [RMenuRow] {
        PlayerSheetModel.MoreItem.allCases.map { item in
            RMenuRow(
                id: item.rawValue,
                title: item.title,
                symbol: item.symbol,
                opensMore: item.opensMore,
                accessibilityNote: PlayerSheetModel.notAvailableYet
            ) {}
        }
    }
}

/// "correct this part" (26OU-0 / 26OV-0) exactly as Paper draws it: a 36 wash pill, 16 inline, the
/// correct glyph (a speech bubble with a line, SF) and the words in Geist md medium. Founder Q1 = C: it
/// is cosmetic until the correction flow is drawn (G6), so it is a plain view, not a button: no press,
/// no dimming, no navigation, and VoiceOver hears that it isn't available yet.
struct CorrectThisPart: View {
    static let words = "correct this part"

    var body: some View {
        HStack(spacing: RDimension.space2) {
            RSymbol(name: "text.bubble", size: .small)
            Text(Self.words)
                .rText(.playerHeaderTitle)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, RDimension.space4)
        .frame(height: RDimension.sizeControlMedium)
        .background(RColor.surfaceWash, in: RShape.pill)
        // AX sizes: the pill keeps its size like the transport (its words never truncate)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.words)
        .accessibilityValue(PlayerSheetModel.notAvailableYet)
        .accessibilityIdentifier("player.correct")
    }
}

/// A sheet that is open from the start, standing on the underlay (26NO-0). The underlay and the sheet's
/// surface are backgrounds and may run under the status bar and the home indicator; everything on the
/// sheet stays inside the safe area (plan-screens §10). The surface starts where Paper draws it (48 from
/// the top) when the status bar is taller, right under a shorter one (SE); the transport keeps Paper's
/// 40 from the screen's bottom edge where the home indicator leaves room for it.
struct PlayerSheetScreen<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            RSheetPanel(surfaceRise: max(insets.top - RDimension.space12, RDimension.space0)) {
                content()
                    .padding(.bottom, max(RDimension.space10 - insets.bottom, RDimension.space0))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { RColor.backgroundUnderlay.ignoresSafeArea() }
        // the "…" menu's host sits at the screen, outside every padding, so its veil covers the
        // whole screen and a tap anywhere outside the menu closes it (QA 198 M1)
        .rMenuHost()
    }
}

#if DEBUG
#Preview("tease · as drawn") {
    PlayerSheetScreen {
        PlayerSheet(model: PlayerSheetModel(
            playback: SamplePlayback(scenario: .teaseStill, clock: ContinuousClock()),
            transcript: SampleTranscript.tease,
            onCollapse: {}
        ))
    }
}

#Preview("tease · paused") {
    PlayerSheetScreen {
        PlayerSheet(model: PlayerSheetModel(
            playback: SamplePlayback(scenario: .teasePaused, clock: ContinuousClock()),
            transcript: SampleTranscript.tease,
            onCollapse: {}
        ))
    }
}

#Preview("tease · ended") {
    PlayerSheetScreen {
        PlayerSheet(model: PlayerSheetModel(
            playback: SamplePlayback(scenario: .teaseEnded, clock: ContinuousClock()),
            transcript: SampleTranscript.tease,
            onCollapse: {}
        ))
    }
}
#endif
