import Foundation

extension Backend {
    /// An app version as the contract writes it: `1.0 (42)`, the marketing
    /// version and, in brackets, the build. Never compared as text.
    ///
    /// The floor compares **builds** (the server's rule, BE0.10: builds only
    /// go up, the marketing version can stay put across many builds);
    /// `Comparable` orders by marketing version first, then build, for
    /// "a newer version exists".
    struct AppVersion: Sendable, Equatable, Comparable, CustomStringConvertible {
        let marketing: [Int]
        let build: Int

        /// `1.0 (42)`: one to three dotted numbers, a space, and the build in
        /// brackets (a dotted build such as `42.1` counts by its first number).
        init?(_ text: String) {
            guard let match = text.wholeMatch(of: Self.pattern) else { return nil }
            let parts = match.output.1.split(separator: ".").compactMap { Int($0) }
            guard !parts.isEmpty, let build = Int(match.output.2) else { return nil }
            marketing = parts
            self.build = build
        }

        private static let pattern = /^(\d{1,4}(?:\.\d{1,4}){0,2}) \((\d{1,8})(?:\.\d{1,8}){0,2}\)$/

        /// Whether this build is below `floor`'s build: told to update.
        func isBelow(floor: AppVersion) -> Bool {
            build < floor.build
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            let count = max(lhs.marketing.count, rhs.marketing.count)
            for index in 0 ..< count {
                let left = index < lhs.marketing.count ? lhs.marketing[index] : 0
                let right = index < rhs.marketing.count ? rhs.marketing[index] : 0
                if left != right {
                    return left < right
                }
            }
            return lhs.build < rhs.build
        }

        var description: String {
            "\(marketing.map(String.init).joined(separator: ".")) (\(build))"
        }
    }
}
