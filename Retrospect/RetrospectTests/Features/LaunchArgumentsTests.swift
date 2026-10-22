@testable import Retrospect
import Testing

/// T02: the launch arguments are parsed into screen, data, state, appearance and size; unknown
/// values are reported, never thrown; a missing `-Data` means sample.
struct LaunchArgumentsTests {
    @Test("every flag is read")
    func allFlags() {
        let parsed = LaunchArguments.parse([
            "app",
            "-Screen",
            "journal",
            "-Data",
            "sample",
            "-State",
            "offline",
            "-Appearance",
            "dark",
            "-ContentSize",
            "UICTContentSizeCategoryAccessibilityXL",
        ])
        #expect(parsed.screen == "journal")
        #expect(parsed.data == .sample)
        #expect(parsed.state == "offline")
        #expect(parsed.appearance == .dark)
        #expect(parsed.contentSize == "UICTContentSizeCategoryAccessibilityXL")
        #expect(parsed.dynamicTypeSize == .accessibility3)
        #expect(parsed.unknown.isEmpty)
    }

    @Test("what the launcher can't honour is reported, not ignored")
    func cannotHonour() {
        #expect(LaunchArguments.parse(["app", "-Data", "live"]).unknown == ["-Data"])
        #expect(LaunchArguments.parse(["app", "-ReduceMotion", "YES"]).unknown == ["-ReduceMotion"])
        #expect(LaunchArguments.parse(["app", "-ReduceMotion", "NO"]).unknown.isEmpty)
        #expect(LaunchArguments.parse(["app", "-ContentSize", "huge"]).unknown == ["-ContentSize"])
        #expect(LaunchArguments.parse(["app", "-ContentSize", "huge"]).contentSize == nil)
    }

    @Test("screen ids are unique across every flow")
    func uniqueIDs() {
        #expect(Set(ScreenRegistry.allIDs).count == ScreenRegistry.allIDs.count)
        #expect(ScreenRegistry.all.count == ScreenRegistry.allIDs.count)
    }

    @Test("a missing -Data means sample, a missing -State means full")
    func defaults() {
        let parsed = LaunchArguments.parse(["app", "-Screen", "journal"])
        #expect(parsed.data == .sample)
        #expect(parsed.state == "full")
        #expect(parsed.appearance == nil)
    }

    @Test("unknown values are reported, never thrown")
    func unknownValues() {
        let parsed = LaunchArguments.parse(["app", "-Data", "nope", "-Appearance", "sepia"])
        #expect(parsed.unknown == ["-Data", "-Appearance"])
        #expect(parsed.data == .sample)
    }

    @Test("without -Screen there is no screen, so the normal app shows")
    func noScreen() {
        #expect(LaunchArguments.parse(["app", "-DesignLab"]).screen == nil)
    }

    @Test("the journal is registered with every scenario")
    func journalRegistered() {
        let screen = ScreenRegistry.screen("journal")
        #expect(screen != nil)
        #expect(screen?.states.contains("error.network") == true)
        #expect(screen?.states.count == JournalScenario.allCases.count)
    }
}
