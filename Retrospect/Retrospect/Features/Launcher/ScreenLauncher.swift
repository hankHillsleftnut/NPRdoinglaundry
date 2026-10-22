//
//  ScreenLauncher.swift
//  T02, the views half (docs/team/ui/T02.md): any screen in any state, from the command line.
//  `-Screen <id> -State <scenario> -Data sample|live -Appearance light|dark -ContentSize <raw>`.
//  The arguments are parsed by a pure function; the registry maps an id to a builder and each
//  flow registers its own screens from its own folder; an unknown id or state shows the list of
//  valid ones (the test's failure message) and never crashes. The app root shows
//  `ScreenLauncher` when `-Screen` is present (the integrator's one-line hook); until then the
//  design lab's "journal" page reads the same arguments. Debug and UI-test builds only.
//
#if DEBUG
import SwiftUI

/// What the command line asked for.
struct LaunchArguments: Equatable {
    enum DataSource: String {
        case sample, live
    }

    enum Appearance: String {
        case light, dark
    }

    var screen: String?
    var data: DataSource = .sample
    var state = "full"
    var appearance: Appearance?
    /// A `UIContentSizeCategory` raw value.
    var contentSize: String?
    var reduceMotion = false
    /// Flags whose values weren't understood, by name ("-Data").
    var unknown: [String] = []

    /// Reads `ProcessInfo.processInfo.arguments` only (never UserDefaults, which leak between
    /// test launches). Unknown values are reported, never thrown.
    static func parse(_ arguments: [String]) -> LaunchArguments {
        var parsed = LaunchArguments()
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let value = index + 1 < arguments.endIndex ? arguments[index + 1] : nil
            if parsed.take(flag: arguments[index], value: value) {
                index += 1
            }
            index += 1
        }
        return parsed
    }

    /// Reads one flag; true when it took the value after it.
    private mutating func take(flag: String, value: String?) -> Bool {
        switch flag {
        case "-Screen":
            screen = value
        case "-Data":
            if let value, let source = DataSource(rawValue: value) {
                data = source
            } else {
                unknown.append(flag)
            }
        case "-State":
            if let value {
                state = value
            } else {
                unknown.append(flag)
            }
        case "-Appearance":
            if let value, let appearance = Appearance(rawValue: value) {
                self.appearance = appearance
            } else {
                unknown.append(flag)
            }
        case "-ContentSize":
            contentSize = value
        case "-ReduceMotion":
            reduceMotion = value == "YES"
        default:
            return false
        }
        return true
    }

    var dynamicTypeSize: DynamicTypeSize? {
        guard let contentSize else { return nil }
        return DynamicTypeSize(UIContentSizeCategory(rawValue: contentSize))
    }
}

/// A screen the launcher can open: its builder takes the parsed arguments, and its states are
/// listed for the unknown-state page.
struct LaunchableScreen {
    let id: String
    let states: [String]
    let build: (LaunchArguments) -> AnyView
}

enum ScreenRegistry {
    /// Every registered screen, by id. Each flow adds its own in its `+Launcher.swift` file.
    static let all: [String: LaunchableScreen] = Dictionary(uniqueKeysWithValues: journalScreens.map { ($0.id, $0) })

    static func screen(_ id: String) -> LaunchableScreen? {
        all[id]
    }
}

/// The root the app shows for `-Screen`: the screen in its state, or the list of valid ones.
struct ScreenLauncher: View {
    let arguments: LaunchArguments

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.arguments = LaunchArguments.parse(arguments)
    }

    var body: some View {
        Group {
            if let screen = known {
                screen.build(arguments)
            } else {
                unknown
            }
        }
        .preferredColorScheme(arguments.appearance.map { $0 == .dark ? .dark : .light })
        .environment(\.dynamicTypeSize, arguments.dynamicTypeSize ?? DynamicTypeSize.large)
        .rReadsScreenHeight()
    }

    private var asked: String {
        let line = "asked for \(arguments.screen ?? "nothing") in state \(arguments.state)"
        return arguments.unknown.isEmpty ? line : line + "; not understood: \(arguments.unknown.joined(separator: ", "))"
    }

    /// The asked-for screen, when it exists, knows the state, and every flag was understood.
    private var known: LaunchableScreen? {
        guard let id = arguments.screen, let screen = ScreenRegistry.screen(id),
              screen.states.contains(arguments.state), arguments.unknown.isEmpty
        else {
            return nil
        }
        return screen
    }

    /// The list of valid screens and states, which is also a test's failure message.
    private var unknown: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space4) {
                Text("screen launcher").rText(.inkTitle).foregroundStyle(RColor.textPrimary)
                Text(asked)
                    .rText(.textMd)
                    .foregroundStyle(RColor.textSecondary)
                ForEach(ScreenRegistry.all.keys.sorted(), id: \.self) { id in
                    VStack(alignment: .leading, spacing: RDimension.space1) {
                        Text(id).rText(.labelMedium).foregroundStyle(RColor.textPrimary)
                        Text(ScreenRegistry.all[id]?.states.joined(separator: " · ") ?? "")
                            .rText(.metaLine)
                            .foregroundStyle(RColor.textLabel)
                    }
                }
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .background(RColor.backgroundCanvas)
        .accessibilityIdentifier("screen.unknown")
    }
}
#endif
