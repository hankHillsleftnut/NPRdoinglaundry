//
//  YouSourceModel.swift
//  V2.you · YO-3: one state (loading, the entry, or gone), loaded once. Your words are not editable from
//  You (founder 27 Oct: editable in Journal only), so this page only reads.
//
import Foundation

@MainActor
@Observable
final class YouSourceModel {
    enum State: Equatable {
        case loading
        case content(Flows.SourceEntry)
        /// The source doesn't exist (any more).
        case gone
    }

    private(set) var state: State = .loading
    let sourceID: String
    private let data: any YouData

    init(sourceID: String, data: any YouData) {
        self.sourceID = sourceID
        self.data = data
    }

    /// Loads once: coming back to the page (after YO-5) keeps what is shown.
    func load() async {
        guard state == .loading else { return }
        state = await data.source(id: sourceID).map(State.content) ?? .gone
    }

    var entry: Flows.SourceEntry? {
        if case let .content(entry) = state { return entry }
        return nil
    }
}
