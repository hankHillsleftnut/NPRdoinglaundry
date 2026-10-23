//
//  QuestionsModel.swift
//  P02.min, ON-3–9: what the questions page shows and does, from `Flows.FirstRun`. One
//  question at a time, in the seam's order, starting at the first one not answered (resume);
//  a send hands the words to the seam and moves to the next unanswered question; a failure
//  keeps the words in the composer with the offline line and stays put; back goes to the
//  previous question with its answer kept; once every question is answered it finishes the
//  seam exactly once and tells the host. It never reaches the network and never logs.
//
import Foundation
import Observation

@MainActor
@Observable
final class QuestionsModel {
    typealias Key = Flows.QuestionKey

    let data: any Flows.FirstRun
    /// The questions asked, in order: the seam's, without any key the app doesn't know.
    let questions: [Flows.FirstRunQuestion]

    /// The composer's words for the question on screen.
    var draft = ""
    /// Which question is on screen.
    private(set) var index: Int
    /// The words sent for each question this session, shown under the question when you go back.
    private(set) var answers: [Key: String] = [:]
    /// The question whose last send wasn't kept (its words are back in the composer), until one is.
    private(set) var failedKey: Key?
    /// Counts failed sends, so the page announces each one once.
    private(set) var failures = 0
    /// A send is on its way to the seam.
    private(set) var isSending = false
    /// `finishQuestions()` has been called (once, ever, for this model).
    private(set) var isFinished = false

    /// Called once, after `finishQuestions()`, when every question is answered.
    @ObservationIgnored var onDone: () -> Void = {}
    /// Unsent words per question, so going back and forth never loses what was typed.
    @ObservationIgnored private var drafts: [Key: String] = [:]

    /// ON-4a's offline frame (05b): the words are kept, nothing is lost.
    static let offlineLine = "you're offline. your answer is kept; we'll pick up here."

    init(data: any Flows.FirstRun) {
        self.data = data
        questions = Self.asked(data.questions)
        index = Self.firstUnanswered(questions, answered: data.answeredKeys) ?? max(questions.count - 1, 0)
    }

    // MARK: - Pure rules

    /// The questions to ask: unknown keys never are, and a key is asked once.
    static func asked(_ questions: [Flows.FirstRunQuestion]) -> [Flows.FirstRunQuestion] {
        var seen: Set<Key> = []
        return questions.filter { $0.key != .unknown && seen.insert($0.key).inserted }
    }

    /// The first question, in order, whose key isn't answered; nil when all are.
    static func firstUnanswered(_ questions: [Flows.FirstRunQuestion], answered: Set<Key>) -> Int? {
        questions.firstIndex { !answered.contains($0.key) }
    }

    /// How far the progress bar is filled on question `index` of `count` (one step per
    /// question, the one on screen counted, so the first already shows a sliver).
    static func progress(index: Int, count: Int) -> Double {
        guard count > 0 else { return 0 }
        return Double(min(index + 1, count)) / Double(count)
    }

    /// The composer after a send that wasn't kept: the failed words, then anything typed since.
    static func restored(failed: String, typed: String) -> String {
        if typed.isEmpty {
            return failed
        }
        return failed + " " + typed
    }

    // MARK: - What the page reads

    var question: Flows.FirstRunQuestion? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    /// The words sent for the question on screen, this session.
    var answer: String? {
        question.flatMap { answers[$0.key] }
    }

    var canGoBack: Bool {
        index > 0
    }

    var progress: Double {
        Self.progress(index: index, count: questions.count)
    }

    /// "step 3 of 8", for VoiceOver.
    var stepLabel: String {
        "step \(min(index + 1, questions.count)) of \(questions.count)"
    }

    /// The offline line, while the question on screen holds words that weren't kept.
    var offline: Bool {
        failedKey != nil && failedKey == question?.key
    }

    private var answered: Set<Key> {
        data.answeredKeys.union(answers.keys)
    }

    // MARK: - Actions

    /// The page's `.task`: a person who has answered everything is done at once.
    func appear() async {
        if Self.firstUnanswered(questions, answered: answered) == nil {
            await finish()
        }
    }

    /// Hands the words to the seam. Empty words are never sent; a send while one is on its way
    /// keeps its words in the composer. Saved: on to the next unanswered question (or done).
    /// Not kept: the words go back in the composer, the offline line shows, and it stays put.
    func send(_ text: String) async {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key = question?.key, !words.isEmpty, !isSending, !isFinished else {
            // nothing typed is ever dropped: the composer cleared itself before calling
            if !text.isEmpty {
                draft = Self.restored(failed: text, typed: draft)
            }
            return
        }
        draft = ""
        isSending = true
        let outcome = await data.answer(key, text: words, given: .typed)
        isSending = false
        switch outcome {
        case .saved:
            answers[key] = words
            drafts[key] = nil
            if failedKey == key {
                failedKey = nil
            }
            await advance(from: key)
        case .failedKept:
            failedKey = key
            failures += 1
            if question?.key == key {
                draft = Self.restored(failed: words, typed: draft)
            } else {
                // the person moved while it was on its way: the words wait with their question
                drafts[key] = Self.restored(failed: words, typed: drafts[key] ?? "")
            }
        }
    }

    /// Back to the previous question; its answer is kept and shown under it.
    func back() {
        guard canGoBack else { return }
        move(to: index - 1)
    }

    // MARK: - Private

    private func advance(from key: Key) async {
        // every question answered finishes, even if the person went back while it was on its way
        guard let next = Self.firstUnanswered(questions, answered: answered) else {
            await finish()
            return
        }
        // moved while it was on its way: stay where they went
        guard question?.key == key else { return }
        move(to: next)
    }

    private func move(to next: Int) {
        if let key = question?.key {
            drafts[key] = draft.isEmpty ? nil : draft
        }
        index = next
        draft = question.flatMap { drafts[$0.key] } ?? ""
    }

    private func finish() async {
        guard !isFinished else { return }
        isFinished = true
        await data.finishQuestions()
        onDone()
    }
}
