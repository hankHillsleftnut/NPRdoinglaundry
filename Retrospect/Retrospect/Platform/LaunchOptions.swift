import Foundation

extension Platform {
    /// How this launch should run, from launch arguments (testing.md layers 8–9):
    ///
    ///     -Data live|sample        whose data the flows show        (default live)
    ///     -Environment production|staging|local                     (default production)
    ///     -Screen <id>             the screen launcher's page (the views half reads it)
    ///     -State <name>            the sample data's scenario
    ///     -Account fresh|day-one|month   a seeded staging account (local or staging only)
    ///
    /// Release builds read none of them: `current` is a constant there, chosen at
    /// compile time, so TestFlight and App Store builds always run live on production.
    struct LaunchOptions: Sendable, Equatable {
        enum DataSource: String, Sendable, CaseIterable {
            case live, sample
        }

        /// The seeded accounts on staging (docs/team/staging.md).
        enum Account: String, Sendable, CaseIterable {
            case fresh
            case dayOne = "day-one"
            case month
        }

        /// The arguments that take a value from a fixed list.
        enum Flag: String, Sendable, CaseIterable {
            case data = "-Data"
            case environment = "-Environment"
            case account = "-Account"
        }

        /// Something in the arguments that was ignored. Reported, never thrown:
        /// the app still launches with the default.
        enum Problem: Sendable, Equatable {
            /// The flag's value isn't one it accepts.
            case unknownValue(Flag)
            /// The flag came last, with no value after it.
            case missingValue(Flag)
            /// `-Account` on production, where there are no seeded accounts.
            case accountNeedsStaging
        }

        var dataSource: DataSource = .live
        var environment: Backend.Environment = .production
        var screen: String?
        var state: String?
        var account: Account?
        var problems: [Problem] = []

        /// Live data on production: every release launch, and a debug launch with no arguments.
        static let standard = LaunchOptions()

        /// This launch's options.
        static var current: LaunchOptions {
            #if DEBUG
            parse(ProcessInfo.processInfo.arguments)
            #else
            .standard
            #endif
        }

        /// Reads the options from `arguments` (the process's, in order). Values
        /// come from the arguments only, never from defaults, so one launch never
        /// leaks into the next.
        static func parse(_ arguments: [String]) -> LaunchOptions {
            var options = LaunchOptions()
            options.dataSource = value(.data, in: arguments, problems: &options.problems) ?? .live
            options.environment = value(.environment, in: arguments, problems: &options.problems) ?? .production
            options.account = value(.account, in: arguments, problems: &options.problems)
            if options.account != nil, options.environment == .production {
                options.account = nil
                options.problems.append(.accountNeedsStaging)
            }
            options.screen = text(after: "-Screen", in: arguments)
            options.state = text(after: "-State", in: arguments)
            return options
        }

        private static func value<Value: RawRepresentable>(_ flag: Flag, in arguments: [String], problems: inout [Problem]) -> Value?
            where Value.RawValue == String {
            guard let index = arguments.lastIndex(of: flag.rawValue) else { return nil }
            guard arguments.indices.contains(index + 1), !arguments[index + 1].hasPrefix("-") else {
                problems.append(.missingValue(flag))
                return nil
            }
            guard let value = Value(rawValue: arguments[index + 1]) else {
                problems.append(.unknownValue(flag))
                return nil
            }
            return value
        }

        private static func text(after flag: String, in arguments: [String]) -> String? {
            guard let index = arguments.lastIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            let value = arguments[index + 1]
            return value.hasPrefix("-") ? nil : value
        }
    }
}
