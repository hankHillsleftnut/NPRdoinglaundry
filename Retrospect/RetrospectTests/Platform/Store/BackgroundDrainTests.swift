import BackgroundTasks
import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct BackgroundDrainTests {
    private final class SchedulerSpy: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var registered: [String] = []
        private(set) var submitted: [(identifier: String, earliest: Date)] = []
        var refuses = false

        var scheduler: Store.BackgroundDrain.Scheduler {
            Store.BackgroundDrain.Scheduler(
                register: { identifier, _ in
                    self.lock.withLock { self.registered.append(identifier) }
                    return true
                },
                submit: { identifier, earliest in
                    if self.refuses {
                        throw BGTaskScheduler.Error(.unavailable)
                    }
                    self.lock.withLock { self.submitted.append((identifier, earliest)) }
                }
            )
        }
    }

    @Test("the task id is the one Info.plist permits")
    func theTaskIDIsPermitted() throws {
        let plist = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Retrospect/Info.plist")
        let data = try Data(contentsOf: plist)
        let object = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let permitted = try #require(object?["BGTaskSchedulerPermittedIdentifiers"] as? [String])

        #expect(Store.BackgroundDrain.identifier == "com.shauryanarang.Retrospect.outbox.drain")
        #expect(permitted.contains(Store.BackgroundDrain.identifier))
    }

    @Test("register registers the drain's identifier")
    func registerRegistersTheIdentifier() {
        let spy = SchedulerSpy()

        #expect(Store.BackgroundDrain(scheduler: spy.scheduler).register())

        #expect(spy.registered == [Store.BackgroundDrain.identifier])
    }

    @Test("a background drain is requested only when something is unsent, not before fifteen minutes")
    func aDrainIsRequestedOnlyWithUnsentItems() {
        let spy = SchedulerSpy()
        let drain = Store.BackgroundDrain(scheduler: spy.scheduler)
        let now = Date(timeIntervalSince1970: 1_792_569_604)

        #expect(!drain.scheduleIfNeeded(unsent: 0, now: now))
        #expect(drain.scheduleIfNeeded(unsent: 2, now: now))

        #expect(spy.submitted.count == 1)
        #expect(spy.submitted.first?.identifier == Store.BackgroundDrain.identifier)
        #expect(spy.submitted.first?.earliest == now.addingTimeInterval(15 * 60))
    }

    @Test("a refused request is reported as not scheduled, never thrown")
    func aRefusedRequestIsNotScheduled() {
        let spy = SchedulerSpy()
        spy.refuses = true

        #expect(!Store.BackgroundDrain(scheduler: spy.scheduler).scheduleIfNeeded(unsent: 1))
    }
}
