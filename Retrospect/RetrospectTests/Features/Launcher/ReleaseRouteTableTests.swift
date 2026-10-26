import Foundation
@testable import Retrospect
import Testing

/// V2.routes-guard (plan-v2.md §1): the release app reaches the approved core-12 screens and nothing else.
/// V2 screens are merged dark: reachable from the debug launcher and the lab only. This suite fails a PR that
/// mounts one anywhere the app can reach. Two guards:
/// 1. The route tables are pinned. Every case of the release root (`NewAppRoot.Screen`), the launch table
///    (`FirstRunRoute`) and the sample flow (`FlowStep`) maps to an approved route below; a new case is a compile
///    error in the exhaustive switches here, so whoever adds one has to come and name it.
/// 2. The dark folders are fenced. No Swift file outside them (and outside the launcher and the lab) names a type
///    declared inside them, so a tab, drawer row, sheet or flow step can't open a V2 screen by the back door.
///
/// ONLY A WIRING PR EDITS THIS FILE, after the founder's go for that group (docs/team/flows/v2-dark-launch.md):
/// it adds the group's routes to `approvedRoot` / `approvedLaunch` / `approvedFlow` and takes the group's
/// folder out of `darkFolders`, quoting the founder's go in the PR body.
@Suite(.timeLimit(.minutes(1)))
struct ReleaseRouteTableTests {
    // MARK: the approved tables (core-12 + the screens built before V2)

    /// What the release root may show: PI0/AC-1, PI1/PI2, paused, the store retry, JR-1 and PX.
    static let approvedRoot: Set<String> = [
        "blank", "locked", "PI0", "PI1-PI2", "paused", "storeFailed", "JR-1", "PX",
    ]

    /// Where the launch table may send a person.
    static let approvedLaunch: Set<String> = ["blank", "PI0", "PI1", "PI2", "paused", "JR-1"]

    /// The core 12, splash to first home (SCREEN-MAP §1 first run): the only steps the sample flow may have.
    /// The core lane adds these steps one PR at a time without touching this file; a V2 step fails.
    static let approvedFlow: Set<String> = [
        "splash", "inviteGate", "youreIn", "questions", "privacy", "connect", "gettingReady", "tease", "paywall",
        "firstHome",
    ]

    /// V2 homes (plan-v2.md §3): screens built here are dark until their group's wiring PR.
    static let darkFolders = [
        "Features/Shell", "Features/Entries", "Features/Podcasts", "Features/You", "Features/Settings",
        "Features/Goals", "Features/Outside",
    ]

    /// Debug-only surfaces that may name a dark screen: the launcher (and its group registry) and the lab.
    static let allowedToNameDark = ["Features/Launcher/", "DesignSystemV2/RLabPages"]

    // MARK: guard 1: the pinned tables

    /// Exhaustive on purpose: a new release-root case doesn't compile until it is named here.
    static func route(_ screen: NewAppRoot.Screen) -> String {
        switch screen {
        case .blank: "blank"
        case .locked: "locked"
        case .signIn: "PI0"
        case .inviteGate: "PI1-PI2"
        case .paused: "paused"
        case .storeFailed: "storeFailed"
        case .journal: "JR-1"
        case .updateRequired: "PX"
        }
    }

    static func route(_ launch: FirstRunRoute) -> String {
        switch launch {
        case .blank: "blank"
        case .signIn: "PI0"
        case .inviteGate: "PI1"
        case .paused: "paused"
        case .youreIn: "PI2"
        case .journal: "JR-1"
        }
    }

    @Test("the release root shows only approved screens")
    func releaseRoot() {
        let every: [NewAppRoot.Screen] = [
            .blank, .locked, .signIn(returning: false, endedByServer: false), .signIn(returning: true, endedByServer: true),
            .inviteGate, .paused, .storeFailed, .journal, .updateRequired,
        ]
        let routes = Set(every.map(Self.route))
        #expect(routes == Self.approvedRoot, "release root routes \(routes.sorted()) != approved \(Self.approvedRoot.sorted())")
    }

    @Test("the launch table sends people only to approved screens")
    func launchTable() {
        let every: [FirstRunRoute] = [.blank, .signIn(returning: false), .signIn(returning: true), .inviteGate, .paused, .youreIn, .journal]
        let routes = Set(every.map(Self.route))
        #expect(routes == Self.approvedLaunch)
    }

