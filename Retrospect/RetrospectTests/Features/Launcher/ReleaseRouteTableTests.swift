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
    /// `Features/Entries` holds the journal's V2 screens: JR-2 today's brief (`Entries/Brief`), JR-3 all
    /// entries (`Entries/Drawer`), JR-4 one entry (`Entries/Entry`). JR-1 stays in `Features/Journal` (core).
    static let darkFolders = [
        "Features/Shell", "Features/Entries", "Features/Podcasts", "Features/You", "Features/Settings",
        "Features/Goals", "Features/Outside",
    ]

    /// Debug-only surfaces that may name a dark screen: the launcher (and its group registry), the lab, and
    /// the sandbox (`Sandbox/`: the full-app demo, `-Flow demo`, DECISIONS 27 Oct), whose every file is
    /// DEBUG-only (`sandboxIsDebugOnly`).
    static let allowedToNameDark = ["Features/Launcher/", "DesignSystemV2/RLabPages", "Sandbox/"]

    /// The sandbox folder: test and demo hosts that never ship (founder 27 Oct, binding).
    static let sandboxFolder = "Sandbox"

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

    @Test("every sandbox file is debug-only: its code sits inside one #if DEBUG … #endif")
    func sandboxIsDebugOnly() {
        let files = Self.swiftFiles(in: Self.appRoot.appendingPathComponent(Self.sandboxFolder, isDirectory: true))
        #expect(!files.isEmpty, "no sandbox files found under \(Self.appRoot.path)/\(Self.sandboxFolder)")
        for file in files {
            #expect(Self.isDebugOnly(file.text), "\(file.path) has code outside #if DEBUG: a sandbox file would ship")
        }
    }

    @Test("the debug-only check catches code before or after the DEBUG block")
    func debugOnlyCheckWorks() {
        #expect(Self.isDebugOnly("//\n// header\n//\n#if DEBUG\nimport SwiftUI\nstruct Demo {}\n#endif\n"))
        #expect(!Self.isDebugOnly("import SwiftUI\n#if DEBUG\nstruct Demo {}\n#endif\n"))
        #expect(!Self.isDebugOnly("#if DEBUG\nstruct Demo {}\n#endif\nstruct Shipped {}\n"))
        #expect(!Self.isDebugOnly("struct Shipped {}\n"))
        #expect(!Self.isDebugOnly("#if DEBUG\nstruct Demo {}\n#endif\nstruct Shipped {}\n#if os(iOS)\n#endif\n"))
        #expect(Self.isDebugOnly("#if DEBUG\n#if os(iOS)\nstruct Demo {}\n#endif\n#endif\n"))
    }

    /// The file's only code is one `#if DEBUG` block: before it only comments and blank lines, after its
    /// closing `#endif` nothing at all.
    static func isDebugOnly(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        let code = lines.filter { !$0.isEmpty && !$0.hasPrefix("//") }
        guard code.first == "#if DEBUG", code.count > 1 else { return false }
        // the first block's own #endif must be the last line: depth reaches 0 there and nowhere before
        var depth = 0
        for (index, line) in code.enumerated() {
            if line.hasPrefix("#if") {
                depth += 1
            } else if line.hasPrefix("#endif") {
                depth -= 1
                if depth == 0 {
                    return index == code.count - 1
                }
            }
        }
        return false
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
        @available(iOS 18, *) extension JournalScreen {
            var gatedRow: some View { PodcastsPage() }
        }
        @available(iOS 18, *)
        @MainActor public extension JournalScreen {
            static func splitRow() -> some View { PodcastsPage() }
        }
        extension JournalScreen { var oneLineRow: Int { 1 } }
        private extension JournalScreen {
            var fileOnly: Int { 1 }
        }
        """
        let types = Self.declaredTypes(in: darkFile)
        #expect(types == ["PodcastsPage", "PodcastsModel", "GatedPage", "OpenPage", "PackagePage", "TreePage"])
        let dark = Self.darkNames(in: [darkFile])
        // the back doors: a top-level function, and a member added to a type declared outside the fence
        #expect(dark.isSuperset(of: ["makePodcastsTab", "podcastsRow"]))
        // ... also behind attributes with arguments, on the line before, and on the opener's own line
        #expect(dark.isSuperset(of: ["gatedRow", "splitRow", "oneLineRow"]))
        // a private extension's members can't be reached from another file
        #expect(!dark.contains("fileOnly"))
        // private helpers, locals and members of the dark types themselves stay out
        #expect(!dark.contains("privateHelper") && !dark.contains("hiddenRow") && !dark.contains("local") && !dark.contains("body"))
        #expect(Self.names(in: "case .podcasts: PodcastsPage()", from: dark) == ["PodcastsPage"])
        #expect(Self.names(in: "screen.podcastsRow", from: dark) == ["podcastsRow"])
        #expect(Self.names(in: "// later: PodcastsPage\nlet x = 1 /* PodcastsModel */", from: dark).isEmpty)
        #expect(Self.names(in: "let s = \"PodcastsPage\"", from: dark).isEmpty)
        // a "//" inside a string is not a comment: the mount after it is still seen
        #expect(Self.names(in: "let url = \"https://example.com\"; PodcastsPage()", from: dark) == ["PodcastsPage"])
        #expect(Self.names(in: "struct PodcastsPageTitle {}", from: dark).isEmpty)
        // the scanner keeps its place through every literal Swift has (a slip blanks the real code after it)
        #expect(Self.names(in: ##"let path = #"C:\"#; PodcastsPage()"##, from: dark) == ["PodcastsPage"])
        #expect(Self.names(in: ##"let s = #"PodcastsModel \(x) \" still raw"#; PodcastsPage()"##, from: dark) == ["PodcastsPage"])
        #expect(Self.names(in: ##"let s = #"\#(PodcastsPage())"#"##, from: dark) == ["PodcastsPage"])
        #expect(Self.names(in: #"let s = "a\"PodcastsModel\\"; PodcastsPage()"#, from: dark) == ["PodcastsPage"])
        #expect(Self.names(in: "let s = \"\"\"\nsay \"hi\n\"\"\"\nPodcastsPage()", from: dark) == ["PodcastsPage"])
        #expect(Self.names(in: "let s = \"\"; PodcastsPage()", from: dark) == ["PodcastsPage"])
        // an interpolation is code: a mount inside one is seen, a string inside it is not
        #expect(Self.names(in: #"Text("\(presenter.show(PodcastsPage()))")"#, from: dark) == ["PodcastsPage"])
        #expect(Self.names(in: #"let s = "\(f("PodcastsModel", (1)))"; PodcastsPage()"#, from: dark) == ["PodcastsPage"])
        // block comments nest
        #expect(Self.names(in: "/* a /* b */ PodcastsPage() */ let x = 1", from: dark).isEmpty)
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
        // attributes with arguments too (`@available(iOS 18, *) extension …`), and any access modifier
        let opener = try? NSRegularExpression(pattern: #"^\s*"# + modifiers + #"extension\s+([A-Z]\w*)[^{\n]*\{?"#)
        var names = types
        func collect(_ line: String) {
            let range = NSRange(line.startIndex..., in: line)
            guard let decl = member?.firstMatch(in: line, range: range),
                  let mods = Range(decl.range(at: 1), in: line), let name = Range(decl.range(at: 2), in: line),
                  !line[mods].contains("private") else { return }
            names.insert(String(line[name]))
        }
        for text in code {
            var depth = 0
            var outsideExtension = false
            for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
                let range = NSRange(line.startIndex..., in: line)
                if depth == 0, let open = opener?.firstMatch(in: line, range: range),
                   let mods = Range(open.range(at: 1), in: line), let name = Range(open.range(at: 2), in: line),
                   let whole = Range(open.range, in: line) {
                    // a `private extension` adds nothing another file can reach
                    outsideExtension = !types.contains(String(line[name])) && !line[mods].contains("private")
                    // a one-line `extension JournalScreen { var row … }`: the member after the brace
                    if outsideExtension, line[whole].hasSuffix("{") {
                        collect(String(line[whole.upperBound...]))
                    }
                } else if depth == 0 || (depth == 1 && outsideExtension) {
                    collect(line)
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
    /// keeping the line breaks so line-based scans still line up. It knows Swift's literals well enough not to
    /// lose its place: raw strings (`#"C:\"#`, no escapes inside), multi-line strings (a lone `"` inside them),
    /// nested block comments, and interpolations, whose contents are code (`"\(show(PodcastsPage()))"`).
    static func stripped(_ text: String) -> String {
        enum Frame {
            case code(interpolation: Bool, parens: Int)
            case string(hashes: Int, multiline: Bool)
            case block(depth: Int)
        }
        let chars = Array(text)
        var stack: [Frame] = [.code(interpolation: false, parens: 0)]
        var out = ""
        var index = 0
        func at(_ offset: Int) -> Character? {
            index + offset < chars.count ? chars[index + offset] : nil
        }
        func hashes(from start: Int) -> Int {
            var count = 0
            while start + count < chars.count, chars[start + count] == "#" { count += 1 }
            return count
        }
        while index < chars.count {
            let char = chars[index]
            switch stack[stack.count - 1] {
            case let .code(interpolation, parens):
                let pounds = hashes(from: index)
                if char == "/", at(1) == "/" {
                    while index < chars.count, chars[index] != "\n" { index += 1 }
                    continue
                } else if char == "/", at(1) == "*" {
                    stack.append(.block(depth: 1))
                    index += 2
                    continue
                } else if (char == "\"" || char == "#"), at(pounds) == "\"" {
                    let multiline = at(pounds + 1) == "\"" && at(pounds + 2) == "\""
                    stack.append(.string(hashes: pounds, multiline: multiline))
                    index += pounds + (multiline ? 3 : 1)
                    out.append(" ")
                    continue
                } else if interpolation, char == "(" {
                    stack[stack.count - 1] = .code(interpolation: true, parens: parens + 1)
                } else if interpolation, char == ")" {
                    if parens == 0 {
                        stack.removeLast()
                        out.append(" ")
                        index += 1
                        continue
                    }
                    stack[stack.count - 1] = .code(interpolation: true, parens: parens - 1)
                }
                out.append(char)
                index += 1
            case let .string(pounds, multiline):
                if char == "\\", hashes(from: index + 1) >= pounds {
                    // an escape only counts with the string's own number of `#`s after the backslash
                    if at(1 + pounds) == "(" {
                        stack.append(.code(interpolation: true, parens: 0))
                        out.append(" ")
                    }
                    index += 2 + pounds
                    continue
                }
                let closer = multiline ? 3 : 1
                if char == "\"", (0..<closer).allSatisfy({ at($0) == "\"" }), hashes(from: index + closer) >= pounds {
                    stack.removeLast()
                    out.append(" ")
                    index += closer + pounds
                    continue
                }
                if char == "\n" { out.append(char) }
                index += 1
            case let .block(depth):
                if char == "/", at(1) == "*" {
                    stack[stack.count - 1] = .block(depth: depth + 1)
                    index += 2
                } else if char == "*", at(1) == "/" {
                    stack[stack.count - 1] = .block(depth: depth - 1)
                    if depth == 1 { stack.removeLast() }
                    index += 2
                } else {
                    if char == "\n" { out.append(char) }
                    index += 1
                }
            }
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
