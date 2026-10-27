import Foundation
@testable import Retrospect
import Testing

/// The rules that decide how much someone slept. Getting these wrong once
/// produced a portrait telling a person they never sleep.
struct SleepMathTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour, minute: minute))!
    }

    private var june9Night: (start: Date, end: Date) {
        SleepMath.nightWindow(for: at(9, 15), calendar: calendar)!
    }

    @Test func aNightRunsNoonToNoonAndBelongsToTheMorningItEnds() {
        #expect(june9Night.start == at(8, 12))
        #expect(june9Night.end == at(9, 12))
    }

    @Test func sleepThatStartsBeforeMidnightIsCountedInFull() {
        // 11pm to 7am. Counted from midnight, this used to read as 7 hours at
        // best, and as little as 1.5 when samples were split across midnight.
        let night = [SleepMath.Sample(start: at(8, 23), end: at(9, 7), stage: "core")]
        #expect(SleepMath.hoursAsleep(night, in: june9Night) == 8)
    }

    @Test func inBedWithNoSleepReadingIsNotRecordedNotZero() {
        let night = [SleepMath.Sample(start: at(8, 23), end: at(9, 7), stage: "in_bed")]
        #expect(SleepMath.hoursAsleep(night, in: june9Night) == nil)
    }

    @Test func noSamplesAtAllIsNotRecorded() {
        #expect(SleepMath.hoursAsleep([], in: june9Night) == nil)
    }

    @Test func aWatchAndAPhoneRecordingTheSameNightCountItOnce() {
        let night = [
            SleepMath.Sample(start: at(8, 23), end: at(9, 6), stage: "asleep_unspecified"), // iPhone
            SleepMath.Sample(start: at(8, 23, 30), end: at(9, 7), stage: "core"), // Watch
        ]
        #expect(SleepMath.hoursAsleep(night, in: june9Night) == 8)
    }

    @Test func awakeTimeIsNotSleep() {
        let night = [
            SleepMath.Sample(start: at(9, 0), end: at(9, 3), stage: "core"),
            SleepMath.Sample(start: at(9, 3), end: at(9, 4), stage: "awake"),
            SleepMath.Sample(start: at(9, 4), end: at(9, 7), stage: "rem"),
        ]
        #expect(SleepMath.hoursAsleep(night, in: june9Night) == 6)
        #expect(SleepMath.stageHours(night, in: june9Night)["awake"] == 1)
    }

    @Test func sleepOutsideTheNightBelongsToAnotherDay() {
        // An afternoon nap on the 9th belongs to the 10th's window, not this one.
        let nap = [SleepMath.Sample(start: at(9, 14), end: at(9, 15), stage: "core")]
        #expect(SleepMath.hoursAsleep(nap, in: june9Night) == nil)
    }
}
