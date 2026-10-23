import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct LiveJournalRootTests {
    @Test("the root's day is the person's local day, so it rolls over at their midnight, not UTC's")
    func theDayFollowsThePersonsZone() throws {
        let instant = Date(timeIntervalSince1970: 1_792_640_400) // 2026-10-22 03:40 UTC
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))

        #expect(LiveJournalRoot.day(now: instant, timeZone: tokyo) == "2026-10-22")
        #expect(LiveJournalRoot.day(now: instant, timeZone: losAngeles) == "2026-10-21")
        #expect(LiveJournalRoot.day(now: instant.addingTimeInterval(86400), timeZone: losAngeles) == "2026-10-22")
    }
}
