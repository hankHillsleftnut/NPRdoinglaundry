import Foundation

extension Flows.Journal.BriefSlot {
    /// What the brief card shows, worked out when it's read and never kept (contract PL3.1 §2): off when the
    /// person hasn't turned it on; today's brief when there is one (a quiet day is Retro's one line); else
    /// "being made" when one is due, else nothing on the way. A brief dated another day is never `ready`.
    static func derive(from latest: Backend.Endpoints.BriefLatest.Latest, today: String) -> Self {
        guard latest.enabled else { return .off }
        if let brief = latest.brief, brief.date == today {
            switch brief.kind {
            case .quiet:
                if let line = brief.parts.first?.text, !line.isEmpty {
                    return .quiet(line: line)
                }
            case .brief, .unknown:
                return .ready(brief)
            }
        }
        if let nextAt = latest.nextAt {
            return .making(readyBy: nextAt)
        }
        return .none
    }
}
