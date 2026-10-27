//
//  WhatIKnowModel.swift
//  V2.you · YO-5: the page's one state (loading, then what Retro knows) read through `YouData`.
//
import Foundation

@MainActor
@Observable
final class WhatIKnowModel {
    enum State: Equatable {
        case loading
        case content(Flows.WhatIKnow)
    }

    private(set) var state: State = .loading
    private let data: any YouData

    init(data: any YouData) {
        self.data = data
    }

    func load() async {
        state = await .content(data.whatIKnow())
    }

    /// "2 answers changed" / "1 answer changed"; nil hides the row.
    static func changedLine(_ count: Int?) -> String? {
        guard let count, count > 0 else { return nil }
        return count == 1 ? "1 answer changed" : "\(count) answers changed"
    }
}
