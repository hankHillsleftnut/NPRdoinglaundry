//
//  DemoFlowEdges.swift
//  FLOW.coverage (founder, DECISIONS 27 Oct: "EVERY page connected to every other page in flow, even with
//  dummy data"): every page Paper's "everything · latest" draws (p-J-0, 16EK-0) and every way out of it,
//  as one table. It is `pipeline/flow-coverage.md` §2–§5 row for row: the doc and this file change together.
//  A HIDDEN control (decided "not drawn in the app") is not a row; everything else is: a working edge, a
//  planned one (named PR), the "not available yet" pattern, an open founder question, or MISSING.
//  `DemoFlowEdgesTests` checks the table against the app's real navigation model (the flow's
//  `FlowEdge.table`, the launcher registry) on every base, and, once the demo host has landed
//  (`demoHostLanded`), that nothing is left planned, open or missing.
//

/// A registered destination of the demo: a page, a sheet or a state Paper draws as its own column, plus the
/// two places a walk starts from (a launch and the system opening the app).
enum DemoPage: String, CaseIterable, Sendable {
    /// where a walk starts
    case launch, system
    // first run (ON-1/2 … ON-13, with the invite gate kept between, DECISIONS 6)
    case splash = "ON-1/2", inviteGate = "PI1", youreIn = "PI2", questions = "ON-3–9", privacy = "ON-5"
    case connect = "ON-6", gettingReady = "ON-10", tease = "ON-11", paywall = "ON-12", firstHome = "ON-13"
    // the shell and its mini-player (part 45)
    case shell = "SHELL", miniPlayer = "MINI"
    // journal, podcasts, goals, you
    case jr1 = "JR-1", jr2 = "JR-2", jr3 = "JR-3", jr4 = "JR-4"
    case pc1 = "PC-1", pc2 = "PC-2", pc3 = "PC-3"
    case gl1 = "GL-1", gl2 = "GL-2"
    case yo1 = "YO-1", yo2 = "YO-2", yo3 = "YO-3", yo4 = "YO-4", yo5 = "YO-5"
    // settings and account
    case st1 = "ST-1", st2 = "ST-2", st3 = "ST-3", st4 = "ST-4", st5 = "ST-5", st6 = "ST-6", st7 = "ST-7"
    case st8 = "ST-8", st9 = "ST-9", ac2 = "AC-2", ac1 = "AC-1"
    // outside the app
    case ex1 = "EX-1", ex2 = "EX-2", ex3 = "EX-3", ex4 = "EX-4"

    /// A walk starts here; nothing leads in.
    var isOrigin: Bool {
        self == .launch || self == .system
    }

    /// The `-Screen <id>` ids that open this page in the launcher (any group's registry). A launcher id that
    /// looks like a Paper id and is on no page fails the coverage test: a screen merged without its joins.
    var launcherIDs: [String] {
        switch self {
        case .splash: ["PI0"]
        case .inviteGate: ["PI1"]
        case .youreIn: ["PI2"]
        case .jr1: ["JR-1", "journal"]
        case .tease: ["player"]
        case .st9: ["account", "ST-9"]
        case .shell: ["shell"]
        case .launch, .system, .questions, .privacy, .connect, .gettingReady, .paywall, .firstHome, .miniPlayer, .ex2, .ex3, .ex4:
            []
        default: [rawValue]
        }
    }
}

/// How a control is used.
enum DemoGesture: Equatable, Sendable {
    case tap, back, dismiss, swipe, tab, automatic, system
}

/// Who owns the move.
enum DemoVia: Equatable, Sendable {
    /// A first-run hand-off: a row of the flow's `FlowEdge.table` (step and event raw values).
    case flow(from: String, event: String, to: String)
    /// Inside one group's own typed stack, sheet or drawer (YouRoute, GoalsRoute, SettingsRoute, DrawerHost).
    case stack
    /// Across groups: a case of G0's `AppRoute.Kind` / `AppSheet.Kind` (raw value), resolved by the shell.
    case route(String)
    /// The shell (tabs) or the demo host itself (hand-off, sign-out loop, "opened from outside").
    case host
    /// The control changes the page it is on; listed so the control is counted.
    case inPlace
    /// The system (a lock screen, a notification, a widget, the share sheet).
    case system
}

/// Where the edge stands on today's base.
enum DemoStatus: Equatable, Sendable {
    /// Merged on main.
    case main
    /// Built in an open PR (inside its own group or launcher); the join may still be planned (see `join`).
    case pr(Int)
    /// No code yet; the PR that adds it.
    case planned(String)
    /// Drawn as Paper, inert, VoiceOver "not available yet" (DECISIONS 27 Oct consistency rule b).
    case notAvailableYet
    /// A founder question; the control waits for the answer.
    case open(String)
    /// Nobody plans it yet.
    case missing(String)
}

