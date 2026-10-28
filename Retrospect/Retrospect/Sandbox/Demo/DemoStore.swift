//
//  DemoStore.swift
//  DEMO.app: where the demo keeps its place between launches. Everything the demo saves (its stage, and
//  the first run's step and answers through the core flow's own `UserDefaultsFlowStore`) lives in the
//  demo's own UserDefaults suite, so `-Flow demo` and `-Flow sample` (the Core Flow scheme) never move
//  each other's place. Invented answers typed into a debug build; never the live store, never logged.
//
#if DEBUG
import Foundation

@MainActor
protocol DemoStageStore: AnyObject {
    func load() -> DemoStage?
    func save(_ stage: DemoStage)
}

/// The demo's UserDefaults suite.
enum DemoDefaults {
    static let suiteName = "retrospect.demo"

    /// The suite, or nil if the system refuses it (then the demo keeps nothing between launches rather
    /// than writing into the Core Flow scheme's place).
    static func suite(named name: String = suiteName) -> UserDefaults? {
        UserDefaults(suiteName: name)
    }
}

/// The app's: the stage's name under one key in the demo's suite.
@MainActor
final class UserDefaultsDemoStore: DemoStageStore {
    static let key = "demo.stage"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> DemoStage? {
        defaults.string(forKey: Self.key).flatMap(DemoStage.init(rawValue:))
    }

    func save(_ stage: DemoStage) {
        defaults.set(stage.rawValue, forKey: Self.key)
    }
}

/// The tests', and the fallback when the suite is refused: in memory.
@MainActor
final class MemoryDemoStore: DemoStageStore {
    private(set) var saved: DemoStage?

    init(_ saved: DemoStage? = nil) {
        self.saved = saved
    }

    func load() -> DemoStage? {
        saved
    }

    func save(_ stage: DemoStage) {
        saved = stage
    }
}
#endif
