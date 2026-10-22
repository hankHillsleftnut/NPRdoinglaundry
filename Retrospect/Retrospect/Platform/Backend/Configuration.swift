import Foundation

extension Backend {
    /// Which backend the app talks to.
    enum Environment: String, Sendable, CaseIterable {
        case production, staging, local
    }

    /// Where requests go and who's asking. Built once at launch.
    struct Configuration: Sendable, Equatable {
        let environment: Backend.Environment
        let baseURL: URL
        /// `CFBundleShortVersionString (CFBundleVersion)`, e.g. `1.0 (42)`: sent as `X-App-Version`.
        let appVersion: String

        /// The configuration for `environment`, with the version read from `info`
        /// (the app's Info.plist by default).
        ///
        /// Release builds always resolve to production, whatever they're asked: the
        /// flag is a compile-time constant, so no launch argument or setting can
        /// point a TestFlight or App Store build anywhere else.
        static func resolve(_ environment: Backend.Environment, info: [String: Any]? = Bundle.main.infoDictionary) -> Configuration {
            #if DEBUG
            resolve(environment, info: info, isRelease: false)
            #else
            resolve(environment, info: info, isRelease: true)
            #endif
        }

        /// `resolve(_:info:)` with the build kind passed in, so tests can check the release rule.
        static func resolve(_ environment: Backend.Environment, info: [String: Any]?, isRelease: Bool) -> Configuration {
            let target = isRelease ? Backend.Environment.production : environment.resolved
            return Configuration(environment: target, baseURL: target.baseURL, appVersion: appVersion(from: info))
        }

        /// `1.0 (42)`. A bundle without a version reads `0 (0)`, which the server
        /// treats as too old rather than guessing.
        static func appVersion(from info: [String: Any]?) -> String {
            let short = info?["CFBundleShortVersionString"] as? String ?? "0"
            let build = info?["CFBundleVersion"] as? String ?? "0"
            return "\(short) (\(build))"
        }
    }
}

extension Backend.Environment {
    /// Render staging doesn't exist yet, so `staging` means local staging on the
    /// Mac (docs/team/staging.md) until it does.
    var resolved: Backend.Environment {
        self == .staging ? .local : self
    }

    /// The server for this environment. `local` is the backend on this Mac,
    /// which the simulator reaches as localhost.
    var baseURL: URL {
        switch resolved {
        case .production, .staging: URL(string: "https://retrospect-api.onrender.com") ?? URL(fileURLWithPath: "/")
        case .local: URL(string: "http://localhost:3000") ?? URL(fileURLWithPath: "/")
        }
    }
}
