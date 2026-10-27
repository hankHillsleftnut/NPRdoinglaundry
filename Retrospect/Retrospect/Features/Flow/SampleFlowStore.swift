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
    /// `-Flow sample` was given (or `-Flow demo`: the demo is a sample flow to the app root).
    var isRequested = false
    /// `-Flow demo` (DEMO.app): the whole app on sample data, from `Sandbox/Demo`.
    var isDemo = false
    /// `-FlowStart <step>`: start there with nothing kept. Nil resumes (or starts at the splash).
    var start: FlowStep?

    static let current = parse(ProcessInfo.processInfo.arguments)

    /// Reads the arguments only (never UserDefaults). An unknown step is ignored: the flow resumes.
    static func parse(_ arguments: [String]) -> Self {
        var launch = Self()
        for (index, flag) in arguments.enumerated() {
            let value = index + 1 < arguments.endIndex ? arguments[index + 1] : nil
            switch flag {
            case "-Flow":
                launch.isRequested = value == "sample" || value == "demo"
                launch.isDemo = value == "demo"
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
