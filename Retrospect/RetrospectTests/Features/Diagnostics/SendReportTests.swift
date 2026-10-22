import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct SendReportTests {

    // MARK: The shake

    @Test("two hard knocks inside the window are a shake")
    func twoKnocksAreAShake() {
        var detector = ShakeDetector()
        func hit(_ magnitude: Double, _ time: TimeInterval) -> Bool {
            detector.feed(magnitude: magnitude, at: time)
        }

        #expect(!hit(3, 10))
        #expect(hit(3, 10.3))
    }

    @Test("a single bump, a gentle wobble and two knocks far apart are not")
    func quietThingsAreNotAShake() {
        var detector = ShakeDetector()
        func hit(_ magnitude: Double, _ time: TimeInterval) -> Bool {
            detector.feed(magnitude: magnitude, at: time)
        }

        #expect(!hit(4, 1))
        #expect(!hit(1.4, 1.2))
        #expect(!hit(1.4, 1.3))
        #expect(!hit(4, 5), "the second knock came too late to pair with the first")
    }

    @Test("one knock seen in many samples is still one knock")
    func oneKnockIsOneKnock() {
        var detector = ShakeDetector()
        func hit(_ magnitude: Double, _ time: TimeInterval) -> Bool {
            detector.feed(magnitude: magnitude, at: time)
        }

        let results = [10.00, 10.03, 10.06, 10.09].map { hit(3, $0) }

        #expect(results == [false, false, false, false])
    }

    @Test("after a shake nothing counts until the cooldown ends, and then a new shake does")
    func aShakeCoolsDown() {
        var detector = ShakeDetector()
        func hit(_ magnitude: Double, _ time: TimeInterval) -> Bool {
            detector.feed(magnitude: magnitude, at: time)
        }
        #expect(!hit(3, 0))
        #expect(hit(3, 0.3))

        #expect(!hit(3, 0.5))
        #expect(!hit(3, 0.9))
        #expect(!hit(3, 5))
        #expect(hit(3, 5.3))
    }

    @Test("the switch is on for TestFlight and debug builds and off for the App Store")
    func theSwitchDefault() {
        #expect(ShakePreference.defaultValue(receiptName: "sandboxReceipt", isDebug: false))
        #expect(ShakePreference.defaultValue(receiptName: nil, isDebug: true))
        #expect(!ShakePreference.defaultValue(receiptName: "receipt", isDebug: false))
        #expect(!ShakePreference.defaultValue(receiptName: nil, isDebug: false))
    }

    // MARK: The sheet's model

    @Test("counts load, the note is cut to the door's limit, and a queued report is handed on once")
    func aQueuedReportIsHandedOn() async {
        let sender = SampleReportSender(scenario: .online)
        var outcomes: [Flows.ReportOutcome] = []
        let model = SendReportModel(sender: sender) { outcomes.append($0) }
        await model.load()
        model.note = String(repeating: "a", count: SendReportModel.maxNoteCharacters + 50)

        await model.send()
        await model.send()

        #expect(model.included?.events == 1284)
        #expect(model.note.count == SendReportModel.maxNoteCharacters)
        #expect(outcomes.count == 1, "a second tap after it's saved does nothing")
        #expect(model.phase == .queued(online: true))
        #expect(sender.notes.count == 1)
    }

    @Test("offline the report is still saved, and the model says it waits")
    func offlineIsSaved() async {
        let sender = SampleReportSender(scenario: .offline)
        let model = SendReportModel(sender: sender) { _ in }

        await model.send()

        #expect(model.phase == .queued(online: false))
    }

    @Test("a report that couldn't be saved says so, hands nothing on, and can be tried again")
    func aFailureCanBeRetried() async {
        let sender = SampleReportSender(scenario: .failing)
        var handedOn = 0
        let model = SendReportModel(sender: sender) { _ in handedOn += 1 }

        await model.send()
        #expect(model.phase == .failed)
        #expect(model.canSend)
        await model.send()

        #expect(sender.notes.count == 2)
        #expect(handedOn == 0)
    }
}
