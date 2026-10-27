//
//  SampleFirstRunData.swift
//  P02.min: first run's questions on sample data, in memory. It conforms to `Flows.FirstRun`
//  exactly as the live seam will (PL3.3a.min), so mounting swaps one line and nothing on screen
//  changes. It also carries the simulated ear (founder decision 4): per question, #201's
//  SampleListening hears what sam says, so the page answers out loud on its own.
//  Deterministic: the pretend save waits on the injected clock, nothing is random,
//  and the words are never kept beyond the answer count (nothing is logged).
//
import Foundation
import Observation

/// The sample's starting points (launcher states `questions`, `questions-resume`, `questions-offline`).
enum FirstRunScenario: String, CaseIterable {
    /// Nothing answered yet.
    case questions
    /// The first three answered: the page opens on the fourth.
    case questionsResume = "questions-resume"
    /// Every answer fails as if offline: the words stay on screen.
    case questionsOffline = "questions-offline"
    /// Paper's listening frame (1F6C-0), held: sam's Q1 words heard at once, "london" still soft,
    /// never ending (the comparison still, like ON-10's `getting-ready-still`).
    case questionsStill = "questions-still"
}

@MainActor
@Observable
final class SampleFirstRunData: Flows.FirstRun {
    let questions: [Flows.FirstRunQuestion]
    private(set) var answeredKeys: Set<Flows.QuestionKey>
    /// How many answers were handed over, and how many times the questions were finished
    /// (tests read these; the words themselves are not kept).
    private(set) var answerCount = 0
    private(set) var finishCount = 0
    /// Whether answers fail as if offline. Tests and the offline scenario set it.
    var isOffline: Bool
    /// One ear per question, made on first use, so a second listen to a question hears nothing new.
    @ObservationIgnored private var ears: [Flows.QuestionKey: SampleListening] = [:]
    /// The held still: every ear hands its words over at once and never ends.
    @ObservationIgnored private let holdsStill: Bool

    @ObservationIgnored private let clock: any Clock<Duration>

    /// How long the pretend save takes (short: a typed answer saves on the phone first).
    static let saveDelay: Duration = .milliseconds(250)

    init(
        scenario: FirstRunScenario,
        questions: [Flows.FirstRunQuestion] = Flows.FirstRunQuestion.core,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.questions = questions
        self.clock = clock
        isOffline = scenario == .questionsOffline
        holdsStill = scenario == .questionsStill
        answeredKeys = scenario == .questionsResume ? Set(questions.prefix(3).map(\.key)) : []
    }

    func answer(_ key: Flows.QuestionKey, text _: String, given _: Flows.FirstRunQuestion.Given) async -> Flows.AnswerOutcome {
        try? await clock.sleep(for: Self.saveDelay)
        answerCount += 1
        if isOffline {
            return .failedKept(.network)
        }
        answeredKeys.insert(key)
        return .saved
    }

    /// The sample person's answer to `key`, heard word by word on this data's clock (a question it
    /// has no words for, like Paper's quick-answers frame, leaves the ear open and quiet).
    func listening(for key: Flows.QuestionKey) -> (any Flows.Listening)? {
        if let ear = ears[key] {
            return ear
        }
        // a scripted answer, once; listening to it again ends after a quiet (nothing new to hear)
        let words = Self.spoken[key] ?? []
        let ear = holdsStill
            ? SampleListening(clock: clock, ends: false, waits: false, utterance: words)
            : SampleListening(clock: clock, utterance: words, quietEnds: !words.isEmpty)
        ears[key] = ear
        return ear
    }

    /// What sam says to each question (QC-4: Q1 is Paper's 1F6C-0 "sam." · "i'm in" · "london"; the
    /// rest are sample-only lines for the demo, never product copy). One entry = one word landing.
    static let spoken: [Flows.QuestionKey: [String]] = [
        .namePlace: ["sam.", "i'm in", "london"],
        .yearFromNow: ["the", "seed", "is", "raised,", "and", "i", "sleep", "before", "midnight."],
        .careMost: ["my", "sister,", "my", "health,", "and", "the", "team."],
        .onYourMind: ["the", "raise.", "the", "investor", "call", "on", "thursday."],
        .struggle: ["sleep.", "i", "keep", "pushing", "bedtime", "past", "one."],
        .workingOn: ["retrospect.", "it's", "going,", "slower", "than", "i'd", "like."],
        .keepMeaning: ["running", "in", "the", "mornings.", "work", "keeps", "winning."],
        .highLow: ["high:", "the", "first", "demo.", "low:", "losing", "a", "client."],
        .people: ["maya.", "and", "my", "brother;", "i", "should", "call", "him", "more."],
    ]

    func finishQuestions() async {
        finishCount += 1
    }
}
