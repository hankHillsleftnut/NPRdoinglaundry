//
//  LiveFirstRunData.swift
//  FR.b1.data: the first run's live seam. The questions page reads it exactly as it reads the sample
//  (`Flows.FirstRun`); nothing on screen changes. It asks only the questions whose key the answers door
//  accepts today (`OnboardingAnswer.QuestionKey(flow:)`): `struggle` is kept out until BE.struggle is
//  deployed (FR.b2), so no answer can be refused for its key and lost. An answer is kept on the phone
//  and queued in one write through the outbox (`.saved`); a write that fails keeps the words on screen
//  (`.failedKept`). `finishQuestions` queues `complete`, which the outbox sends after every answer; when
//  the door answers, the session keeps the new access state (`member`). After `stop()` (sign-out) it
//  reads and writes nothing: the next person never sees this person's words.
//
import Foundation
import Observation

@MainActor
@Observable
final class LiveFirstRunData: Flows.FirstRun {
    /// An answer longer than this (UTF-16 units, after trimming) is refused on the phone; the door's limit (contract 01 §4).
    static let longestAnswer = 8000

    let questions: [Flows.FirstRunQuestion]
    private(set) var answeredKeys: Set<Flows.QuestionKey> = []
    /// The words kept on this phone for each question answered (resume shows them, the recap reads them). Never logged.
    private(set) var kept: [Flows.QuestionKey: String] = [:]
    /// The kept answers have been read from the store (`open()`); until then `answeredKeys` is empty.
    private(set) var isLoaded = false
    /// `finishQuestions` queued `complete` (or found it queued or sent already).
    private(set) var completeQueued = false
    /// The door answered `complete`: the person is a member.
    private(set) var isComplete = false

    @ObservationIgnored private let outbox: Store.Outbox
    @ObservationIgnored private let setAccess: @Sendable (Session.AccessState) async -> Void
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var completionWatch: Task<Void, Never>?
    /// After `stop()` nothing more is read, written or shown.
    @ObservationIgnored private var stopped = false

    init(
        outbox: Store.Outbox,
        questions: [Flows.FirstRunQuestion] = Flows.FirstRunQuestion.core,
        setAccess: @escaping @Sendable (Session.AccessState) async -> Void,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.outbox = outbox
        self.questions = Self.asked(questions)
        self.setAccess = setAccess
        self.now = now
    }

    /// The seam on the person's outbox and session (built by `AppEnvironment` with the stack).
    convenience init(outbox: Store.Outbox, session: Session.Manager, questions: [Flows.FirstRunQuestion] = Flows.FirstRunQuestion.core) {
        self.init(outbox: outbox, questions: questions, setAccess: { await session.setAccess($0) })
    }

    /// The questions the door accepts, in order: one whose key it refuses is not asked (never sent, never lost).
    nonisolated static func asked(_ questions: [Flows.FirstRunQuestion]) -> [Flows.FirstRunQuestion] {
        questions.filter { Backend.Endpoints.OnboardingAnswer.QuestionKey(flow: $0.key) != nil }
    }

    /// Reads the answers kept on this phone (resume starts after them) and starts listening for `complete`
    /// landing. Called once when the stack opens; a host may await it before showing the questions.
    func open() async {
        guard !stopped else { return }
        if completionWatch == nil {
            // registered before the reads below, so a `complete` left from the last session that lands while
            // they run (the outbox may already be draining) is heard: the stream replays nothing
            let completions = await outbox.completions()
            guard !stopped else { return }
            if completionWatch == nil {
                completionWatch = Task { [weak self] in
                    for await access in completions {
                        guard let self, !stopped else { return }
                        isComplete = true
                        await setAccess(access)
                    }
                }
            }
        }
        let rows = await (try? outbox.firstRunAnswers()) ?? [:]
        let sent = await (try? outbox.isCompleteSent()) ?? false
        guard !stopped else { return }
        kept = rows
        answeredKeys = Set(rows.keys)
        if sent {
            completeQueued = true
            isComplete = true
        }
        isLoaded = true
    }

    /// The person signed out: nothing more is read or written, and no late receipt changes the session.
    func stop() {
        stopped = true
        completionWatch?.cancel()
        completionWatch = nil
    }

    // MARK: Flows.FirstRun

    func answer(_ key: Flows.QuestionKey, text: String, given: Flows.FirstRunQuestion.Given) async -> Flows.AnswerOutcome {
        guard !stopped else { return .failedKept(.signedOut) }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // everything the door refuses (profile.ts AnswerCreateBody): a key it doesn't accept, a skip (never sent: no skip, founder
        // rule), no words, too many, a NUL. Refused here, so no row can ever dead-letter for it.
        guard let doorKey = Backend.Endpoints.OnboardingAnswer.QuestionKey(flow: key), given != .skipped, !words.isEmpty,
              words.utf16.count <= Self.longestAnswer, !words.contains("\u{0}")
        else { return .failedKept(.invalid) }
        do {
            try await outbox.enqueueAnswer(key: key, doorKey: doorKey, text: words, given: .init(flow: given), createdAt: now())
        } catch {
            return .failedKept(.unknown)
        }
        guard !stopped else { return .failedKept(.signedOut) }
        kept[key] = words
        answeredKeys.insert(key)
        return .saved
    }

    func finishQuestions() async {
        guard !stopped, await (try? outbox.enqueueComplete()) != nil, !stopped else { return }
        completeQueued = true
    }
}
