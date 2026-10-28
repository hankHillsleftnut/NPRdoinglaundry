//
//  DemoSamples.swift
//  DEMO.app.b: the demo's composition root. One instance of each group's existing sample per signed-in
//  session, handed to the pages through the environment the app route table reads (G0: "data from the
//  environment, as in the launcher"), so a page opened from another group's stack reads the same seam as
//  the page in its own tab, exactly as the live per-person stack will (AppEnvironment). A sign-out ends
//  the session and the next one builds new samples: nothing from the last session shows after AC-1.
//  No sample is copied or changed here; each comes from its group's Sample folder.
//
#if DEBUG
import SwiftUI

@MainActor
@Observable
final class DemoSamples {
    /// JR-1's thread and brief card.
    let journal = SampleJournalData(scenario: .full)
    /// JR-3 all entries and JR-4 one entry.
    let entries = SampleEntriesData(scenario: .rest)
    /// GL-1 and GL-2.
    let goals = SampleGoals()
    /// YO-1 … YO-5.
    let you = SampleYou()
    /// ST-1 … ST-8.
    let settings = SampleSettings()
    /// ST-9's sign-out (AC-2): nothing unsent, so it signs out at once; the demo hears `.done`.
    let signOut = SampleSignOutFlow(unsent: 0)
    /// JR-2: the brief on the sample player, as the brief lane's launcher plays it.
    let brief = BriefSheetSource(
        playback: SamplePlayback(scenario: .briefPaperPlaying, clock: ContinuousClock()),
        content: SampleBrief.heavierWeek
    )
}

extension View {
    /// The session's samples, where the pages and the app route table read them.
    func demoSamples(_ samples: DemoSamples) -> some View {
        environment(\.journalData, samples.journal)
            .environment(\.entriesData, samples.entries)
            .environment(\.settingsData, samples.settings)
            .environment(\.signOutFlow, samples.signOut)
            .environment(\.briefSheetSource, samples.brief)
    }
}
#endif
