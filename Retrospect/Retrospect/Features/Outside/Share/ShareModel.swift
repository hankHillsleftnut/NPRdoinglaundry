//
//  ShareModel.swift
//  V2.outside · EX-1's model. One state enum; only the drawn state is built (ready). Reading, saving,
//  saved, offline and video aren't drawn (EX-D2). "cancel" and "save" both close the sheet (journey
//  map: "save · sheet closes"); the host decides what closing means.
//
import Observation
import SwiftUI

@Observable
@MainActor
final class ShareModel {
    enum State: Equatable {
        case idle
        case ready(ShareItem)
        /// The sheet closed: saved (with the why, "" when none) or cancelled.
        case closed(saved: Bool)
    }

    private(set) var state: State = .idle
    /// "add why (optional)".
    var why: String
    private let data: any ShareData
    /// True while save is on its way, so a second tap can't save twice.
    private(set) var isSaving = false

    init(data: any ShareData, why: String = "") {
        self.data = data
        self.why = why
    }

    var item: ShareItem? {
        if case let .ready(item) = state {
            return item
        }
        return nil
    }

    func load() async {
        let item = await data.item()
        // a cancel (or save) while the item was loading wins
        guard state == .idle else { return }
        state = .ready(item)
    }

    func save() async {
        guard item != nil, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        await data.save(why: why.trimmingCharacters(in: .whitespacesAndNewlines))
        state = .closed(saved: true)
    }

    func cancel() {
        guard !isSaving else { return }
        state = .closed(saved: false)
    }
}
