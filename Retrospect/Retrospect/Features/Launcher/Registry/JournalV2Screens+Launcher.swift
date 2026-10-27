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
//  `drawn-rest|drawn-nothingTaken|drawn-offline|drawn-editing|drawn-deleteDialog` open the same page
//  with the drawn parts on (edit, what i took, not right, delete: J-19), as Paper draws them.
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
            return AnyView(EntriesLaunch(scenario: .rest, opening: entry.entryID, drawn: entry.drawnStart))
        },
    ]
}

/// JR-4's launcher states: which entry opens (Paper's 05 frames).
enum EntryScenario: String, CaseIterable {
    case rest, voiceNote, nothingTaken, offline
    case drawnRest = "drawn-rest"
    case drawnNothingTaken = "drawn-nothingTaken"
    case drawnOffline = "drawn-offline"
    case drawnEditing = "drawn-editing"
    case drawnDeleteDialog = "drawn-deleteDialog"

    var entryID: String {
        switch self {
        case .rest, .drawnRest, .drawnEditing, .drawnDeleteDialog: SampleEntries.hereID
        case .voiceNote: SampleEntries.walkID
        case .nothingTaken, .drawnNothingTaken: SampleEntries.ranID
        case .offline, .drawnOffline: SampleEntries.trainID
        }
    }

    /// The drawn states open with every drawn part on, in Paper's state; the others are the cut.
    var drawnStart: EntryDrawnModel.Start? {
        switch self {
        case .rest, .voiceNote, .nothingTaken, .offline: nil
        case .drawnRest, .drawnNothingTaken, .drawnOffline: .rest
        case .drawnEditing: .editing
        case .drawnDeleteDialog: .deleteDialog
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
    /// Drawn parts on (J2b `drawn-*`), and the state the first opened entry starts in.
    private let drawn: EntryDrawnModel.Start?
    private let openingID: String?
    /// The opening entry's drawn start is used once; entries opened later start at rest.
    @State private var startUsed = false
    /// Deletes so far: the warning haptic plays here, on the stack that outlives the popped page.
    @State private var deletes = 0

    init(scenario: EntriesScenario, opening entryID: String? = nil, drawn: EntryDrawnModel.Start? = nil) {
        self.scenario = scenario
        self.drawn = drawn
        openingID = entryID
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
                EntryScreen(
                    id: id,
                    data: data,
                    capabilities: drawn == nil ? .cut : .drawn,
                    claims: SampleTook.claims(for: id),
                    start: id == openingID && !startUsed ? drawn ?? .rest : .rest,
                    onDelete: {
                        deletes += 1
                        if !path.isEmpty {
                            path.removeLast()
                        }
                    },
                    back: {
                        if !path.isEmpty {
                            path.removeLast()
                        }
                    }
                )
                .onAppear {
                    if id == openingID {
                        startUsed = true
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .onAppear { model.onOpen = { path.append($0.id) } }
        .sensoryFeedback(RHaptic.warning, trigger: deletes)
        .fullScreenCover(isPresented: $showsSettings) {
            AccountPage(flow: SampleSignOutFlow(unsent: 0)) { showsSettings = false }
        }
    }
}

#Preview("JR-3 · rest") { EntriesLaunch(scenario: .rest) }
#Preview("JR-3 · searching") { EntriesLaunch(scenario: .searching) }
#Preview("JR-4 · rest") { EntriesLaunch(scenario: .rest, opening: SampleEntries.hereID) }
#Preview("JR-4 · drawn") { EntriesLaunch(scenario: .rest, opening: SampleEntries.hereID, drawn: .rest) }
#endif
