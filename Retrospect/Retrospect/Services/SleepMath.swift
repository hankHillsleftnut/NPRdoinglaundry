import Foundation

/// How one night of sleep is counted, kept free of HealthKit so it can be tested.
///
/// Three mistakes this exists to stop. Between them they produced "you slept
/// 0.0 hours" on 746 of 749 days, and a portrait that told someone they never
/// sleep:
///
/// 1. Counting from midnight. A night that starts at 11pm lost everything before
///    midnight, so a full night could read as 1.5 hours. A night now runs noon
///    to noon, and belongs to the morning it ends on.
/// 2. "In bed" with no sleep reading counted as zero. An iPhone without a Watch
///    records only time in bed. No sleep reading now means "not recorded" (nil),
///    never "slept 0 hours".
/// 3. Adding up overlapping samples. A Watch and an iPhone both recording the
///    same night were summed, double-counting it. Overlaps are now merged.
enum SleepMath {
    struct Sample: Equatable {
        let start: Date
        let end: Date
        /// The sleep stage key ("core", "deep", "rem", "asleep_unspecified",
        /// "awake", "in_bed", "other").
        let stage: String

        var isAsleep: Bool {
            SleepMath.asleepStages.contains(stage)
        }
    }

    static let asleepStages: Set<String> = ["core", "deep", "rem", "asleep_unspecified"]

    /// The night that belongs to `day`: from noon the day before to noon on `day`.
    static func nightWindow(for day: Date, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        let midnight = calendar.startOfDay(for: day)
        guard
            let previousDay = calendar.date(byAdding: .day, value: -1, to: midnight),
            let start = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: previousDay),
            let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: midnight)
        else { return nil }
        return (start, end)
    }

    /// Hours asleep in the window, or nil if nothing recorded sleep at all.
    static func hoursAsleep(_ samples: [Sample], in window: (start: Date, end: Date)) -> Double? {
        let asleep = samples.filter { $0.isAsleep && $0.end > window.start && $0.start < window.end }
        guard !asleep.isEmpty else { return nil }
        return mergedHours(asleep, in: window)
    }

    /// Hours per stage in the window, with overlaps inside each stage merged.
    static func stageHours(_ samples: [Sample], in window: (start: Date, end: Date)) -> [String: Double] {
        Dictionary(grouping: samples, by: \.stage)
            .mapValues { mergedHours($0, in: window) }
            .filter { $0.value > 0 }
    }

    /// Total hours covered by the samples, clipped to the window, counting any
    /// stretch of time once however many samples cover it.
    static func mergedHours(_ samples: [Sample], in window: (start: Date, end: Date)) -> Double {
        let clipped = samples
            .map { (max($0.start, window.start), min($0.end, window.end)) }
            .filter { $0.0 < $0.1 }
            .sorted { $0.0 < $1.0 }

        var total: TimeInterval = 0
        var current: (Date, Date)?
        for interval in clipped {
            if let open = current, interval.0 <= open.1 {
                current = (open.0, max(open.1, interval.1))
            } else {
                if let open = current {
                    total += open.1.timeIntervalSince(open.0)
                }
                current = interval
            }
        }
        if let open = current {
            total += open.1.timeIntervalSince(open.0)
        }
        return total / 3600
    }
}
