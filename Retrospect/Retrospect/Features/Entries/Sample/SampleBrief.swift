//
//  SampleBrief.swift
//  V2.journal J3: JR-2's sample brief, Paper's own invented lines (1FMG-0, GNY-0, GQ9-0), not anyone's
//  words. The audio side (headline, timing, part names) is `SamplePlayback`'s `briefPaper*` scenarios.
//
#if DEBUG
import Foundation

enum SampleBrief {
    /// Paper's three parts (1FO0-0 now card, 1FNR-0 next rows, GNY-0 played card).
    static let heavierWeek = BriefSheetContent(kind: .brief(parts: [
        .init(
            title: "the fundraise article you sent",
            why: "here for your goal: raise the seed",
            source: "from the link you sent yesterday, 9:14"
        ),
        .init(
            title: "four meetings before noon",
            why: "here for your goal: protect the mornings",
            source: "from your calendar, today"
        ),
        .init(
            title: "five hours of sleep, two nights running",
            why: "here for your goal: sleep before midnight",
            source: "from your watch, monday and tuesday"
        ),
    ]))

    /// Paper's quiet day (GSN-0).
    static let quietTuesday = BriefSheetContent(kind: .quiet(
        line: "nothing much moved. enjoy the quiet.",
        note: "a short brief today · 40 seconds"
    ))
}
#endif
