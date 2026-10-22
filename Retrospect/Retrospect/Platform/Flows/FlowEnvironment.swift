//
//  FlowEnvironment.swift
//  How screens reach the flows (ui-engineer.md §4): one environment value per flow protocol,
//  set once at the app's root (sample or live) and read by any screen. Screens never take a
//  concrete type and never import Platform/Backend.
//
import SwiftUI

extension EnvironmentValues {
    /// The journal's data: `SampleJournalData` or `LiveJournalData`. Nil only outside the app
    /// (a preview that forgot to set it), which a screen treats as loading.
    @Entry var journalData: (any Flows.JournalData)?
    /// The one player.
    @Entry var playback: (any Flows.Playback)?
}
