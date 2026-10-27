//
//  Listening.swift
//  QU.followups.a: the questions page's ear (Paper ON-3–9 1F6C-0, c:voice-composer/listening and
//  c:onboarding/your-words). While a question is open Retro listens: the bars follow the voice, each
//  word lands under the question as it is recognised, and a quiet ends the answer. The sample hears a
//  scripted person (founder decision 4: "a SIMULATED listening composer"); a real recogniser plugs in
//  here later (VC.1). A first run without one has no ear: the page is typed only, as before.
//
import Foundation

extension Flows {
    /// What the ear reports, in order. Never logged: `word` carries the person's words.
    enum Heard: Equatable, Sendable {
        /// The voice level, 0…1; nil when it is quiet (the bars rest).
        case level(Double?)
        /// One more recognised word (or Paper's small group, "i'm in"), in speaking order.
        case word(String)
        /// The person stopped: the answer is what was heard.
        case ended
    }

    /// Hears one answer to one question. The stream ends after `.ended`, or when its consumer
    /// cancels (mic off, back, the page leaving): nothing arrives after that.
    @MainActor
    protocol Listening: AnyObject {
        func hear(_ key: QuestionKey) -> AsyncStream<Heard>
    }
}

extension Flows.FirstRun {
    /// No ear by default: the page is typed only (the live seam until a recogniser lands, VC.1).
    var listening: (any Flows.Listening)? {
        nil
    }
}