/// One way out of a page.
struct DemoEdge: Sendable {
    let id: String
    let from: DemoPage
    let control: String
    let gesture: DemoGesture
    /// The page it lands on; nil when it stays on the page (`inPlace`) or has no target yet.
    let to: DemoPage?
    let via: DemoVia
    let status: DemoStatus
    /// The demo's join for an edge built only inside its group (a DEMO.app §5 row).
    let join: String?

    init(
        _ id: String,
        _ from: DemoPage,
        _ control: String,
        _ gesture: DemoGesture,
        _ to: DemoPage?,
        _ via: DemoVia,
        _ status: DemoStatus,
        join: String? = nil
    ) {
        self.id = id
        self.from = from
        self.control = control
        self.gesture = gesture
        self.to = to
        self.via = via
        self.status = status
        self.join = join
    }

    /// Counts as a way in or out of a page: it lands somewhere and is built or planned.
    var connects: Bool {
        guard to != nil, via != .inPlace else { return false }
        switch status {
        case .main, .pr, .planned: return true
        case .notAvailableYet, .open, .missing: return false
        }
    }

    /// Works on today's base, in the demo's walk.
    var worksOnMain: Bool {
        status == .main
    }
}

enum DemoFlowEdges {
    /// Flipped by the demo host's last PR (DEMO.app.c) in the same change that sets every row's status:
    /// from then on no row may be planned, open or missing, and every page is reachable from a launch.
    static let demoHostLanded = false

    /// Pages that have no way out inside the app, by design: the lock screen's now playing has no page in a
    /// simulator (it is covered by the player).
    static let noWayOut: Set<DemoPage> = [.ex2]

    /// The founder's named exceptions to "no inert control" in release (plan-glue §3) are still rows here;
    /// the demo shows them as "not available yet".
    static let edges: [DemoEdge] = firstRun + shellAndJournal + podcasts + goalsAndYou + settings + outside

    // MARK: first run (flow-coverage.md §2)

    static let firstRun: [DemoEdge] = [
        DemoEdge("F01", .launch, "-Flow demo (or the saved step)", .automatic, .splash, .host, .main),
        DemoEdge("F02", .splash, "Sign in with Apple", .tap, .inviteGate, .flow(from: "splash", event: "signedIn", to: "inviteGate"), .main),
        DemoEdge("F03", .splash, "Continue with Google", .tap, .inviteGate, .flow(from: "splash", event: "signedIn", to: "inviteGate"), .main),
        DemoEdge("F04", .splash, "terms · privacy", .tap, nil, .inPlace, .missing("plain words: neither links nor the not-available-yet pattern")),
        DemoEdge("F05", .splash, "sign-in fails", .automatic, nil, .inPlace, .main),
        DemoEdge("F06", .inviteGate, "join the waitlist", .tap, nil, .inPlace, .main),
        DemoEdge("F07", .inviteGate, "tear", .swipe, .youreIn, .flow(from: "inviteGate", event: "ticketTorn", to: "youreIn"), .main),
        DemoEdge("F08", .youreIn, "begin", .tap, .questions, .flow(from: "youreIn", event: "begin", to: "questions"), .main),
        DemoEdge("F09", .questions, "send · chip · back", .tap, nil, .inPlace, .main),
        DemoEdge("F10", .questions, "the last answer", .tap, .privacy, .flow(from: "questions", event: "questionsDone", to: "privacy"), .main),
        DemoEdge("F11", .privacy, "back", .back, .questions, .flow(from: "privacy", event: "back", to: "questions"), .main),
        DemoEdge(
            "F12",
            .privacy,
            "read-aloud ends · tap",
            .automatic,
            .connect,
            .flow(from: "privacy", event: "privacyDone", to: "connect"),
            .main
        ),
        DemoEdge("F13", .privacy, "read the privacy policy", .tap, nil, .inPlace, .main),
        DemoEdge("F14", .connect, "+ connect", .tap, nil, .inPlace, .pr(199)),
        DemoEdge(
            "F15",
            .connect,
            "continue · later",
            .tap,
            .gettingReady,
            .flow(from: "connect", event: "connectDone", to: "gettingReady"),
            .main
        ),
        DemoEdge("F16", .connect, "back", .back, .privacy, .flow(from: "connect", event: "connectBack", to: "privacy"), .main),
        DemoEdge(
            "F18",
            .gettingReady,
            "episode ready",
            .automatic,
            .tease,
            .flow(from: "gettingReady", event: "episodeReady", to: "tease"),
            .main
        ),
        DemoEdge(
            "F20",
            .tease,
            "the 10 s mark",
            .automatic,
            .paywall,
            .flow(from: "tease", event: "teaseEnded", to: "paywall"),
            .planned("PS.sheet.c / PW.paywall.b")
        ),
        DemoEdge("F21", .tease, "collapse chevron", .dismiss, nil, .inPlace, .open("Q-E3 / map Q7: where the tease's collapse goes")),
        DemoEdge("F22", .tease, "share", .tap, nil, .inPlace, .main),
        DemoEdge("F23", .tease, "correct this part · … rows", .tap, nil, .inPlace, .notAvailableYet),
        DemoEdge(
            "F24",
            .paywall,
            "either price",
            .tap,
            .firstHome,
            .flow(from: "paywall", event: "subscribed", to: "firstHome"),
            .planned("PW.paywall.b + FH.home.b")
        ),
        DemoEdge("F25", .paywall, "restore · privacy · terms", .tap, nil, .inPlace, .notAvailableYet),
        DemoEdge("F26", .paywall, "mini-player play (haptic nudge)", .tap, nil, .inPlace, .planned("PW.paywall.b")),
        DemoEdge("F27", .firstHome, "first-episode card", .tap, .tease, .stack, .planned("FH.home.b")),
        DemoEdge("F27b", .tease, "close (from first home)", .dismiss, .firstHome, .stack, .planned("FH.home.b")),
        DemoEdge("F28", .firstHome, "drawer button", .tap, nil, .inPlace, .notAvailableYet),
        DemoEdge("F30", .firstHome, "the first run ends", .automatic, .shell, .host, .planned("DEMO.app.a")),
    ]

