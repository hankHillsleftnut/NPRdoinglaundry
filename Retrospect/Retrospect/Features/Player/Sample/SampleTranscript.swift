//
//  SampleTranscript.swift
//  PS.sheet.a: the tease's words for the player sheet, word for word as Paper ON-11 draws them
//  (26PE-0 … 26PA-0), each with the second it starts at. The start times sit inside the tease's
//  chapters (SamplePlayback.tease: 0, 33, 79, 104 of 130 s) so the lit line at 0:48 is the third one,
//  as drawn. Sample only: the live lines come from the episode later (BE3.x.ep).
//
import Foundation

enum SampleTranscript {
    static let tease = Flows.Transcript(lines: [
        .init(id: 0, text: "This is the week you started, so it's a short one.", startSeconds: 0),
        .init(id: 1, text: "Here's the first thing I noticed. It's narrow, because it's day one.", startSeconds: 33),
        .init(
            id: 2,
            text: "You said Thursday's investor call matters. Your calendar agrees: three prep blocks, all before noon.",
            startSeconds: 41
        ),
        .init(id: 3, text: "You give your mornings to what you care about.", startSeconds: 79),
        .init(id: 4, text: "Next Sunday I'll have a whole week to go on.", startSeconds: 104),
    ])
}
