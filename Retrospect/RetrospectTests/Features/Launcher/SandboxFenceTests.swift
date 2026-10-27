import Foundation
@testable import Retrospect
import Testing

/// Founder, 27 Oct (DECISIONS.md): test and state screens live in a sandbox and are never in the product.
/// The sandbox is the launcher (`Features/Launcher/**`, every `*Screens+Launcher.swift`), the lab
/// (`DesignSystemV2/RLab*`, `*Lab.swift`, `*Gallery.swift`) and any `Sandbox/` or `Lab/` folder. This suite
/// fails a PR that lets any of it into a Release build:
/// 1. every sandbox file is wholly inside `#if DEBUG` (only its imports outside);
/// 2. no type named like a sandbox part (`…Gallery`, `…Lab`, `…LabPage`, `…Launch`, `…Sandbox`, `…States`,
///    `…Scenario`, `Sample…`) is declared in release code at any depth, except the sample seams that already
///    ship (`shippedSampleSeams`, pinned: the list may only shrink);
/// 3. no release code (outside `#if DEBUG`, previews included) names a type that exists only in debug builds;
/// 4. the release route tables (ReleaseRouteTableTests) list final screens only.
/// It reads the source like ReleaseRouteTableTests, so Debug-only CI still catches what only a Release
/// build would.
@Suite(.timeLimit(.minutes(1)))
struct SandboxFenceTests {
    typealias Scan = ReleaseRouteTableTests

    /// The sandbox: paths relative to the app root.
    static func isSandbox(_ path: String) -> Bool {
        let file = (path as NSString).lastPathComponent
        return path.hasPrefix("Features/Launcher/") || file.hasSuffix("+Launcher.swift")
            || path.contains("/Sandbox/") || path.hasPrefix("Sandbox/") || path.contains("/Lab/")
            || file.hasPrefix("RLab") || file.hasSuffix("Lab.swift") || file.hasSuffix("Gallery.swift")
    }

