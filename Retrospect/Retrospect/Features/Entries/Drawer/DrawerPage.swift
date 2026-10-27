//
//  DrawerPage.swift
//  V2.journal (dark) · JR-3 all entries, the drawer's column (Paper 1FPO-0 and the 05 state frames
//  MW6-0, MYD-0, MZJ-0, N17-0, N2N-0): on background.underlay, 16 in from each side, the 36 journal
//  search field in its 44 tap area, the offline line, then the days (label 4 above its rows, 16
//  between days), each day's label pinned under the search while its rows scroll (build notes,
//  part 23). The foot (settings · v1.0) sits at the bottom over a fade; the list's last rows scroll
//  up past it. Empty and no-results are the shared empty line.
//
import SwiftUI

struct DrawerPage: View {
    /// Where the foot's backing turns solid (Paper 1FOR-0: underlay at 38%).
    static var footSolidFrom: CGFloat {
        0.38
    } // literal-ok: Paper's gradient stop, a fraction

    @Bindable var model: DrawerModel
    /// The screen has a home indicator (the foot sits on its safe area).
    var onHomeIndicator = true
    /// The foot's "settings" (ST-1, or the account page until ST-1 exists: founder-review 37).
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space4) {
            RSearchField(placeholder: "search your journal", text: $model.query, look: .journal)
                .accessibilityIdentifier("drawer.search")
            if model.isOffline {
                offlineLine
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, RDimension.space4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            // Paper 1FOR-0: the foot stands on its own backing, 48 of clear easing into the underlay
            // (solid from 38%) and running to the screen's bottom edge, so the last rows fade under it
            DrawerFoot(onHomeIndicator: onHomeIndicator, openSettings: openSettings)
                .padding(.top, RDimension.space12)
                .background(alignment: .bottom) {
                    LinearGradient(
                        stops: [
                            .init(color: RColor.backgroundUnderlay.opacity(0), location: 0),
                            .init(color: RColor.backgroundUnderlay, location: Self.footSolidFrom),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
        }
        .background(RColor.backgroundUnderlay)
        .task { await model.load() }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            Color.clear
        case .empty:
            REmptyLine(line: "nothing yet. say anything.", subline: "what you say shows up here, by day", symbol: "doc.text")
                .frame(maxHeight: .infinity)
                .accessibilityIdentifier("drawer.empty")
        case .noResults:
            REmptyLine(line: "nothing with that word yet", subline: "try another word you might have said", symbol: "magnifyingglass")
                .frame(maxHeight: .infinity)
                .accessibilityIdentifier("drawer.noResults")
        case let .failed(reason):
            REmptyLine(line: reason, action: .init(title: "try again") { Task { await model.load() } })
                .frame(maxHeight: .infinity)
        case let .list(sections):
            list(sections)
        }
    }

    private func list(_ sections: [DrawerModel.Section]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RDimension.space4, pinnedViews: .sectionHeaders) {
                ForEach(sections) { section in
                    Section {
                        VStack(alignment: .leading, spacing: RDimension.space1) {
                            ForEach(section.rows) { row in
                                REntryRow(
                                    words: row.words,
                                    meta: row.meta,
                                    matches: row.matches,
                                    status: row.status,
                                    here: row.here
                                ) { model.tap(row) }
                                    // nothing to open yet: not a dead control, it says so
                                    .disabled(!model.opens(row))
                                    .accessibilityHint(model.opens(row) ? "" : "not available yet")
                                    .accessibilityIdentifier("drawer.row.\(row.id)")
                                    .task(id: model.isLast(row)) {
                                        if model.isLast(row) {
                                            await model.loadMore()
                                        }
                                    }
                            }
                        }
                    } header: {
                        RSectionLabel(title: section.title)
                            .padding(.horizontal, RDimension.space3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RColor.backgroundUnderlay)
                    }
                }
            }
            // the last rows clear the foot (its fade and its 44 row above the bottom edge)
            .padding(.bottom, RDimension.space16 + RDimension.space12)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .rProgressiveBlur(.drawerFoot)
    }

    /// Paper N4S-0: a 14 offline glyph and the line in Geist 12, text.label, 12 in.
    private var offlineLine: some View {
        HStack(spacing: RDimension.space1) {
            RSymbol(name: "wifi.slash", size: .small, tint: RColor.iconMuted, glyphScale: 0.7) // literal-ok: Paper's 14 mark in the 16 frame
            Text("offline · new notes send when you're back")
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
        }
        .padding(.horizontal, RDimension.space3)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("drawer.offline")
    }
}
