//
//  BriefSheetModel.swift
//  V2.journal J3, JR-2 today's brief (Paper 1FMG-0, key states GLG-0): the brief opened from the
//  journal's card as a player sheet. In place of the transcript it shows the part playing now
//  (raised: "playing now" · "1 of 3", the part, why it is here, where it came from) and the parts
//  still to come ("next"); played, the last part with "played" and nothing next; a quiet day, one
//  inky line and how short today's brief is. Everything is read from the one player
//  (`Flows.Playback`), so the card follows the audio as it moves between parts.
//  Dark (plan-v2 §1): reachable only from the launcher, on sample data.
//
import Foundation
import Observation

/// What today's brief says about itself, beyond the audio: per part, the words the card shows.
struct BriefSheetContent: Hashable, Sendable {
    struct Part: Hashable, Sendable {
        /// The part as the card names it ("the fundraise article you sent").
        let title: String
        /// "here for your goal: raise the seed" (contract 02 §3 `why`); nil hides the line.
        let why: String?
        /// "from the link you sent yesterday, 9:14": where the part came from; nil hides the line.
        /// Plain text: the destination isn't drawn (SCREEN-MAP row 53), so it is not a button.
        let source: String?
    }

    enum Kind: Hashable, Sendable {
        case brief(parts: [Part])
        /// A quiet day: Retro's one line and a note on the brief's length (GQ9-0).
        case quiet(line: String, note: String)
    }

    let kind: Kind
}

@MainActor @Observable
final class BriefSheetModel {
    /// The now card's label: the part playing (paused, it stays the part playing: GLN-0), or the
    /// last part once the brief has played (GNY-0).
    enum NowLabel: Equatable {
        case playingNow
        case played

        var words: String {
            switch self {
            case .playingNow: "playing now"
            case .played: "played"
            }
        }
    }

    let playback: any Flows.Playback
    let content: BriefSheetContent
    @ObservationIgnored private let onCollapse: () -> Void
    /// The collapse is handed over once; a second tap while the sheet leaves does nothing.
    private(set) var hasCollapsed = false

    init(playback: any Flows.Playback, content: BriefSheetContent, onCollapse: @escaping () -> Void) {
        self.playback = playback
        self.content = content
        self.onCollapse = onCollapse
    }

    /// The header's line: the brief's headline, read from the player's item.
    var title: String {
        playback.item?.title ?? ""
    }

    /// What share hands the system share sheet (founder Q3 = B: a line of text).
    var shareText: String {
        title.isEmpty ? "retrospect" : "\(title) · retrospect"
    }

    var parts: [BriefSheetContent.Part] {
        if case let .brief(parts) = content.kind {
            return parts
        }
        return []
    }

    var isQuiet: Bool {
        if case .quiet = content.kind {
            return true
        }
        return false
    }

    var hasPlayed: Bool {
        playback.state == .ended
    }

    /// The part the card shows: the player's part, clamped to the parts the brief has; the last
    /// part once the brief has played.
    var currentIndex: Int {
        guard !parts.isEmpty else { return 0 }
        if hasPlayed {
            return parts.count - 1
        }
        return min(max(playback.currentPart ?? 0, 0), parts.count - 1)
    }

    var now: BriefSheetContent.Part? {
        parts.isEmpty ? nil : parts[currentIndex]
    }

    var nowLabel: NowLabel {
        hasPlayed ? .played : .playingNow
    }

    /// "1 of 3".
    var place: String {
        "\(currentIndex + 1) of \(parts.count)"
    }

    /// The parts after the one playing, with their numbers ("2 · four meetings before noon");
    /// nothing once the brief has played (GNY-0).
    var next: [NextPart] {
        guard !hasPlayed, currentIndex + 1 < parts.count else { return [] }
        return (currentIndex + 1 ..< parts.count).map { NextPart(number: $0 + 1, part: parts[$0]) }
    }

    /// One row of "next": the part's number in the brief and its words.
    struct NextPart: Identifiable, Equatable {
        let number: Int
        let part: BriefSheetContent.Part

        var id: Int {
            number
        }
    }

    /// The chevron-down: the sheet goes back to the journal, once (SCREEN-MAP row 52).
    func collapse() {
        guard !hasCollapsed else { return }
        hasCollapsed = true
        onCollapse()
    }
}
