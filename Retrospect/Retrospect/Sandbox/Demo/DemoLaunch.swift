//
//  DemoLaunch.swift
//  DEMO.app (pipeline/scopes/DEMO.app.md): the full-app demo on sample data, `-Flow demo` (debug only).
//  The demo has three stages: the first run (the core flow's own engine, unchanged), the app (the shell
//  with every group's pages), and the returning sign-in (AC-1) after a sign-out. `-DemoStart <stage>`
//  opens a stage with nothing kept; without it the demo resumes the stage it was in. Sandbox: never in
//  a release build.
//
#if DEBUG
import Foundation

/// Where the demo is: the first run, the app, or welcome back.
enum DemoStage: String, CaseIterable, Codable, Sendable {
    /// Splash to first home, on the core flow's `SampleFlowModel` and `SampleFlowHost`.
    case firstRun
    /// The shell: journal, podcasts, goals, you, and every page they open.
    case app
    /// AC-1 welcome back, after signing out.
    case returning
}

/// What the command line asked of the demo (the arguments only, never UserDefaults).
struct DemoLaunch: Equatable {
    /// `-DemoStart <stage>`: open there with nothing kept. Nil resumes (or starts at the first run).
    var start: DemoStage?
    /// `-DemoTab <tab>`: the app opens on that tab (journal by default), as if it had been tapped.
    var tab: RTab?

    static let current = parse(ProcessInfo.processInfo.arguments)

    /// An unknown stage or tab is ignored.
    static func parse(_ arguments: [String]) -> Self {
        var launch = Self()
        for (index, flag) in arguments.enumerated() {
            let value = index + 1 < arguments.endIndex ? arguments[index + 1] : nil
            switch flag {
            case "-DemoStart":
                launch.start = value.flatMap(DemoStage.init(rawValue:))
            case "-DemoTab":
                launch.tab = value.flatMap(RTab.init(rawValue:))
            default:
                continue
            }
        }
        return launch
    }
}
#endif
