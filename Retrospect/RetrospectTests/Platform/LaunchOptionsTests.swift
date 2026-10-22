@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct LaunchOptionsTests {
    @Test("no arguments means live data on production")
    func noArgumentsMeansLiveDataOnProduction() {
        let options = Platform.LaunchOptions.parse(["Retrospect"])

        #expect(options == .standard)
        #expect(options.dataSource == .live)
        #expect(options.environment == .production)
        #expect(options.screen == nil && options.state == nil && options.account == nil)
        #expect(options.problems.isEmpty)
    }

    @Test("-Data sample -State offline is parsed")
    func dataSampleStateOfflineIsParsed() {
        let options = Platform.LaunchOptions.parse(["Retrospect", "-Data", "sample", "-State", "offline"])

        #expect(options.dataSource == .sample)
        #expect(options.state == "offline")
        #expect(options.problems.isEmpty)
    }

    @Test("a full staging launch is parsed")
    func aFullStagingLaunchIsParsed() {
        let options = Platform.LaunchOptions.parse([
            "Retrospect", "-Screen", "JR-1", "-Data", "live", "-Environment", "local", "-Account", "day-one", "-State", "full",
        ])

        #expect(options.screen == "JR-1")
        #expect(options.dataSource == .live)
        #expect(options.environment == .local)
        #expect(options.account == .dayOne)
        #expect(options.state == "full")
        #expect(options.problems.isEmpty)
    }

    @Test("a -Screen or -State value longer than 64 characters is ignored and reported", arguments: Platform.LaunchOptions.TextFlag.allCases)
    func aLongTextValueIsIgnored(_ flag: Platform.LaunchOptions.TextFlag) {
        let longest = String(repeating: "a", count: 64)

        let kept = Platform.LaunchOptions.parse(["Retrospect", flag.rawValue, longest])
        let dropped = Platform.LaunchOptions.parse(["Retrospect", flag.rawValue, longest + "a"])

        #expect((flag == .screen ? kept.screen : kept.state) == longest)
        #expect(kept.problems.isEmpty)
        #expect(dropped.screen == nil && dropped.state == nil)
        #expect(dropped.problems == [.tooLong(flag)])
    }

    @Test("an unknown value falls back to the default and is reported", arguments: [
        (["-Data", "fake"], Platform.LaunchOptions.Problem.unknownValue(.data)),
        (["-Environment", "moon"], .unknownValue(.environment)),
        (["-Environment", "local", "-Account", "year"], .unknownValue(.account)),
    ])
    func anUnknownValueFallsBackToTheDefault(_ arguments: [String], _ problem: Platform.LaunchOptions.Problem) {
        let options = Platform.LaunchOptions.parse(["Retrospect"] + arguments)

        #expect(options.dataSource == .live)
        #expect(options.environment == (arguments.contains("local") ? .local : .production))
        #expect(options.account == nil)
        #expect(options.problems == [problem])
    }

    @Test("a flag with no value is reported, and the next flag still counts")
    func aFlagWithNoValueIsReported() {
        let options = Platform.LaunchOptions.parse(["Retrospect", "-Data", "-Environment", "local"])

        #expect(options.dataSource == .live)
        #expect(options.environment == .local)
        #expect(options.problems == [.missingValue(.data)])
    }

    @Test("a seeded account needs local or staging")
    func aSeededAccountNeedsLocalOrStaging() {
        let options = Platform.LaunchOptions.parse(["Retrospect", "-Account", "month"])

        #expect(options.account == nil)
        #expect(options.problems == [.accountNeedsStaging])
    }

    @Test("the last of a repeated flag wins")
    func theLastOfARepeatedFlagWins() {
        let options = Platform.LaunchOptions.parse(["Retrospect", "-Data", "sample", "-Data", "live"])
        #expect(options.dataSource == .live)
    }

    @Test("a release build ignores every option")
    func aReleaseBuildIgnoresEveryOption() {
        // `current` is `.standard` in a release build (compile-time); what it then
        // resolves to on the server side is checked by ConfigurationTests'
        // release case. Here: the constant itself is live on production.
        #expect(Platform.LaunchOptions.standard.dataSource == .live)
        #expect(Platform.LaunchOptions.standard.environment == .production)
        #expect(Backend.Configuration.resolve(Platform.LaunchOptions.standard.environment, info: nil, isRelease: true).environment == .production)
    }

    @Test("this test run has no launch options")
    func thisTestRunHasNoLaunchOptions() {
        #expect(Platform.LaunchOptions.current.problems.isEmpty)
        #expect(Platform.LaunchOptions.current.environment == .production)
    }
}
