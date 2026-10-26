//
//  SampleTranscript.swift
//  PS.sheet.a: the tease's words for the player sheet, word for word as Paper ON-11 draws them
//  (26PE-0 … 26PA-0), each with the second it starts at inside the 10-second tease (founder Q5 = B),
//  so the third line, the one Paper lights, is read from 0:04 to 0:07. Sample only: the live lines
//  come from the episode later (BE3.x.ep).
//
import Foundation

enum SampleTranscript {
    /// The id of the episode these lines belong to (`SamplePlayback.tease`).
    static let teaseID = "sample-tease"

    static let tease = Flows.Transcript(itemID: teaseID, lines: [
        .init(id: 0, text: "This is the week you started, so it's a short one.", startSeconds: 0),
        .init(id: 1, text: "Here's the first thing I noticed. It's narrow, because it's day one.", startSeconds: 2),
        .init(
            id: 2,
            text: "You said Thursday's investor call matters. Your calendar agrees: three prep blocks, all before noon.",
            startSeconds: 4
        ),
        .init(id: 3, text: "You give your mornings to what you care about.", startSeconds: 7),
        .init(id: 4, text: "Next Sunday I'll have a whole week to go on.", startSeconds: 8.5),
    ])
}
