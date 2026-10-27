//
//  SampleWhy.swift
//  V2.podcasts.b: PC-3's words, as Paper draws them: "asked" (1FXG-0 = 05 NDK-0) and "stated"
//  (05 NBD-0), both resting on the same three sources and pointing at 4:12 in this week's episode.
//
import Foundation

/// PC-3's launcher states.
enum WhyScenario: String, CaseIterable {
    case asked
    case stated
    /// Not drawn: two more sources than the three rows shown ("and 2 more").
    case more
    /// Not drawn: nothing the page can show yet.
    case nothingYet = "nothing-yet"
}

enum SampleWhy {
    static let episodeTitle = "the week you stopped rushing"

    static let evidence: [WhyThisIsHere.Evidence] = [
        .init(id: "e1", kind: .words, meta: "14 oct · your words", words: "up at 6:40, a long focused morning"),
        .init(id: "e2", kind: .words, meta: "16 oct · your words", words: "\"felt sharp before anyone was online\""),
        .init(id: "e3", kind: .calendar, meta: "17 oct · calendar", words: "ran at 7, then shipped the deck"),
    ]

    static func content(_ scenario: WhyScenario) -> WhyThisIsHere {
        switch scenario {
        case .asked, .more, .nothingYet:
            WhyThisIsHere(
                episodeTitle: episodeTitle,
                kind: .asked,
                claim: "are mornings when you do your best work?",
                meta: "asked · fairly sure · rests on \(scenario == .more ? 5 : 3) mornings",
                evidence: scenario == .nothingYet ? [] : evidence,
                more: scenario == .more ? 2 : 0,
                moment: .init(quote: "“you sound sharper before nine. is that true for you?”", at: "at 4:12 in this week's", seconds: 252)
            )
        case .stated:
            WhyThisIsHere(
                episodeTitle: episodeTitle,
                kind: .stated,
                claim: "your best days start early.",
                meta: "stated · from what you did · very sure",
                evidence: evidence,
                more: 0,
                moment: .init(quote: "“three of your best days this week started before eight.”", at: "at 4:12 in this week's", seconds: 252)
            )
        }
    }
}