    #if DEBUG
    @Test("the sample flow has only core-12 steps; every flow edge stays inside them")
    func flowSteps() {
        for step in FlowStep.allCases {
            #expect(Self.approvedFlow.contains(step.rawValue), "flow step \(step.rawValue) is not a core-12 step: that is a wiring PR")
        }
        for edge in FlowEdge.table {
            #expect(Self.approvedFlow.contains(edge.to.rawValue))
        }
    }
    #endif

    // MARK: guard 2: the fenced folders

    @Test("nothing the app can reach names a screen from a dark folder")
    func darkFoldersAreFenced() throws {
        let app = Self.appRoot
        #expect(FileManager.default.fileExists(atPath: app.appendingPathComponent("RetrospectApp.swift").path), "source tree not found at \(app.path)")
        let darkFiles = Self.darkFolders.flatMap { Self.swiftFiles(in: app.appendingPathComponent($0, isDirectory: true)) }
        let dark = Self.darkNames(in: darkFiles.map(\.text))
        let outside = Self.swiftFiles(in: app).filter { file in
            !Self.darkFolders.contains { file.path.hasPrefix($0 + "/") }
                && !Self.allowedToNameDark.contains { file.path.hasPrefix($0) }
        }
        // the walk really read the app (a wrong root would make the fence pass on nothing)
        #expect(outside.count > 100, "only \(outside.count) Swift files found under \(app.path)")
        #expect(outside.contains { $0.path == "Features/SignIn/NewAppRoot.swift" })
        var mounts: [String] = []
        for file in outside {
            let named = Self.names(in: file.text, from: dark)
            mounts += named.sorted().map { "\(file.path) names \($0)" }
        }
        #expect(mounts.isEmpty, "a dark V2 screen is reachable outside the launcher/lab (wiring PR only):\n\(mounts.joined(separator: "\n"))")
    }

    @Test("the fence itself works: mounts and back doors are caught; comments, strings and private helpers are not")
    func fenceWorks() {
        let darkFile = """
        struct PodcastsPage: View {}
        private struct Helper {}
        enum PodcastsModel {}
        @available(iOS 18, *) struct GatedPage {}
        open class OpenPage {}
        package struct PackagePage {}
        indirect enum TreePage {}
        func makePodcastsTab() -> some View { PodcastsPage() }
        private func privateHelper() {}
        extension JournalScreen {
            var podcastsRow: some View { PodcastsPage() }
            private var hiddenRow: Int { 1 }
            func nested() { let local = 1 }
        }
        extension PodcastsPage {
            var body: some View { EmptyView() }
        }
        """
        let types = Self.declaredTypes(in: darkFile)
        #expect(types == ["PodcastsPage", "PodcastsModel", "GatedPage", "OpenPage", "PackagePage", "TreePage"])
        let dark = Self.darkNames(in: [darkFile])
        // the back doors: a top-level function, and a member added to a type declared outside the fence
        #expect(dark.isSuperset(of: ["makePodcastsTab", "podcastsRow"]))
        // private helpers, locals and members of the dark types themselves stay out
        #expect(!dark.contains("privateHelper") && !dark.contains("hiddenRow") && !dark.contains("local") && !dark.contains("body"))
        #expect(Self.names(in: "case .podcasts: PodcastsPage()", from: dark) == ["PodcastsPage"])
        #expect(Self.names(in: "screen.podcastsRow", from: dark) == ["podcastsRow"])
        #expect(Self.names(in: "// later: PodcastsPage\nlet x = 1 /* PodcastsModel */", from: dark).isEmpty)
        #expect(Self.names(in: "let s = \"PodcastsPage\"", from: dark).isEmpty)
        // a "//" inside a string is not a comment: the mount after it is still seen
        #expect(Self.names(in: "let url = \"https://example.com\"; PodcastsPage()", from: dark) == ["PodcastsPage"])
        #expect(Self.names(in: "struct PodcastsPageTitle {}", from: dark).isEmpty)
    }

    // MARK: the scanner

    /// `Retrospect/Retrospect`, the app target's sources (this file is Retrospect/RetrospectTests/Features/Launcher/…).
    static let appRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Retrospect", isDirectory: true)

