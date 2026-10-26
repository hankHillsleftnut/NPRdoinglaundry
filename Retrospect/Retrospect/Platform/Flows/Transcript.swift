//
//  Transcript.swift
//  PS.sheet.a: what the player sheet reads along with (Paper ON-11 26OZ-0, PC-2 1FWU-0). An episode's
//  words, one line at a time, each with the second it starts at when the episode has timings, so the
//  sheet can light the line being read. The shape is the episode's `lines[]` (contract 03
//  `Backend.Podcasts.Line`: `startSeconds` is present only when the timing is measured; the
//  `transcript` fallback carries lines with no time). Today the sample gives it, later the episode
//  door does. Pure values: nothing here plays, loads or logs.
//
import Foundation

extension Flows {
    /// One line of an episode's words.
    struct TranscriptLine: Identifiable, Hashable, Sendable {
        /// The line's position, from 0.
        let id: Int
        let text: String
        /// Where the line starts in the audio, in seconds; nil when the episode's lines aren't timed.
        let startSeconds: Double?
    }

    /// An episode's lines, in the order they're read, and the episode they belong to.
    struct Transcript: Hashable, Sendable {
        /// The `PlaybackItem.id` these lines are the words of.
        let itemID: String
        let lines: [TranscriptLine]

        /// Every line has a start time, so the one being read can be found.
        var isTimed: Bool {
            !lines.isEmpty && lines.allSatisfy { $0.startSeconds != nil }
        }

        /// Timed lines are kept in the order they start, whatever order they arrived in; untimed lines
        /// keep their own order.
        init(itemID: String, lines: [TranscriptLine]) {
            self.itemID = itemID
            if lines.allSatisfy({ $0.startSeconds != nil }) {
                self.lines = lines.sorted { ($0.startSeconds ?? 0, $0.id) < ($1.startSeconds ?? 0, $1.id) }
            } else {
                self.lines = lines.sorted { $0.id < $1.id }
            }
        }

        /// The index of the line being read at `seconds`: the last line that has started. Before the
        /// first line starts, the first line (it's the one about to be read). Nil with no lines, or when
        /// the lines aren't timed: then nothing is lit rather than the wrong line.
        func lineIndex(at seconds: Double) -> Int? {
            guard isTimed else { return nil }
            return lines.lastIndex { ($0.startSeconds ?? 0) <= seconds } ?? 0
        }
    }
}
