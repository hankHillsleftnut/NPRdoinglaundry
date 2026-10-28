import Foundation
@testable import Retrospect
import Testing

/// V2.outside · EX-2 and EX-3 content: Paper's words, the skips, and the notification rules.
struct OutsideContentTests {
    @Test("lock screen: Paper's title, line, 1:12 and −2:48, skips 15 and 30")
    func nowPlaying() {
        let content = NowPlayingContent.paper
        #expect(content.title == "the fundraise article you sent")
        #expect(content.subtitle == "retrospect · tuesday's brief · part 2 of 3")
        #expect(content.elapsedLabel == "1:12")
        #expect(content.remainingLabel == "\u{2212}2:48")
        #expect(content.skipBack == 15)
        #expect(content.skipForward == 30)
    }

    @Test("past the end the remaining time stays at zero")
    func remainingClamps() {
        let content = NowPlayingContent(title: "t", subtitle: "s", duration: 60, elapsed: 90)
        #expect(content.remainingLabel == "\u{2212}0:00")
    }

    @Test("an unknown or negative time reads 0:00, never crashes")
    func clockGuards() {
        #expect(NowPlayingContent.clock(.nan) == "0:00")
        #expect(NowPlayingContent.clock(.infinity) == "0:00")
        #expect(NowPlayingContent.clock(-5) == "0:00")
    }

    @Test("quiet hours that don't wrap midnight (a daytime window) are honoured too")
    func daytimeQuiet() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let noon = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12)))
        let evening = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 18)))
        let policy = NotificationPolicy(quietFrom: 9, quietUntil: 17)
        #expect(policy.isQuiet(noon, calendar: calendar))
        #expect(!policy.isQuiet(evening, calendar: calendar))
    }

    @Test("notifications: Paper's three kinds and where each lands")
    func kinds() {
        #expect(NotificationKind.episode.body() == "this week's episode is here.")
        #expect(NotificationKind.brief.body() == "your brief is ready · 4 min")
        #expect(NotificationKind.question.body() == "one question for you, when you have a minute.")
        #expect(NotificationKind.allCases.map(\.destination) == [.episode, .brief, .question])
        #expect(Set(NotificationKind.allCases.map(\.threadID)).count == 3)
    }

    @Test("at most one a day, never at night (21:00-08:00 by default)")
    func policy() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)))
        }
        let policy = NotificationPolicy()
        #expect(try policy.allows(at: at(26, 8, 30), lastSent: nil, calendar: calendar))
        #expect(try policy.allows(at: at(26, 18, 10), lastSent: nil, calendar: calendar))
        #expect(try !policy.allows(at: at(26, 18, 10), lastSent: at(26, 8, 30), calendar: calendar))
        #expect(try policy.allows(at: at(27, 9), lastSent: at(26, 18, 10), calendar: calendar))
        #expect(try !policy.allows(at: at(26, 21), lastSent: nil, calendar: calendar))
        #expect(try !policy.allows(at: at(27, 7, 59), lastSent: nil, calendar: calendar))
        #expect(try policy.allows(at: at(27, 8), lastSent: nil, calendar: calendar))
        // a clock moved back across midnight: the day before the last one is not a later day
        #expect(try !policy.allows(at: at(26, 18), lastSent: at(27, 9), calendar: calendar))
    }
}