    /// Swift files under `folder`, with paths relative to the app root.
    static func swiftFiles(in folder: URL) -> [(path: String, text: String)] {
        let base = appRoot.standardizedFileURL.path + "/"
        let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
        var found: [(String, String)] = []
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift", let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            found.append((url.standardizedFileURL.path.replacingOccurrences(of: base, with: ""), text))
        }
        return found
    }

    /// Declaration modifiers and attributes (with or without arguments) before a declaration keyword.
    private static let modifiers =
        #"((?:@\w+(?:\([^)\n]*\))?\s+)*(?:(?:public|internal|package|open|final|private|fileprivate|nonisolated|indirect|static|class|override|mutating|nonmutating|dynamic|lazy|weak|unowned|convenience|required)\s+)*)"#

    /// The non-private type names a file declares.
    static func declaredTypes(in text: String) -> Set<String> {
        let pattern = #"(?m)^\s*"# + modifiers + #"(?:struct|class|enum|actor|protocol|typealias)\s+([A-Z]\w*)"#
        return matches(of: pattern, in: stripped(text))
    }

    /// Everything a dark folder adds that the app could reach: its non-private types, its top-level
    /// functions and values, and the members it adds to types declared outside the fence (the back door
    /// of `extension JournalScreen { var podcastsRow … }`). Members of its own types stay out (their
    /// type is already fenced, and names like `body` would match everywhere).
    static func darkNames(in texts: [String]) -> Set<String> {
        let code = texts.map(stripped)
        let types = code.reduce(into: Set<String>()) { $0.formUnion(declaredTypes(in: $1)) }
        let member = try? NSRegularExpression(pattern: #"^\s*"# + modifiers + #"(?:func|var|let)\s+(\w+)"#)
        let opener = try? NSRegularExpression(pattern: #"^\s*(?:@\w+\s+)*(?:public |internal |package )?extension\s+([A-Z]\w*)"#)
        var names = types
        for text in code {
            var depth = 0
            var outsideExtension = false
            for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
                let range = NSRange(line.startIndex..., in: line)
                if depth == 0, let open = opener?.firstMatch(in: line, range: range), let name = Range(open.range(at: 1), in: line) {
                    outsideExtension = !types.contains(String(line[name]))
                } else if depth == 0 || (depth == 1 && outsideExtension),
                          let decl = member?.firstMatch(in: line, range: range),
                          let mods = Range(decl.range(at: 1), in: line), let name = Range(decl.range(at: 2), in: line),
                          !line[mods].contains("private") {
                    names.insert(String(line[name]))
                }
                depth += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
                if depth == 0 {
                    outsideExtension = false
                }
            }
        }
        return names
    }

    private static func matches(of pattern: String, in text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var names: Set<String> = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let mods = Range(match.range(at: 1), in: text), let name = Range(match.range(at: 2), in: text) else { continue }
            if text[mods].contains("private") { continue }
            names.insert(String(text[name]))
        }
        return names
    }

    /// The code with comments and string literals blanked out (a `//` inside a string is not a comment),
    /// keeping the line breaks so line-based scans still line up.
    static func stripped(_ text: String) -> String {
        enum Mode { case code, line, block, string }
        var mode = Mode.code
        var out = ""
        var chars = Array(text)
        chars.append(" ")
        var index = 0
        while index < chars.count - 1 {
            let char = chars[index], next = chars[index + 1]
            switch mode {
            case .code:
                if char == "/", next == "/" { mode = .line; index += 1 } else if char == "/", next == "*" { mode = .block; index += 1 } else if char == "\"" { mode = .string } else { out.append(char) }
            case .line:
                if char == "\n" { mode = .code; out.append(char) }
            case .block:
                if char == "*", next == "/" { mode = .code; index += 1 } else if char == "\n" { out.append(char) }
            case .string:
                if char == "\\" { index += 1 } else if char == "\"" { mode = .code; out.append(" ") } else if char == "\n" { out.append(char) }
            }
            index += 1
        }
        return out
    }

    /// Which of `names` the code (comments and strings blanked) uses as a whole identifier.
    static func names(in text: String, from names: Set<String>) -> Set<String> {
        guard !names.isEmpty else { return [] }
        var identifiers: Set<String> = []
        var current = ""
        for character in stripped(text) + " " {
            if character.isLetter || character.isNumber || character == "_" {
                current.append(character)
            } else if !current.isEmpty {
                identifiers.insert(current)
                current = ""
            }
        }
        return names.intersection(identifiers)
    }
}
