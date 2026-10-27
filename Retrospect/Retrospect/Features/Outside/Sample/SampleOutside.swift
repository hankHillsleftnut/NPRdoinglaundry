//
//  SampleOutside.swift
//  V2.outside: Paper's words for the views outside the app (EX-1 1H1M-0, EX-4 1H4D-0). Nothing is
//  stored: saving only records what would have been saved, so a test (and the launcher) can see it.
//
import Foundation

@MainActor
final class SampleShare: ShareData {
    /// What "save" recorded: nil until saved; the why ("" when none was added).
    private(set) var saved: String?

    static let paper = ShareItem(
        title: "how to raise a seed round in 2026",
        source: "youtube.com · 40 min video",
        read: "a 40-minute talk on raising a seed round, mostly about angels.",
        goal: "raise the seed"
    )

    func item() async -> ShareItem {
        Self.paper
    }

    func save(why: String) async {
        saved = why
    }
}

enum SampleWidgets {
    static let brief = WidgetBrief(label: "today's brief · 4 min", line: "a heavier week than usual, and it shows.")
}
