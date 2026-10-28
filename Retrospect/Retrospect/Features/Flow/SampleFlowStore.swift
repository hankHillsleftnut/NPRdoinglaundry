//
//  SampleFlowStore.swift
//  FLOW.host: where the sample flow keeps its place between launches (founder decision 9: resume at the
//  exact step, answers kept). Sample flow only: invented answers typed into a debug build, under the
//  flow's own key, never the live store, never logged. `-Flow sample` turns the host on;
//  `-FlowStart <step>` starts at that step with nothing kept. Debug builds only.
//
#if DEBUG
import Foundation

/// What the flow keeps: the step, and the words sent for each question (by key).
struct SampleFlowSaved: Codable, Equatable, Sendable {
    var step: FlowStep = .splash
    var answers: [String: String] = [:]
    /// The step was reached by a page's back (FLOW.edges); nil otherwise, so older saves still decode.
    var cameBack: Bool?
    /// The walk reached the end of what's built at this step (the start-over pill); nil otherwise.
    var endedAt: FlowStep?
}

@MainActor
protocol SampleFlowStore: AnyObject {
    func load() -> SampleFlowSaved?
    func save(_ saved: SampleFlowSaved)
    func clear()
}

/// The app's: one JSON value in UserDefaults under the sample flow's key.
@MainActor
final class UserDefaultsFlowStore: SampleFlowStore {
    static let key = "sampleFlow.saved"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SampleFlowSaved? {
        defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(SampleFlowSaved.self, from: $0) }
    }

    func save(_ saved: SampleFlowSaved) {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

/// The tests': in memory.
@MainActor
final class MemoryFlowStore: SampleFlowStore {
    private(set) var saved: SampleFlowSaved?
    private(set) var saves = 0

    init(_ saved: SampleFlowSaved? = nil) {
        self.saved = saved
    }

    func load() -> SampleFlowSaved? {
        saved
    }

    func save(_ saved: SampleFlowSaved) {
        self.saved = saved
        saves += 1
    }

    func clear() {
        saved = nil
    }
}

/// What the command line asked of the flow.
struct FlowLaunch: Equatable {
    /// `-Flow sample` was given.
    var isRequested = false
    /// `-FlowStart <step>`: start there with nothing kept. Nil resumes (or starts at the splash).
    var start: FlowStep?

    static let current: Self = {
        let defaults = UserDefaults.standard
        let arguments = ProcessInfo.processInfo.arguments
        let launch = resolve(arguments, environment: ProcessInfo.processInfo.environment, optedIn: defaults.bool(forKey: iconOptInKey))
        defaults.set(iconOptIn(after: arguments, was: defaults.bool(forKey: iconOptInKey)), forKey: iconOptInKey)
        return launch
    }()

    /// Set by a launch with `-Flow sample`, cleared by any other explicit `-Flow` (the plain scheme's
    /// `-Flow live`; #248's `-Flow demo` too, so a Full Demo run never opts the icon into the Core Flow walk).
    static let iconOptInKey = "sampleFlow.iconOptIn"

    /// The icon opt-in after this launch: the last explicit `-Flow` decides (as in `parse`): `sample` turns it
    /// on, any other value turns it off; a launch with no `-Flow` (the icon, a link, a notification) keeps it.
    static func iconOptIn(after arguments: [String], was optedIn: Bool) -> Bool {
        guard let flag = arguments.lastIndex(of: "-Flow") else { return optedIn }
        let value = flag + 1 < arguments.endIndex ? arguments[flag + 1] : nil
        return value == "sample"
    }

    /// FLOW.debug-launch (founder, DECISIONS 27 Oct; debug builds only, this whole file is DEBUG): a launch
    /// from the home-screen icon carries no arguments. Once this build has been run with `-Flow sample`
    /// (the `Retrospect · Core Flow` scheme), the icon opens the sample flow too, so the founder can walk the
    /// first run on his phone without Xcode. Never by default: a build that was never opted in (a fresh
    /// install, Xcode's plain scheme, a UI test's `XCUIApplication`) opens the live app whatever Xcode passes
    /// or leaves out. Any explicit argument wins: `-Flow sample` on, `-Flow` with anything else (`-Flow live`)
    /// off for that launch, any other flag (`-Screen`, `-DesignLab`, `-OldHome`) asks for something else.
    /// A test host (unit tests) never opens it.
    static func resolve(_ arguments: [String], environment: [String: String], optedIn: Bool) -> Self {
        var launch = parse(arguments)
        let flags = arguments.dropFirst().filter { $0.hasPrefix("-") }
        let testKeys = ["XCTestConfigurationFilePath", "XCTestSessionIdentifier", "XCTestBundlePath", "XCInjectBundleInto"]
        let underTest = testKeys.contains { environment[$0] != nil }
        if flags.isEmpty, optedIn, !underTest {
            launch.isRequested = true
        }
        return launch
    }

    /// Reads the arguments only (never UserDefaults). An unknown step is ignored: the flow resumes.
    static func parse(_ arguments: [String]) -> Self {
        var launch = Self()
        for (index, flag) in arguments.enumerated() {
            let value = index + 1 < arguments.endIndex ? arguments[index + 1] : nil
            switch flag {
            case "-Flow":
                launch.isRequested = value == "sample"
            case "-FlowStart":
                launch.start = value.flatMap(FlowStep.init(rawValue:))
            default:
                continue
            }
        }
        return launch
    }
}
#endif
