//
//  WhyThisIsHerePage.swift
//  V2.podcasts.b · PC-3 why this is here, inside the player sheet (Paper 1FXR-0): the header (a 32
//  wash back chevron, the episode's title, the 34 collapse; 1FZA-0), then one scroll 24 under it with
//  32 between groups (1FY0-0): the claim (RClaim, stated or asked), "what it rests on" over the
//  evidence rows in one panel (REvidenceRow in REvidenceGroup), and the moment in the episode where
//  Retro says it (EpisodeMomentCard). "not right" sits under the scroll, 16 above it (1FXT-0).
//  The card's shadow is never clipped by the scroll (comment c-vkm9o5 → `.scrollClipDisabled()`).
//  Not drawn (founder-review lean): "and n more" under the rows, and "nothing to show yet" when no
//  source can be shown.
//  Taps without a drawn destination (the rows' ›, "not right": SCREEN-MAP row 80, G6) are disabled
//  with the reason "not available yet"; back and "hear it" are too until the player hosts the page.
//
import SwiftUI

struct WhyThisIsHerePage: View {
    let model: WhyThisIsHereModel

    var body: some View {
        VStack(spacing: RDimension.space0) {
            header
                .padding(.top, RDimension.space1)
            ScrollView {
                columnContent
                    .padding(.top, RDimension.space6)
                    .padding(.bottom, RDimension.space4)
            }
            .scrollClipDisabled()
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
            RPill(
                title: "not right",
                symbol: "text.bubble",
                size: .medium,
                disabledReason: WhyThisIsHereModel.notAvailableYet
            ) {}
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, RDimension.space4)
            .accessibilityIdentifier("why.notRight")
        }
        .accessibilityAction(.escape) { model.dismiss() }
        .accessibilityIdentifier("why")
    }

    /// The claim, what it rests on, and the moment (Paper 1FY0-0: 32 between groups).
    private var columnContent: some View {
        VStack(alignment: .leading, spacing: RDimension.space8) {
            RClaim(kind: model.content.kind, text: model.content.claim, meta: model.content.meta)
            restsOn
            if let moment = model.content.moment {
                VStack(alignment: .leading, spacing: RDimension.space2) {
                    RSectionLabel(title: model.content.momentLabel)
                    EpisodeMomentCard(moment: moment, hearIt: hearIt)
                }
            }
        }
    }

    /// "hear it" plays only once the player hosts the page.
    private var hearIt: (() -> Void)? {
        guard model.hearIt != nil else { return nil }
        return { model.playMoment() }
    }

    /// Paper 1FZA-0: back and the title 8 apart on the left, collapse on the right.
    private var header: some View {
        HStack(spacing: RDimension.space2) {
            RIconButton(symbol: "chevron.left", label: "back to the player", role: .inField) {
                model.back?()
            }
            .disabled(model.back == nil)
            .accessibilityHint(model.back == nil ? WhyThisIsHereModel.notAvailableYet : "")
            .accessibilityIdentifier("why.back")
            Text(model.content.episodeTitle)
                .rText(.playerHeaderTitle)
                .foregroundStyle(RColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: RDimension.space2)
            RIconButton(symbol: "chevron.down", label: "close", role: .sheetHeader, action: model.dismiss)
                .accessibilityHint("closes the player")
                .accessibilityIdentifier("why.close")
        }
        .frame(minHeight: RDimension.sizePlayerHeaderButton)
    }

    @ViewBuilder private var restsOn: some View {
        VStack(alignment: .leading, spacing: RDimension.space2) {
            RSectionLabel(title: "what it rests on")
            if model.content.evidence.isEmpty {
                REmptyLine(line: WhyThisIsHereModel.nothingYet)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                REvidenceGroup {
                    ForEach(model.content.evidence) { row in
                        REvidenceRow(leading: .kind(symbol: row.kind.symbol), meta: row.meta, words: row.words) {}
                            .disabled(true)
                            .accessibilityHint(WhyThisIsHereModel.notAvailableYet)
                    }
                }
                if let more = model.moreLine {
                    Text(more)
                        .rText(.metaLine)
                        .foregroundStyle(RColor.textLabel)
                        .padding(.leading, RDimension.space4)
                        .accessibilityIdentifier("why.more")
                }
            }
        }
    }
}
