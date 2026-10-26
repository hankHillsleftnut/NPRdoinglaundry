//
//  PlayerSheet.swift
//  PS.sheet.a: the player sheet as Paper ON-11 draws it (26NO-0; the same sheet as PC-2 1FV9-0), built
//  from the player parts that exist: the header, the transcript (flexes and scrolls), the place of
//  "correct this part", RScrubber and RTransport, with Paper's gaps (16, 20, 24) and 40 under the
//  transport. The scrubber names the chapter by its title alone, as ON-11 does. The controls Paper
//  draws without a destination ("correct this part", share, "…") keep their places but aren't built
//  (repo rule: no control without a destination; QUESTIONS Q1–Q3 in scopes/PS.sheet.md).
//  `PlayerSheetScreen` stands the sheet on the underlay for a screen that opens as a sheet (the tease);
//  inside the app the RSheetHost presents the same `PlayerSheet` (PS.sheet.c).
//
import SwiftUI

struct PlayerSheet: View {
    let model: PlayerSheetModel

    var body: some View {
        VStack(spacing: RDimension.space0) {
            PlayerSheetHeader(title: model.title, onCollapse: model.collapse)
                .padding(.top, RDimension.space1)
            TranscriptColumn(transcript: model.transcript, current: model.currentLine)
                .frame(maxHeight: .infinity)
            correctThisPart
                .padding(.top, RDimension.space4)
            RScrubber(playback: model.playback, partLabel: .title)
                .padding(.top, RDimension.space5)
            RTransport(playback: model.playback)
                .padding(.top, RDimension.space6)
        }
        .padding(.bottom, RDimension.space10)
        .accessibilityAction(.escape) { model.collapse() }
    }

    /// "correct this part" (26OV-0) opens a correction flow Paper doesn't draw yet (G6): its 36 row
    /// is kept so the transcript, scrubber and transport sit where Paper puts them.
    private var correctThisPart: some View {
        Color.clear
            .frame(height: RDimension.sizeControlMedium)
            .accessibilityHidden(true)
    }
}

/// A sheet that is open from the start, standing on the underlay (26NO-0): its top sits under the
/// status bar where Paper draws it (48), or right under a shorter status bar (SE). It runs to the
/// bottom edge; the sheet keeps its own 40 under the transport.
struct PlayerSheetScreen<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            RSheetPanel(content: content)
                .padding(.top, min(proxy.safeAreaInsets.top, RDimension.space12))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RColor.backgroundUnderlay)
                .ignoresSafeArea()
        }
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
