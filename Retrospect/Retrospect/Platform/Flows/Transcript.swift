//
//  Transcript.swift
//  PS.sheet.a: what the player sheet reads along with (Paper ON-11 26OZ-0, PC-2 1FWU-0). An episode's
//  words, one line at a time, each with the second it starts at, so the sheet can light the line being
//  read. The shape is the episode's `lines[]` (BE3.x.ep, each with `startSeconds`); today the sample
//  gives it, later the episode door does. Pure values: nothing here plays, loads or logs.
//
import Foundation

extension Flows {
    /// One line of an episode's words.
    struct TranscriptLine: Identifiable, Hashable, Sendable {
        /// The line's position, from 0.
        let id: Int
        let text: String
        /// Where the line starts in the audio, in seconds.
        let startSeconds: Double
    }

    /// An episode's lines, in the order they're read.
    struct Transcript: Hashable, Sendable {
        let lines: [TranscriptLine]

        /// Lines are kept in the order they start, whatever order they arrived in.
        init(lines: [TranscriptLine]) {
            self.lines = lines.sorted { ($0.startSeconds, $0.id) < ($1.startSeconds, $1.id) }
        }

        /// The index of the line being read at `seconds`: the last line that has started. Before the
        /// first line starts, the first line (it's the one about to be read); nil with no lines.
        func lineIndex(at seconds: Double) -> Int? {
            guard !lines.isEmpty else { return nil }
            return lines.lastIndex { $0.startSeconds <= seconds } ?? 0
        }
    }
}
