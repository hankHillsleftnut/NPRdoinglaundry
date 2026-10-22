import Foundation

/// The shared contract fixtures in `docs/team/contracts/fixtures/<contract>/<name>.json`
/// (`<contract>` is the number: `00`, `02`),
/// the same files the backend's zod schemas check. Read straight from the repo:
/// the simulator runs on the Mac and can see it.
enum Fixtures {
    struct Missing: Error, CustomStringConvertible {
        let path: String
        var description: String {
            "Fixtures: no fixture at \(path)"
        }
    }

    /// The repo's `docs/team/contracts/fixtures`, found from this file's place in the repo.
    static let root: URL = .init(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Support
        .deletingLastPathComponent() // Platform
        .deletingLastPathComponent() // RetrospectTests
        .deletingLastPathComponent() // Retrospect
        .deletingLastPathComponent() // the repo
        .appendingPathComponent("docs/team/contracts/fixtures", isDirectory: true)

    /// The bytes of `<contract>/<name>.json`, or `Missing` naming the exact path.
    static func data(_ contract: String, _ name: String, root: URL = root) throws -> Data {
        let url = root.appendingPathComponent(contract, isDirectory: true).appendingPathComponent("\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else { throw Missing(path: url.path) }
        return try Data(contentsOf: url)
    }
}
