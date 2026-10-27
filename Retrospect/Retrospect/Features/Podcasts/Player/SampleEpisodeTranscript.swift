//
//  SampleEpisodeTranscript.swift
//  V2.podcasts.c: PC-2's words (Paper 1FV9-0, lines 1FWZ-0 … 1FWV-0), word for word, each with the
//  second it starts at inside the sample weekly episode (`SamplePlayback.weeklyEpisode`, 11:30), so
//  the third line, the one Paper lights, starts with chapter 2 (2:56) and is lit at 4:12. Only the line
//  being read is dark; every other line is dim (founder c-lsyb3w, which replaced Paper's "next
//  secondary" on every player master). Sample only: the live lines come from the episode later.
//  Debug only (sandbox fence): only the launcher and the tests read it.
//
import Foundation

#if DEBUG
enum SampleEpisodeTranscript {
    /// When each of Paper's five lines starts: two in chapter 1 (0:00–2:56), three in chapter 2, the
    /// first of them on the chapter's start so the lit line and the scrubber's chapter always agree.
    /// The transcript stops at chapter 2 on purpose: Paper draws these five lines only, and invented
    /// lines for chapters 3 and 4 would show under them in the compared frame. So the last line stays
    /// lit from 5:30 to the end in the live `playing` state.
    static let starts: [Double] = [0, 120, 176, 280, 330]

    static let weekly = Flows.Transcript(
        itemID: SamplePlayback.weeklyEpisodeID,
        lines: zip(SamplePlayback.weeklyLines, starts).enumerated().map { index, pair in
            Flows.TranscriptLine(id: index, text: pair.0, startSeconds: pair.1)
        }
    )
}
#endif