    // MARK: shell and journal (flow-coverage.md §3)

    static let shellAndJournal: [DemoEdge] = [
        DemoEdge("S01a", .shell, "tab · journal", .tab, .jr1, .host, .pr(213), join: "D14 DEMO.app.a"),
        DemoEdge("S01b", .shell, "tab · podcasts", .tab, .pc1, .host, .planned("DEMO.app.a")),
        DemoEdge("S01c", .shell, "tab · goals", .tab, .gl1, .host, .planned("DEMO.app.a")),
        DemoEdge("S01d", .shell, "tab · you", .tab, .yo1, .host, .planned("DEMO.app.a")),
        DemoEdge("S02", .shell, "re-tap a tab (scroll to top)", .tab, nil, .inPlace, .missing("#213 counts re-taps; no page listens")),
        DemoEdge("S03", .shell, "a tab with no page", .tab, nil, .inPlace, .missing("RTabBar says 'not built yet', the rule says 'not available yet'")),
        DemoEdge("S04", .miniPlayer, "tap", .tap, .pc2, .route("episode"), .planned("G0b + DEMO.app.b")),
        DemoEdge("J01", .jr1, "drawer button · edge swipe", .swipe, .jr3, .stack, .pr(226), join: "D15 DEMO.app.b"),
        DemoEdge("J02", .jr3, "journal edge", .tap, .jr1, .stack, .pr(226)),
        DemoEdge("J03", .jr3, "an entry", .tap, .jr4, .route("entry"), .pr(226), join: "D16 DEMO.app.b"),
        DemoEdge("J04", .jr3, "search · unsent row", .tap, nil, .inPlace, .pr(226)),
        DemoEdge("J05", .jr3, "foot · settings", .tap, .st1, .route("settingsHub"), .planned("DEMO.app.b"), join: "D17 (#226 opens the account page)"),
        DemoEdge("J06", .jr4, "back", .back, .jr3, .stack, .pr(233)),
        DemoEdge("J07", .jr4, "edit · not right · what i took", .tap, nil, .inPlace, .pr(240)),
        DemoEdge("J08", .jr4, "delete entry → delete it", .tap, .jr3, .stack, .pr(240)),
        DemoEdge("J10", .jr1, "brief card play", .tap, .jr2, .route("brief"), .planned("DEMO.app.b + G0b"), join: "D18 (main plays a text-only sheet)"),
        DemoEdge("J11", .jr2, "collapse · drag down", .dismiss, .jr1, .stack, .pr(235)),
        DemoEdge("J12", .jr2, "share", .tap, nil, .inPlace, .pr(235)),
        DemoEdge("J13", .jr2, "correct this part · … rows", .tap, nil, .inPlace, .notAvailableYet),
        DemoEdge("J14", .jr1, "composer mic · send", .tap, nil, .inPlace, .main),
        DemoEdge("J15", .jr1, "retro line 'because ›'", .tap, nil, .inPlace, .open("SCREEN-MAP row 67: the target")),
    ]

