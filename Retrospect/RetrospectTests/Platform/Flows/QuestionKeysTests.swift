import Foundation
@testable import Retrospect
import Testing

/// FR.b1.data (attach-bite1 R2): no first-run answer can ever be refused for its key and lost. The live
/// seam asks only keys the answers door accepts; the door's enum in the app is kept equal to the backend's
/// `QUESTION_KEYS` (backend/src/onboarding/profile.ts; the fixture `01/question.keys.json` replaces that
/// read with BE.struggle). Must-fail: drop the filter in `LiveFirstRunData.asked` and `struggleIsNotAsked`
/// goes red; add a key to the app's door enum the backend lacks and `theDoorEnumMatchesTheBackend` goes red.
@Suite(.timeLimit(.minutes(1)))
struct QuestionKeysTests {
    typealias DoorKey = Backend.Endpoints.OnboardingAnswer.QuestionKey

    @Test("every question the live seam asks has a key the door accepts")
    func everyAskedKeyIsAccepted() {
        let asked = LiveFirstRunData.asked(Flows.FirstRunQuestion.core)
        #expect(!asked.isEmpty)
        for question in asked {
            #expect(DoorKey(flow: question.key) != nil, "\(question.key.rawValue) is asked but the door refuses it")
            #expect(DoorKey(rawValue: question.key.rawValue) != nil, "\(question.key.rawValue) is not in the door's enum")
            #expect(DoorKey(flow: question.key)?.rawValue == question.key.rawValue, "the door key must be the same name on the wire")
        }
    }

    @Test("struggle is in the core list but not asked live until the door accepts it (FR.b2); the 8 others are, in order")
    func struggleIsNotAsked() {
        #expect(Flows.FirstRunQuestion.core.contains { $0.key == .struggle })
        let asked = LiveFirstRunData.asked(Flows.FirstRunQuestion.core).map(\.key)
        #expect(!asked.contains(.struggle))
        #expect(asked == Flows.FirstRunQuestion.core.map(\.key).filter { $0 != .struggle })
        #expect(asked.count == 8)
        #expect(DoorKey(flow: .struggle) == nil)
        #expect(DoorKey(flow: .unknown) == nil)
    }

    @Test("the door enum in the app equals the backend's QUESTION_KEYS (profile.ts), so a key can't drift between them")
    func theDoorEnumMatchesTheBackend() throws {
        let profile = Fixtures.root
            .deletingLastPathComponent() // fixtures
            .deletingLastPathComponent() // contracts
            .deletingLastPathComponent() // team
            .deletingLastPathComponent() // docs
            .appendingPathComponent("backend/src/onboarding/profile.ts")
        let source = try String(contentsOf: profile, encoding: .utf8)
        let range = try #require(source.range(of: #"QUESTION_KEYS = \[[^\]]*\]"#, options: .regularExpression))
        let declaration = String(source[range])
        let backendKeys: Set<String> = Set(declaration.matches(of: #/'([a-z.]+)'/#).map { String($0.output.1) })
        #expect(backendKeys.count >= 12)
        // every backend key decodes to an app key that maps back to the same name, and every mapped app key is a backend key
        let names: Set<String> = backendKeys.union(Flows.FirstRunQuestion.core.map(\.key.rawValue))
        let flowKeys: [Flows.QuestionKey] = names.compactMap { Flows.QuestionKey(rawValue: $0) }.filter { $0 != Flows.QuestionKey.unknown }
        let appKeys: Set<String> = Set(flowKeys.compactMap { DoorKey(flow: $0) }.map(\.rawValue))
        // a key the app defers on purpose (struggle until FR.b2) may already be on the backend: that is not drift
        let deferred = Set(DoorKey.notYetAccepted.map(\.rawValue))
        #expect(
            appKeys == backendKeys.subtracting(deferred),
            "app sends \(appKeys.subtracting(backendKeys).sorted()); backend only knows \(backendKeys.subtracting(appKeys).subtracting(deferred).sorted())"
        )
    }

    @Test("given maps onto the door's names; unknown is sent as typed, never as unknown")
    func givenMaps() {
        typealias Given = Backend.Endpoints.OnboardingAnswer.Given
        #expect(Given(flow: .voice) == .voice)
        #expect(Given(flow: .typed) == .typed)
        #expect(Given(flow: .skipped) == .skipped)
        #expect(Given(flow: .unknown) == .typed)
    }
}
