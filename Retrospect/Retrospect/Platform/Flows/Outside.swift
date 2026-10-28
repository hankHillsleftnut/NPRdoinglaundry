//
//  Outside.swift
//  V2.outside (EX-1 share, EX-4 widgets): what the views outside the app read. Today only the sample
//  (Features/Outside/Sample) stands behind it; the share extension and the widget timeline plug in here
//  once their targets exist (founder paperwork: App Group, extension targets). Views only: nothing here
//  saves, schedules or talks to a server.
//
import Foundation

/// The thing being shared and Retro's read of it (EX-1 c:share/item-card 1H1Z-0).
struct ShareItem: Equatable, Sendable {
    /// "how to raise a seed round in 2026".
    let title: String
    /// "youtube.com · 40 min video".
    let source: String
    /// Retro's one-line read: "a 40-minute talk on raising a seed round, mostly about angels."
    let read: String
    /// The goal it goes with: "raise the seed"; nil when none fits.
    let goal: String?
}

/// EX-1's seam: the item, and saving it with your optional why.
@MainActor
protocol ShareData: AnyObject {
    func item() async -> ShareItem
    /// Saves the item (and the why, when there is one). The sample only records it.
    func save(why: String) async
}

/// What a home-screen widget shows (EX-4 c:widget/344x164 1H4L-0).
struct WidgetBrief: Equatable, Sendable {
    /// "today's brief · 4 min".
    let label: String
    /// "a heavier week than usual, and it shows."
    let line: String
}
