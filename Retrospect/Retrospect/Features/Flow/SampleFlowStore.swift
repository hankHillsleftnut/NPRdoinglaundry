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
        let launch = resolve(
            ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
            optedIn: defaults.bool(forKey: iconOptInKey)
        )
        // an explicit `-Flow sample` launch (the Core Flow scheme) is the opt-in the icon follows later
        if parse(ProcessInfo.processInfo.arguments).isRequested {
            defaults.set(true, forKey: iconOptInKey)
        }
        return launch
    }()

    /// Set once this build was launched with `-Flow sample`; removing the app clears it.
    static let iconOptInKey = "sampleFlow.iconOptIn"

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
