//
//  EntryModel.swift
//  V2.journal (dark) · JR-4 one entry: the page's state. Your words, and one meta line that says
//  when, how (written, voice) and where it is ("read", "sent", "waiting to send", or "didn't send ·
//  tap to retry"), as Paper draws them (05: rest N51-0, voice note N6E-0, nothing taken yet N7R-0,
//  offline N9D-0). Edit is in the cut (founder 27 Oct: your words are editable in the journal, on
//  sample data until BE1.5b). What the backend can't serve yet stays off (`EntryCapabilities`): delete,
//  what Retro took and "not right" (founder-review 34), the voice note's play row (no served
//  recording: 33) and "show it in the conversation" (no drawn landing: SCREEN-MAP row 66).
//
import Foundation
import Observation

/// What the entry page may show. The app's cut has edit on (founder 27 Oct) and the rest off until each
/// door exists; the launcher's `drawn-*` states turn every drawn part on so they can be seen (J-19).
struct EntryCapabilities: Equatable {
    /// "edit" and the editing bar (BE1.5b).
    var edit = false
    /// "delete entry" and its dialog (BE1.6).
    var delete = false
    /// "what i took from this" and "not right" (BE1.7).
    var took = false

    static let cut = EntryCapabilities(edit: true)
    static let drawn = EntryCapabilities(edit: true, delete: true, took: true)
}

@MainActor
@Observable
final class EntryModel {
    typealias Entry = Flows.Journal.Entry

    /// How the meta line ends.
    enum Standing: Equatable {
        /// Retro has read it (with a tick).
        case read
        /// Sent; Retro hasn't read it yet.
        case sent
        /// Offline, kept on the phone.
        case waiting
        /// Didn't send: tap the line to retry (danger text, retry glyph).
        case notSent
    }

    enum State: Equatable {
        case loading
        case shown(words: String, meta: String, standing: Standing)
        case failed(String)
    }

    private(set) var state: State = .loading
    let capabilities: EntryCapabilities
    let id: String

    @ObservationIgnored private let data: any EntriesData
    @ObservationIgnored private var entry: Entry?

    init(id: String, data: any EntriesData, capabilities: EntryCapabilities = .cut) {
        self.id = id
        self.data = data
        self.capabilities = capabilities
    }

    func load() async {
        switch await data.entry(id: id) {
        case let .success(found):
            entry = found
            state = .shown(words: found.text, meta: meta(found), standing: Self.standing(found))
        case let .failure(failure):
            // a reload that fails keeps the last entry on screen; only the first load fails the page
            if let entry {
                state = .shown(words: entry.text, meta: meta(entry), standing: Self.standing(entry))
                return
            }
            state = .failed(failure.message ?? "couldn't open this entry. try again in a moment.")
        }
    }

    /// The meta line's tap: retries an entry that didn't send.
    func retry() async {
        guard let found = entry, let client = found.clientEntryId, case .shown(_, _, .notSent) = state else { return }
        // show it sending at once, so a second tap can't send it twice
        var sending = found
        sending.delivery = .sending
        entry = sending
        state = .shown(words: sending.text, meta: meta(sending), standing: Self.standing(sending))
        await data.retry(clientEntryId: client)
        await load()
    }

    static func standing(_ entry: Entry) -> Standing {
        switch entry.delivery {
        case .waiting, .sending: .waiting
        case .failed: .notSent
        case .sent: entry.reading == .read ? .read : .sent
        }
    }

    /// "today · 9:12 · written · read" (Paper 1FRP-0); "today · 9:40 · didn't send · tap to retry" (N9D-0).
    func meta(_ entry: Entry) -> String {
        let when = "\(EntryWords.dayLabel(entry.day, today: data.today)) · \(EntryWords.time(entry.createdAt, in: data.timeZone))"
        switch Self.standing(entry) {
        case .notSent: return "\(when) · didn't send · tap to retry"
        case .waiting: return "\(when) · waiting to send"
        case .sent: return "\(when) · \(Self.kind(entry.kind)) · sent"
        case .read: return "\(when) · \(Self.kind(entry.kind)) · read"
        }
    }

    /// The entry page's kind word (Paper: "written", "voice").
    static func kind(_ kind: Entry.Kind) -> String {
        switch kind {
        case .typed, .unknown: "written"
        case .voice: "voice"
        case .conversation: "conversation"
        case .imported: "shared"
        }
    }
}