    // MARK: podcasts (flow-coverage.md §3)

    static let podcasts: [DemoEdge] = [
        DemoEdge("P01", .pc1, "hero play", .tap, .pc2, .route("episode"), .planned("V2.playbutton + DEMO.app.b"), join: "D19"),
        DemoEdge("P02", .pc1, "square tile", .tap, nil, .inPlace, .open("SCREEN-MAP row 73: episode or brief")),
        DemoEdge("P03", .pc2, "tap a transcript line", .tap, .pc3, .route("whyThisIsHere"), .pr(236), join: "D20 DEMO.app.b"),
        DemoEdge("P04", .pc2, "collapse", .dismiss, .miniPlayer, .host, .planned("G0b + DEMO.app.b")),
        DemoEdge("P05", .pc2, "share · correct this part · …", .tap, nil, .inPlace, .notAvailableYet),
        DemoEdge("P06", .pc3, "back chevron", .back, .pc2, .stack, .planned("DEMO.app.b")),
        DemoEdge("P07", .pc3, "chevron-down", .dismiss, .pc1, .stack, .planned("DEMO.app.b")),
        DemoEdge("P08", .pc3, "hear it", .tap, nil, .inPlace, .missing("PC-2 at the moment: no PR hosts PC-3 in the player")),
        DemoEdge("P09", .pc3, "evidence rows · not right", .tap, nil, .inPlace, .notAvailableYet),
        DemoEdge("P10", .ex2, "tap the lock screen player", .system, .pc2, .system, .notAvailableYet),
        DemoEdge("P11", .pc2, "lock the phone", .system, .ex2, .system, .planned("W3 now playing")),
    ]

    // MARK: goals and you (flow-coverage.md §4)

    static let goalsAndYou: [DemoEdge] = [
        DemoEdge("G01", .gl1, "a goal card", .tap, .gl2, .stack, .pr(219)),
        DemoEdge("G02", .gl1, "guess yes · not quite", .tap, nil, .inPlace, .pr(218)),
        DemoEdge("G04", .gl2, "back · turn off", .back, .gl1, .stack, .pr(219)),
        DemoEdge("G06", .gl2, "your words", .tap, .jr4, .route("entry"), .planned("DEMO.app.b"), join: "D24 (#219 hook unwired)"),
        DemoEdge("Y01", .yo1, "ask", .tap, .yo2, .stack, .pr(237)),
        DemoEdge("Y01b", .yo2, "clear", .tap, .yo1, .stack, .pr(237)),
        DemoEdge("Y02", .yo2, "a source", .tap, .yo3, .stack, .pr(237)),
        DemoEdge("Y03", .yo3, "back", .back, .yo2, .stack, .pr(231)),
        DemoEdge("Y04", .yo3, "this supports · what i know", .tap, .yo5, .stack, .pr(231)),
        DemoEdge("Y05", .yo1, "a node on the map", .tap, .yo4, .stack, .pr(241)),
        DemoEdge("Y06", .yo4, "chevron-down · still true", .dismiss, .yo1, .stack, .pr(241)),
        DemoEdge("Y07", .yo4, "evidence rows · not right", .tap, nil, .inPlace, .notAvailableYet),
        DemoEdge("Y08", .yo1, "what i know about you", .tap, .yo5, .stack, .pr(237)),
        DemoEdge("Y09", .yo5, "back", .back, .yo1, .stack, .pr(228)),
        DemoEdge("Y10", .yo1, "one question waiting · list", .tap, nil, .inPlace, .notAvailableYet),
        DemoEdge("Y11", .yo1, "your picture", .tap, .st1, .route("settingsHub"), .planned("DEMO.app.b"), join: "D22 (NA today)"),
        DemoEdge("Y12", .yo3, "a goal row", .tap, .gl2, .route("goal"), .planned("DEMO.app.b"), join: "D23 (NA today)"),
        DemoEdge("Y13", .yo3, "show it in the conversation", .tap, nil, .inPlace, .notAvailableYet),
    ]

    // MARK: settings and account (flow-coverage.md §4)

