import Foundation
import UIKit

extension Platform.Diagnostics {
    /// The device as a report describes it (DG.1's `environment`): every
    /// field is a closed value or a short identifier checked against the
    /// door's own pattern, so nothing a person typed or named can get in. A
    /// value that fails its check is nil, which the door stores as null.
    struct Environment: Codable, Equatable, Sendable {
        enum DynamicType: String, CaseIterable, Codable, Sendable {
            case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge, ax1, ax2, ax3, ax4, ax5
        }

        enum Network: String, CaseIterable, Codable, Sendable {
            case wifi, cellular, wired, none, unknown

            /// Reachability knows only whether there is a route: offline is `none`, online is `unknown` (not guessed to be wifi).
            init(isOnline: Bool) {
                self = isOnline ? .unknown : .none
            }
        }

        enum FreeDisk: String, CaseIterable, Codable, Sendable {
            case under1GB = "under_1gb"
            case from1To5GB = "1_to_5gb"
            case from5To20GB = "5_to_20gb"
            case over20GB = "over_20gb"

            init(bytes: Int64) {
                self = switch bytes {
                case ..<1_000_000_000: .under1GB
                case ..<5_000_000_000: .from1To5GB
                case ..<20_000_000_000: .from5To20GB
                default: .over20GB
                }
            }
        }

        /// `1.0`
        var appVersion: String?
        /// `42`
        var build: String?
        /// `26.0`
        var osVersion: String?
        /// `iPhone17,1` (`utsname.machine`; `arm64` on the simulator)
        var deviceModel: String?
        /// `en_US`: the language and region codes, never the full identifier.
        var locale: String?
        /// `America/Los_Angeles`
        var timeZone: String?
        var dynamicType: DynamicType?
        var reduceMotion: Bool?
        var voiceOver: Bool?
        var network: Network?
        var freeDisk: FreeDisk?

        /// The raw values a snapshot is made from, so tests can hand in their own.
        struct Sources {
            var info: [String: Any]?
            var osVersion: OperatingSystemVersion
            var machine: String?
            var locale: Locale
            var timeZone: TimeZone
            var contentSize: UIContentSizeCategory
            var reduceMotion: Bool
            var voiceOver: Bool
            /// From reachability (`Network(isOnline:)`): the phone says only whether there is a route, not what kind.
            var network: Network
            var freeDiskBytes: Int64?

            /// The phone, read now, with the network unknown. Main actor for the accessibility and content-size settings.
            @MainActor static var device: Sources {
                device(network: .unknown)
            }

            /// The phone, read now, with the network as reachability (PL1.2) last said.
            @MainActor static func device(isOnline: Bool) -> Sources {
                device(network: Network(isOnline: isOnline))
            }

            @MainActor private static func device(network: Network) -> Sources {
                Sources(
                    info: Bundle.main.infoDictionary,
                    osVersion: ProcessInfo.processInfo.operatingSystemVersion,
                    machine: machineName(),
                    locale: .current,
                    timeZone: .current,
                    contentSize: UIApplication.shared.preferredContentSizeCategory,
                    reduceMotion: UIAccessibility.isReduceMotionEnabled,
                    voiceOver: UIAccessibility.isVoiceOverRunning,
                    network: network,
                    freeDiskBytes: freeDiskBytes()
                )
            }

            /// `utsname.machine`: the hardware model id, never the person's device name.
            static func machineName() -> String? {
                var system = utsname()
                uname(&system)
                return withUnsafeBytes(of: &system.machine) { bytes in
                    String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8)
                }
            }

            static func freeDiskBytes() -> Int64? {
                let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                return values?.volumeAvailableCapacityForImportantUsage
            }
        }

        /// The snapshot from `sources`, each value checked.
        init(sources: Sources) {
            appVersion = Self.checked(sources.info?["CFBundleShortVersionString"] as? String, Self.versionPattern)
            build = Self.checked(sources.info?["CFBundleVersion"] as? String, Self.buildPattern)
            let os = sources.osVersion
            osVersion = Self.checked("\(os.majorVersion).\(os.minorVersion)\(os.patchVersion == 0 ? "" : ".\(os.patchVersion)")", Self.osPattern)
            deviceModel = Self.checked(sources.machine, Self.modelPattern)
            locale = Self.checked(Self.localeCode(sources.locale), Self.localePattern)
            timeZone = Self.checked(sources.timeZone.identifier, Self.timeZonePattern)
            dynamicType = DynamicType(sources.contentSize)
            reduceMotion = sources.reduceMotion
            voiceOver = sources.voiceOver
            network = sources.network
            freeDisk = sources.freeDiskBytes.map(FreeDisk.init(bytes:))
        }

        /// `languageCode_regionCode` (`en_US`), or the language alone when the
        /// region isn't a two-letter code.
        static func localeCode(_ locale: Locale) -> String? {
            guard let language = locale.language.languageCode?.identifier.lowercased() else { return nil }
            if let region = locale.region?.identifier.uppercased(), region.count == 2 {
                return "\(language)_\(region)"
            }
            return language
        }

        /// `value` if it matches `pattern` in full, else nil. The patterns are
        /// the door's (DG.1's `schema.ts`), so the app never sends a value the
        /// door would null.
        static func checked(_ value: String?, _ pattern: String) -> String? {
            guard let value, let regex = try? Regex(pattern), value.wholeMatch(of: regex) != nil else { return nil }
            return value
        }

        static let versionPattern = #"^\d{1,4}(\.\d{1,4}){0,2}$"#
        static let buildPattern = #"^\d{1,8}(\.\d{1,8}){0,2}$"#
        static let osPattern = #"^\d{1,3}(\.\d{1,3}){0,2}$"#
        static let modelPattern = #"^[A-Za-z]{1,16}\d{0,3}(,\d{1,3})?$"#
        static let localePattern = #"^[a-z]{2,3}(_[A-Z]{2})?$"#
        static let timeZonePattern = #"^[A-Za-z_]{1,32}(/[A-Za-z_+-]{1,32}){0,2}$"#
    }
}

extension Platform.Diagnostics.Environment.DynamicType {
    /// The report's name for a content size category; nil for one the report
    /// doesn't name (`unspecified`).
    init?(_ category: UIContentSizeCategory) {
        guard let named = Self.byCategory[category] else { return nil }
        self = named
    }

    private static let byCategory: [UIContentSizeCategory: Self] = [
        .extraSmall: .xSmall, .small: .small, .medium: .medium, .large: .large, .extraLarge: .xLarge,
        .extraExtraLarge: .xxLarge, .extraExtraExtraLarge: .xxxLarge, .accessibilityMedium: .ax1,
        .accessibilityLarge: .ax2, .accessibilityExtraLarge: .ax3, .accessibilityExtraExtraLarge: .ax4,
        .accessibilityExtraExtraExtraLarge: .ax5,
    ]
}
