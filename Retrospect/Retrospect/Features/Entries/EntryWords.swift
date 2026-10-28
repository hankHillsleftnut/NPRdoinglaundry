//
//  EntryWords.swift
//  V2.journal (dark): how the drawer (JR-3) and the entry page (JR-4) word a day and a time, as
//  Paper writes them: "today", "yesterday", else "sun 19 oct" from the contract's local day; "9:12"
//  and "22:40" in the person's time zone. Fixed words whatever the phone's language (lowercase app).
//
import Foundation

enum EntryWords {
    /// "today", "yesterday", else "sun 19 oct".
    static func dayLabel(_ day: String, today: String) -> String {
        guard let date = Self.day(day), let now = Self.day(today) else { return day }
        let days = utc.dateComponents([.day], from: date, to: now).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "yesterday"
        default: return date.formatted(dayFormat).lowercased()
        }
    }

    /// "9:12", "22:40": the hour without a leading zero.
    static func time(_ date: Date, in zone: TimeZone) -> String {
        var calendar = utc
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = parts.minute ?? 0
        return "\(parts.hour ?? 0):\(minute < 10 ? "0" : "")\(minute)"
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    /// "Sun 19 Oct", lowercased on use.
    private static let dayFormat = Date.VerbatimFormatStyle(
        format: "\(weekday: .abbreviated) \(day: .defaultDigits) \(month: .abbreviated)",
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: utc.timeZone,
        calendar: utc
    )

    private static func day(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
