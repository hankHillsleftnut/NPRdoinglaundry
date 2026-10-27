//
//  BriefSheet.swift
//  V2.journal J3, JR-2 today's brief (Paper 1FMG-0 playing, GLN-0 paused, GNY-0 played, GQ9-0 quiet).
//  The player sheet's parts, reused as they are (PS.sheet.a): the header (the 22 mark, the brief's
//  headline, share and collapse), "correct this part" (cosmetic, founder Q1 = C), RScrubber counting
//  the parts ("1 of 3 · the article") and RTransport with its "…" menu (inert rows, Q2 = B) and 1.0×.
//  Where ON-11 shows the transcript, JR-2 shows the brief: the part playing now raised, 24 under the
//  header, and "next" 24 under it; played, the last part and nothing next; a quiet day, one inky line
//  centred in the open space and no "correct this part" (Paper draws none there).
//  Hidden (scope §0): the source line's chevron (no destination drawn) and the mini-player after the
//  collapse (not drawn): the collapse goes back to the journal.
//
import SwiftUI

struct BriefSheet: View {
    let model: BriefSheetModel

    var body: some View {
        VStack(spacing: RDimension.space0) {
            PlayerSheetHeader(title: model.title, shareText: model.shareText, onCollapse: model.collapse)
                .padding(.top, RDimension.space1)
            middle
                .frame(maxHeight: .infinity, alignment: .top)
            if !model.isQuiet {
                CorrectThisPart()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, RDimension.space4)
            }
            RScrubber(playback: model.playback, partLabel: .counted)
                .padding(.top, model.isQuiet ? RDimension.space8 : RDimension.space5)
            RTransport(playback: model.playback, more: moreRows)
                .padding(.top, RDimension.space6)
        }
        .accessibilityAction(.escape) { model.collapse() }
    }

    /// The brief's words, only while the one player is on this brief (never another item's).
    @ViewBuilder
    private var middle: some View {
        if model.isThisBrief {
            brief
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var brief: some View {
        switch model.content.kind {
        case let .quiet(line, note):
            BriefQuietLine(line: line, note: note)
                .padding(.bottom, RDimension.space16)
                .frame(maxHeight: .infinity)
        case .brief:
            ScrollView {
                VStack(alignment: .leading, spacing: RDimension.space6) {
                    if let now = model.now {
                        BriefItemNow(label: model.nowLabel, place: model.place, part: now)
                            .animation(RMotion.standard(RNumber.motionDurationFast), value: model.currentIndex)
                    }
                    if !model.next.isEmpty {
                        VStack(alignment: .leading, spacing: RDimension.space1) {
                            Text("next")
                                .rText(.briefLabel)
                                .foregroundStyle(RColor.textLabel)
                                .padding(.horizontal, RDimension.space4)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(model.next) { item in
                                BriefItemNext(number: item.number, words: item.part.title)
                            }
                        }
                    }
                }
                .padding(.top, RDimension.space6)
                .padding(.bottom, RDimension.space6)
                // room inside the clip for the raised card's shadow at the sides
                .padding(.horizontal, RDimension.space4)
            }
            // the scroll reaches 16 past the sheet's inset, so the card stays on the inset with its shadow
            // whole; it stays clipped, so nothing scrolls over the header, the pill or the scrubber
            .padding(.horizontal, -RDimension.space4)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// The "…" rows, as the player sheet draws them (founder Q2 = B): choosing one only closes the menu.
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
