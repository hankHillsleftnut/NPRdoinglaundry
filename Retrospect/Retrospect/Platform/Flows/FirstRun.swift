//
//  FirstRun.swift
//  First run's seam (contract 01 §1, §4; ui-engineer.md §4): the questions Retro asks after
//  "begin" (ON-3–9) and the `Flows.FirstRun` protocol the questions page reads. The views
//  build against it on sample data (P02.min); the live side (PL3.3a.min) answers through the
//  outbox. The app owns the question copy; the server only ever sees the key.
//
import Foundation
import Observation

extension Flows {
    /// Contract 01 §1's closed list of question keys; a key the app doesn't know decodes to
    /// `unknown` and is never asked.
    enum QuestionKey: String, ContractEnum {
        case namePlace = "name.place"
        case yearFromNow = "year.from.now"
        case careMost = "care.most"
        case onYourMind = "on.your.mind"
        /// Founder, 26 Oct (DECISIONS "new onboarding question"): asked right after `onYourMind`.
        /// App sample only until the attach phase: the backend door refuses keys it doesn't know yet.
        case struggle
        case workingOn = "working.on"
        case keepMeaning = "keep.meaning"
        case highLow = "high.low"
        case people
        case howStraight = "how.straight"
        case yesterday
        case readingWatching = "reading.watching"
        case thisWeek = "this.week"
        case unknown
    }

    /// One question: its key and the words Retro asks it with.
    struct FirstRunQuestion: Hashable, Sendable, Identifiable {
        /// How an answer was given (contract 01 §1). 0.1 only types (the keyboard's dictation
        /// counts as typed); `skipped` is never sent (no skip, founder rule).
        enum Given: String, ContractEnum {
            case voice, typed, skipped, unknown
        }

        let key: QuestionKey
        let text: String

        var id: QuestionKey {
            key
        }

        /// The 9 core questions, in the order they are asked (docs/second-brain/
        /// brief-onboarding-questions.md v2; founder may change the words: founder-review
        /// "RELEASE 0.1" Q2). The first is Paper ON-3–9's frame. The struggle question (founder,
        /// 26 Oct) is the founder's words lowercased; its wording is to be adjusted later.
        static let core: [Self] = [
            Self(key: .namePlace, text: "first, what should i call you, and where are you based?"),
            Self(
                key: .yearFromNow,
                text: "picture a year from now, and everything has gone as well as it realistically could. what does your life look like?"
            ),
            Self(key: .careMost, text: "what do you care about most: the things you'd protect even if they cost you?"),
            Self(key: .onYourMind, text: "what's been taking up most of your head lately?"),
            Self(
                key: .struggle,
                text: "what's one thing you're really struggling with these days that could be really important?"
            ),
            Self(key: .workingOn, text: "what are you working on right now, and how is it actually going?"),
            Self(key: .keepMeaning, text: "what's one thing you keep meaning to change, and what's gotten in the way so far?"),
            Self(key: .highLow, text: "a high point and a low point from the last few months?"),
            Self(key: .people, text: "who would you call if something went wrong? anyone you wish you saw more?"),
        ]
    }

    /// What handing an answer to the seam did. Neither case carries the person's words.
    enum AnswerOutcome: Hashable, Sendable {
        /// Kept on the phone and on its way: the page moves on.
        case saved
        /// Not kept: the page keeps the words on screen and stays on the question.
        case failedKept(Failure)
    }

    /// Everything the questions page reads and does. Actions never throw to a view.
    @MainActor
    protocol FirstRun: AnyObject, Observable {
        /// The questions to ask, in order.
        var questions: [FirstRunQuestion] { get }
        /// The keys already answered on this phone (resume starts at the first one not in it).
        var answeredKeys: Set<QuestionKey> { get }
        /// The ear, when there is one (Listening.swift); nil = typed only (the default).
        var listening: (any Listening)? { get }

        /// Hands one answer over. `.saved` adds `key` to `answeredKeys`.
        func answer(_ key: QuestionKey, text: String, given: FirstRunQuestion.Given) async -> AnswerOutcome
        /// Every question is answered: the page calls this once, then reports done to its host.
        func finishQuestions() async
    }
}