    static let settings: [DemoEdge] = [
        DemoEdge("T01a", .st1, "daily brief", .tap, .st2, .stack, .pr(225)),
        DemoEdge("T01b", .st1, "sources", .tap, .st3, .stack, .pr(230)),
        DemoEdge("T01c", .st1, "privacy", .tap, .st5, .stack, .pr(232)),
        DemoEdge("T01d", .st1, "how straight i am with you", .tap, .st6, .stack, .pr(229)),
        DemoEdge("T01e", .st1, "voice and listening", .tap, .st7, .stack, .pr(232)),
        DemoEdge("T01f", .st1, "what i've learned", .tap, .st8, .stack, .pr(229)),
        DemoEdge("T02", .st1, "account", .tap, .st9, .stack, .pr(229)),
        DemoEdge("T03a", .st2, "back", .back, .st1, .stack, .pr(225)),
        DemoEdge("T03b", .st3, "back", .back, .st1, .stack, .pr(230)),
        DemoEdge("T03c", .st4, "back", .back, .st3, .stack, .pr(230)),
        DemoEdge("T03d", .st5, "back", .back, .st1, .stack, .pr(232)),
        DemoEdge("T03e", .st6, "back", .back, .st1, .stack, .pr(229)),
        DemoEdge("T03f", .st7, "back", .back, .st1, .stack, .pr(232)),
        DemoEdge("T03g", .st8, "back", .back, .st1, .stack, .pr(229)),
        DemoEdge("T03h", .st9, "back", .back, .st1, .stack, .pr(229)),
        DemoEdge("T04", .st1, "back (to where it was opened)", .back, .shell, .stack, .planned("DEMO.app.b"), join: "D25"),
        DemoEdge("T05", .st1, "talk or read", .tap, nil, .inPlace, .pr(224)),
        DemoEdge("T06", .st3, "calendar", .tap, .st4, .stack, .pr(230)),
        DemoEdge("T07", .st4, "disconnect · delete what it read", .tap, nil, .inPlace, .pr(230)),
        DemoEdge("T07b", .st5, "where it's processed · export", .tap, nil, .inPlace, .notAvailableYet),
        DemoEdge("T08", .st2, "play today's", .tap, .jr2, .route("brief"), .planned("DEMO.app.b"), join: "D26 (NA today)"),
        DemoEdge("T09", .st9, "sign out", .tap, .ac2, .stack, .main),
        DemoEdge("T10", .ac2, "cancel", .dismiss, .st9, .stack, .main),
        DemoEdge("T11", .ac2, "sign out · send, then sign out", .tap, .ac1, .host, .planned("DEMO.app.c"), join: "D27 (live: MAIN)"),
        DemoEdge("T12", .ac2, "sending fails", .automatic, nil, .inPlace, .main),
        DemoEdge("T13", .st9, "plan rows · manage subscription ↗ · restore purchases", .tap, nil, .inPlace, .missing("Paper draws them; AccountPage has none")),
        DemoEdge("T14", .st9, "delete account", .tap, .splash, .host, .missing("P31.delete is release 0.3; no UI in the demo")),
        DemoEdge("T15", .ac1, "Sign in with Apple · Google", .tap, .shell, .host, .planned("DEMO.app.c"), join: "D28 (live: MAIN)"),
        DemoEdge("T16", .ac1, "new here? get started", .tap, .splash, .host, .pr(246), join: "D29 DEMO.app.c"),
    ]

    // MARK: outside the app (flow-coverage.md §4)

    static let outside: [DemoEdge] = [
        DemoEdge("X01", .system, "share to retrospect", .system, .ex1, .route("share"), .planned("DEMO.app.c"), join: "D30 -DemoOutside share"),
        DemoEdge("X02", .ex1, "save", .tap, .jr1, .host, .pr(220), join: "DEMO.app.c (DM-3)"),
        DemoEdge("X03", .ex1, "cancel", .dismiss, .shell, .host, .pr(220), join: "DEMO.app.c"),
        DemoEdge("X04", .system, "a notification arrives", .system, .ex3, .system, .planned("DEMO.app.c")),
        DemoEdge("X04a", .ex3, "your brief is ready", .tap, .jr2, .route("brief"), .planned("DEMO.app.c"), join: "-DemoOutside brief"),
        DemoEdge("X04b", .ex3, "a new episode", .tap, .pc2, .route("episode"), .planned("DEMO.app.c"), join: "-DemoOutside episode"),
        DemoEdge("X04c", .ex3, "a question", .tap, .yo4, .route("node"), .planned("DEMO.app.c"), join: "-DemoOutside question"),
        DemoEdge("X05", .system, "a widget on the home screen", .system, .ex4, .system, .planned("DEMO.app.c")),
        DemoEdge("X05a", .ex4, "tell me…", .tap, .jr1, .host, .planned("DEMO.app.c"), join: "-DemoOutside talk"),
        DemoEdge("X05b", .ex4, "play", .tap, .jr2, .route("brief"), .planned("DEMO.app.c")),
    ]
}
