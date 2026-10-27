//
//  JournalV2Screens+Launcher.swift
//  V2 lane 1 (plan-v2.md §3): the journal's other pages, JR-2 today's brief, JR-3 all entries,
//  JR-4 one entry, opened with `-Screen JR-<n> -State <state> -Data sample`. Dark: listed here and
//  nowhere in the release root. JR-1 stays in `Features/Journal/JournalScreens+Launcher.swift`.
//
//  JR-3: `-Screen JR-3 -State rest|empty|searching|noResults|offline` opens the drawer over JR-1 on
//  sample data in the state Paper draws; `flow` opens JR-1 with the drawer closed, so the drawer
//  button and the edge swipe can be tried. The foot's "settings" opens the account page until ST-1
//  is built (founder-review 37). A row pushes JR-4.
//
//  JR-4: `-Screen JR-4 -State rest|voiceNote|nothingTaken|offline` opens one entry pushed from the
//  drawer (back returns to it), in the app's cut: what has no door yet stays off (EntryCapabilities).
//
#if DEBUG
import SwiftUI

enum JournalV2Screens: ScreenGroup {
    static let name = "journal · v2"
    /// JR-2 (today's brief) lists itself in `Features/Entries/Brief/BriefLaunch.swift`.
    static let screens: [LaunchableScreen] = briefScreens + [
        LaunchableScreen(id: "JR-3", states: EntriesScenario.allCases.map(\.rawValue)) { arguments in
            AnyView(EntriesLaunch(scenario: EntriesScenario(rawValue: arguments.state) ?? .rest))
        },
        LaunchableScreen(id: "JR-4", states: EntryScenario.allCases.map(\.rawValue)) { arguments in
            let entry = EntryScenario(rawValue: arguments.state) ?? .rest
            // offline is Paper's offline frame (N9D-0): a retry waits on the phone
            return AnyView(EntriesLaunch(scenario: entry == .offline ? .offline : .rest, opening: entry.entryID))
        },
    ]
}

/// JR-4's launcher states: which entry opens (Paper's 05 frames).
enum EntryScenario: String, CaseIterable {
    case rest, voiceNote, nothingTaken, offline

    var entryID: String {
        switch self {
        case .rest: SampleEntries.hereID
        case .voiceNote: SampleEntries.walkID
        case .nothingTaken: SampleEntries.ranID
        case .offline: SampleEntries.trainID
        }
    }
}

/// JR-1 on sample data with the drawer (JR-3) on its own sample, the way the wiring PR will mount it.
struct EntriesLaunch: View {
    let scenario: EntriesScenario
    @State private var isOpen: Bool
    @State private var model: DrawerModel
    @State private var journalData: SampleJournalData
    @State private var showsSettings = false
    @State private var path: [String]
    @State private var data: SampleEntriesData

    init(scenario: EntriesScenario, opening entryID: String? = nil) {
        self.scenario = scenario
        _isOpen = State(initialValue: scenario != .flow)
        _path = State(initialValue: entryID.map { [$0] } ?? [])
        let data = SampleEntriesData(scenario: scenario)
        _data = State(initialValue: data)
        _model = State(initialValue: DrawerModel(data: data, query: scenario.query, hereID: SampleEntriesData.hereID))
        // the journal behind: blank on the first day (Paper MYD-0), else the sample thread
        _journalData = State(initialValue: SampleJournalData(scenario: scenario == .empty ? .dayOne : .full))
    }

    var body: some View {
        NavigationStack(path: $path) {
            DrawerHost(isOpen: $isOpen) { onHomeIndicator in
                DrawerPage(model: model, onHomeIndicator: onHomeIndicator) { showsSettings = true }
            } journal: {
                JournalPageContainer(today: SampleJournalContent.today) { isOpen = true }
                    .environment(\.journalData, journalData)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { id in
                EntryScreen(id: id, data: data) {
                    if !path.isEmpty {
                        path.removeLast()
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .onAppear { model.onOpen = { path.append($0.id) } }
        .fullScreenCover(isPresented: $showsSettings) {
            AccountPage(flow: SampleSignOutFlow(unsent: 0)) { showsSettings = false }
        }
    }
}

#Preview("JR-3 · rest") { EntriesLaunch(scenario: .rest) }
#Preview("JR-3 · searching") { EntriesLaunch(scenario: .searching) }
#Preview("JR-4 · rest") { EntriesLaunch(scenario: .rest, opening: SampleEntries.hereID) }
#endif
