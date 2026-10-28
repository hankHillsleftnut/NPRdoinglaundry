//
//  SampleTook.swift
//  V2.journal J2b: what Retro took from the sample entries, Paper's own lines (N51-0: one claim, one
//  already noted). Shown only under the launcher's `drawn-*` states (BE1.7 isn't live).
//
#if DEBUG
import Foundation

enum SampleTook {
    static func claims(for entryID: String) -> [TookClaim] {
        guard entryID == SampleEntries.hereID else { return [] }
        return [
            TookClaim(id: "took-monday", words: "the monday standup is hard for you"),
            TookClaim(id: "took-dread", words: "you feel dread before 9am meetings", noted: true),
        ]
    }
}
#endif
