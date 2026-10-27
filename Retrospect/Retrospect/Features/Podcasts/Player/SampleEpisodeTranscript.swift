//
//  SampleEpisodeTranscript.swift
//  V2.podcasts.c: PC-2's words (Paper 1FV9-0, lines 1FWZ-0 … 1FWV-0), word for word, each with the
//  second it starts at inside the sample weekly episode (`SamplePlayback.weeklyEpisode`, 11:30), so
//  the third line, the one Paper lights, is read from 4:00 to 4:40 and lit at 4:12. Only the line
//  being read is dark; every other line is dim (founder c-lsyb3w, which replaced Paper's "next
//  secondary" on every player master). Sample only: the live lines come from the episode later.
//
import Foundation

enum SampleEpisodeTranscript {
    /// When each of Paper's five lines starts: two in chapter 1 (0:00–2:56), three in chapter 2.
    static let starts: [Double] = [120, 150, 240, 280, 330]

    static let weekly = Flows.Transcript(
        itemID: SamplePlayback.weeklyEpisodeID,
        lines: zip(SamplePlayback.weeklyLines, starts).enumerated().map { index, pair in
            Flows.TranscriptLine(id: index, text: pair.0, startSeconds: pair.1)
        }
    )
}
