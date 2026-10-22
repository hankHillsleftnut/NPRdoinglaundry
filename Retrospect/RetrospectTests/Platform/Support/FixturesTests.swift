import Foundation
import Testing

struct FixturesTests {
    @Test("a missing fixture names its path")
    func aMissingFixtureNamesItsPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let expected = root.appendingPathComponent("02/nope.json").path

        let error = #expect(throws: Fixtures.Missing.self) { try Fixtures.data("02", "nope", root: root) }

        #expect(error?.path == expected)
        #expect(error?.description.contains(expected) == true)
    }

    @Test("a fixture is read from its contract's folder")
    func aFixtureIsReadFromItsContractsFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let folder = root.appendingPathComponent("00", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let contents = Data(#"{"invented":true}"#.utf8)
        try contents.write(to: folder.appendingPathComponent("meta.json"))

        #expect(try Fixtures.data("00", "meta", root: root) == contents)
    }

    @Test("the default root is the repo's contract fixtures folder")
    func theDefaultRootIsTheReposContractFixturesFolder() {
        #expect(Fixtures.root.path.hasSuffix("/docs/team/contracts/fixtures"))
        let repo = Fixtures.root.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        #expect(FileManager.default.fileExists(atPath: repo.appendingPathComponent("docs/team/contracts").path))
    }
}
