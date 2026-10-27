//
//  EntriesData.swift
//  V2.journal (dark): the seam the journal's other pages read, JR-3 all entries (the drawer) and
//  JR-4 one entry. Built on sample data now (`SampleEntriesData`); the group's wiring PR adapts the
//  live journal data (`LiveJournalData+Drawer`), whose drawer calls have the same shapes, so the
//  pages never change when the backend attaches. Dark: only the launcher names these types
//  (ReleaseRouteTableTests fences `Features/Entries`).
//
import Foundation

/// What the drawer and the entry page need from the journal.
@MainActor
protocol EntriesData: AnyObject {
    /// A page of entries, newest first; with a `query`, only the ones that match, with their spans
    /// (contract 02 §5, the same call as `Flows.JournalData.entries`).
    func entries(cursor: String?, query: String?) async -> Result<Flows.Page<Flows.Journal.Entry>, Flows.Failure>
    /// Sends again an entry that didn't send (the row's "tap to retry").
    func retry(clientEntryId: String) async
    /// The phone has no connection: the drawer says so in one grey line and lists what it keeps.
    var isOffline: Bool { get }
    /// The person's local day, `YYYY-MM-DD`, and the time zone their times are read in.
    var today: String { get }
    var timeZone: TimeZone { get }
}
