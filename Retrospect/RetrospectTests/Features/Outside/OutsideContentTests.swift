@testable import Retrospect
import Foundation
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
        #expect(policy.allows(at: try at(26, 8, 30), lastSent: nil, calendar: calendar))
        #expect(policy.allows(at: try at(26, 18, 10), lastSent: nil, calendar: calendar))
        #expect(!policy.allows(at: try at(26, 18, 10), lastSent: try at(26, 8, 30), calendar: calendar))
        #expect(policy.allows(at: try at(27, 9), lastSent: try at(26, 18, 10), calendar: calendar))
        #expect(!policy.allows(at: try at(26, 21), lastSent: nil, calendar: calendar))
        #expect(!policy.allows(at: try at(27, 7, 59), lastSent: nil, calendar: calendar))
        #expect(policy.allows(at: try at(27, 8), lastSent: nil, calendar: calendar))
    }
}
