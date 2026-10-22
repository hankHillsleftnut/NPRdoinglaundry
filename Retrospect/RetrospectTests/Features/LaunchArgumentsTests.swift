@testable import Retrospect
import Testing

/// T02: the launch arguments are parsed into screen, data, state, appearance and size; unknown
/// values are reported, never thrown; a missing `-Data` means sample.
struct LaunchArgumentsTests {
    @Test("every flag is read")
    func allFlags() {
        let parsed = LaunchArguments.parse(["app", "-Screen", "journal", "-Data", "sample", "-State", "offline", "-Appearance", "dark", "-ContentSize", "UICTContentSizeCategoryAccessibilityXL", "-ReduceMotion", "YES"])
        #expect(parsed.screen == "journal")
        #expect(parsed.data == .sample)
        #expect(parsed.state == "offline")
        #expect(parsed.appearance == .dark)
        #expect(parsed.contentSize == "UICTContentSizeCategoryAccessibilityXL")
        #expect(parsed.dynamicTypeSize == .accessibility3)
        #expect(parsed.reduceMotion)
        #expect(parsed.unknown.isEmpty)
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
