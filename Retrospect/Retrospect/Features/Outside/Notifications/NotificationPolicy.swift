//
//  NotificationPolicy.swift
//  V2.outside · EX-3's rules (handoff): at most one a day, never at night, private by default. "Night"
//  isn't defined anywhere yet: the default quiet hours are 21:00 to 08:00 local (EX-D5, the founder
//  confirms). "Private by default" keeps Paper's general words, which say nothing personal on a locked
//  phone (EX-D6). Pure: the caller passes the time, the calendar and when the last one went out.
//
import Foundation

struct NotificationPolicy: Equatable, Sendable {
    /// The first hour notifications are quiet (21 = from 21:00).
    var quietFrom = 21
    /// The first hour they may come again (8 = from 08:00).
    var quietUntil = 8
    var perDay = 1

    /// Whether one may go out at `date`, given when the last one did.
    func allows(at date: Date, lastSent: Date?, calendar: Calendar) -> Bool {
        guard !isQuiet(date, calendar: calendar) else { return false }
        guard let lastSent else { return true }
        return !calendar.isDate(lastSent, inSameDayAs: date) || perDay > 1
    }

    func isQuiet(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return quietFrom > quietUntil
            ? hour >= quietFrom || hour < quietUntil
            : hour >= quietFrom && hour < quietUntil
    }
}