    /// A sandbox part's type name (a bare `Launch`, the platform's launch state, or HealthKit's `Sample`, is not one).
    static func isSandboxName(_ name: String) -> Bool {
        name.range(of: #"^\w+(Gallery|Lab|LabPage|Launch|Sandbox|States|Scenario)$|^Sample\w+$"#, options: .regularExpression) != nil
    }

    /// The sample seams compiled into Release today (27 Oct): the core flow's and JR-1's sample data, which
    /// live in core-12 files (FirstRun, Invite, SignIn, Player: leased). Moving them under `#if DEBUG` is a
    /// core-lane change (SampleInvite is read by InviteModel). Pinned so the list only shrinks: a new
    /// sample, scenario or states type in release code fails.
    static let shippedSampleSeams: Set<String> = [
        "FirstEpisodeScenario", "FirstRunScenario", "InviteScenario", "JournalScenario", "PlaybackScenario",
        "PrivacyScenario", "SampleFirstEpisode", "SampleFirstRunData", "SampleInvite", "SampleInviteSource",
        "SampleJournalContent", "SampleJournalData", "SamplePlayback", "SamplePrivacyReadAloud", "SampleReportSender",
        "SampleSignIn", "SampleSignInTap", "SampleSignOutFlow", "SampleTranscript", "SignInScenario",
    ]

    /// The code a Release build compiles: comments and strings blanked, `#if DEBUG` branches blanked (their
    /// `#else`/`#elseif` branches kept), line breaks kept.
    static func releaseCode(_ text: String) -> String {
        var frames: [(debug: Bool, inElse: Bool)] = []
        var lines: [String] = []
        for line in Scan.stripped(text).split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let directive = line.trimmingCharacters(in: .whitespaces)
            if directive.hasPrefix("#if") {
                // only a plain `#if DEBUG` is debug-only: `#if DEBUG || X` can be true in Release
                frames.append((directive.range(of: #"^#if\s+DEBUG\s*$"#, options: .regularExpression) != nil, false))
                lines.append("")
            } else if directive.hasPrefix("#else") || directive.hasPrefix("#elseif") {
                if !frames.isEmpty { frames[frames.count - 1].inElse = true }
                lines.append("")
            } else if directive.hasPrefix("#endif") {
                _ = frames.popLast()
                lines.append("")
            } else {
                lines.append(frames.contains { $0.debug && !$0.inElse } ? "" : line)
            }
        }
        return lines.joined(separator: "\n")
    }

    /// The file has nothing outside `#if DEBUG` but its imports.
    static func isWhollyDebug(_ text: String) -> Bool {
        releaseCode(text).split(separator: "\n").allSatisfy { line in
            let code = line.trimmingCharacters(in: .whitespaces)
            return code.isEmpty || code.hasPrefix("import ") || code.hasPrefix("@testable import ")
        }
    }

    @Test("sandbox files are wholly debug-only, and no sandbox part is declared in release code")
    func sandboxIsDebugOnly() {
        let files = Scan.swiftFiles(in: Scan.appRoot)
        #expect(files.count > 100, "only \(files.count) Swift files found")
        #expect(files.contains { $0.path == "Features/Launcher/ScreenLauncher.swift" })
        let leaking = files.filter { Self.isSandbox($0.path) && !Self.isWhollyDebug($0.text) }.map(\.path)
        #expect(leaking.isEmpty, "sandbox files with code outside #if DEBUG:\n\(leaking.sorted().joined(separator: "\n"))")
        var named: [String] = []
        var seams: Set<String> = []
        for file in files {
            let found = Scan.declaredTypes(in: Self.releaseCode(file.text), nested: true).filter(Self.isSandboxName)
            seams.formUnion(found.intersection(Self.shippedSampleSeams))
            named += found.subtracting(Self.shippedSampleSeams).sorted().map { "\(file.path): \($0)" }
        }
        #expect(named.isEmpty, "sandbox-named types in release code:\n\(named.joined(separator: "\n"))")
        // a seam moved under #if DEBUG (or deleted) comes off the list
        let gone = Self.shippedSampleSeams.subtracting(seams)
        #expect(gone.isEmpty, "no longer in release code, take off shippedSampleSeams: \(gone.sorted())")
    }

    @Test("release code never names a type that exists only in debug builds")
    func releaseNamesNoDebugType() {
        let files = Scan.swiftFiles(in: Scan.appRoot)
        let release = files.map { (path: $0.path, code: Self.releaseCode($0.text)) }
        let releaseTypes = release.reduce(into: Set<String>()) { $0.formUnion(Scan.declaredTypes(in: $1.code)) }
        let debugOnly = files.reduce(into: Set<String>()) { $0.formUnion(Scan.declaredTypes(in: $1.text)) }
            .subtracting(releaseTypes)
        #expect(debugOnly.contains("ScreenLauncher"), "the scan found no debug-only types")
        var uses: [String] = []
        for file in release {
            uses += Scan.names(in: file.code, from: debugOnly).sorted().map { "\(file.path) names \($0)" }
        }
        #expect(uses.isEmpty, "release code names debug-only types (a Release build would not compile, or would ship it):\n\(uses.joined(separator: "\n"))")
    }

    @Test("the release route tables list final screens only")
    func routesAreFinalScreens() {
        let routes = Scan.approvedRoot.union(Scan.approvedLaunch).union(Scan.approvedFlow)
        for route in routes {
            #expect(
                route.range(of: "lab|sandbox|sample|launcher|gallery|state|test|debug", options: [.regularExpression, .caseInsensitive]) == nil,
                "route \(route) is not a final screen"
            )
        }
    }

    @Test("the sandbox fence itself works")
    func fenceWorks() {
        // #if DEBUG is blanked, its #else kept, nesting followed
        let mixed = "#if DEBUG\nstruct A {}\n#else\nstruct B {}\n#endif\nstruct C {}\n#if DEBUG\n#if os(iOS)\nstruct D {}\n#endif\nstruct E {}\n#endif"
        #expect(Scan.declaredTypes(in: Self.releaseCode(mixed)) == ["B", "C"])
        #expect(Scan.declaredTypes(in: Self.releaseCode("#if !DEBUG\nstruct F {}\n#endif")) == ["F"])
        #expect(Scan.declaredTypes(in: Self.releaseCode("#if DEBUG || targetEnvironment(simulator)\nstruct G {}\n#endif")) == ["G"])
        #expect(Scan.declaredTypes(in: Self.releaseCode("#if DEBUG && os(iOS)\nstruct H {}\n#endif")) == ["H"])
        // wholly debug-only, or not
        #expect(Self.isWhollyDebug("import SwiftUI\n#if DEBUG\nstruct XLab {}\n#endif\n"))
        #expect(Self.isWhollyDebug("// a comment\nimport SwiftUI\n#if DEBUG\n#Preview { XLab() }\n#endif"))
        #expect(!Self.isWhollyDebug("import SwiftUI\nstruct XLab {}"))
        #expect(!Self.isWhollyDebug("#if DEBUG\nstruct XLab {}\n#endif\nstruct Leak {}"))
        #expect(!Self.isWhollyDebug("#if DEBUG\n#else\nstruct Shipped {}\n#endif"))
        #expect(!Self.isWhollyDebug("#Preview { XLab() }"))
        // sandbox paths and names
        #expect(Self.isSandbox("Features/Launcher/ScreenLauncher.swift") && Self.isSandbox("Features/You/YouScreens+Launcher.swift"))
        #expect(Self.isSandbox("DesignSystemV2/RLabPages.swift") && Self.isSandbox("DesignSystemV2/RFoundationGallery.swift"))
        #expect(Self.isSandbox("Features/You/Sandbox/States.swift") && Self.isSandbox("Features/You/Lab/Rows.swift"))
        #expect(!Self.isSandbox("Features/Journal/JournalPage/JournalPage.swift") && !Self.isSandbox("Platform/Launch.swift"))
        #expect(Self.isSandboxName("JournalLaunch") && Self.isSandboxName("RTabBarGallery") && Self.isSandboxName("RMotionLab"))
        #expect(Self.isSandboxName("ShellStates") && Self.isSandboxName("ShellScenario") && Self.isSandboxName("SampleShellData"))
        #expect(!Self.isSandboxName("Launch") && !Self.isSandboxName("Label") && !Self.isSandboxName("Gallery") && !Self.isSandboxName("Sample"))
        #expect(!Self.isSandboxName("SignOutState") && !Self.isSandboxName("Statement"))
        // a sandbox part nested inside a release type is still found
        let nestedPart = Scan.declaredTypes(in: Self.releaseCode("struct Page {\n    struct PageGallery {}\n}"), nested: true)
        #expect(nestedPart.filter(Self.isSandboxName) == ["PageGallery"])
        // a release reference to a debug-only type is seen; the same reference inside #if DEBUG is not
        #expect(Scan.names(in: Self.releaseCode("let v = JournalLaunch()"), from: ["JournalLaunch"]) == ["JournalLaunch"])
        #expect(Scan.names(in: Self.releaseCode("#if DEBUG\nlet v = JournalLaunch()\n#endif"), from: ["JournalLaunch"]).isEmpty)
        #expect(Scan.names(in: Self.releaseCode("#Preview { JournalLaunch() }"), from: ["JournalLaunch"]) == ["JournalLaunch"])
    }
}
