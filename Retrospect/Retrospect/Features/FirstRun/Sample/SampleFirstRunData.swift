//
//  SampleFirstRunData.swift
//  P02.min: first run's questions on sample data, in memory. It conforms to `Flows.FirstRun`
//  exactly as the live seam will (PL3.3a.min), so mounting swaps one line and nothing on screen
//  changes. It also carries the simulated ear (SampleListening): the page listens on its own.
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
    /// The simulated ear (founder decision 4): sam answers out loud, on the same clock.
    let listening: (any Flows.Listening)?

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
        listening = SampleListening(clock: clock)
        isOffline = scenario == .questionsOffline
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

    func finishQuestions() async {
        finishCount += 1
    }
}
