import Foundation
@testable import Retrospect
import Testing

/// PL7.1: what the app tells Apple is true. The manifests are read from the source tree and the built app, and
/// checked against the code: every required-reason API the shipped code calls has its category with a reason that
/// is true for the call, nothing is declared that the code does not use, and the data types are the list the new
/// backend receives.
@Suite(.timeLimit(.minutes(1)))
struct PrivacyManifestTests {
    private static let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let appRoot = projectRoot.appendingPathComponent("Retrospect", isDirectory: true)
    private static let reportRoot = projectRoot.appendingPathComponent("ScreenTimeReport", isDirectory: true)

    /// The data the Beta 1 build sends to the new backend (contract 00/02): adding one means touching this list and the PR body.
    private static let expectedData: Set<String> = [
        "NSPrivacyCollectedDataTypeName", "NSPrivacyCollectedDataTypeEmailAddress", "NSPrivacyCollectedDataTypeUserID",
        "NSPrivacyCollectedDataTypeOtherUserContent", "NSPrivacyCollectedDataTypeCrashData",
        "NSPrivacyCollectedDataTypePerformanceData", "NSPrivacyCollectedDataTypeOtherDiagnosticData",
    ]

    private func manifest(in folder: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: folder.appendingPathComponent("PrivacyInfo.xcprivacy"))
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func declared(in folder: URL) throws -> [String: Set<String>] {
        let types = try #require(try manifest(in: folder)["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        return Dictionary(uniqueKeysWithValues: types.compactMap { entry in
            (entry["NSPrivacyAccessedAPIType"] as? String).map { ($0, Set(entry["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? [])) }
        })
    }

    private func sources(in folder: URL) -> [(name: String, text: String)] {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
        var found: [(String, String)] = []
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift", let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            found.append((url.lastPathComponent, text))
        }
        return found
    }

    private func uses(_ needles: [String], in folder: URL) -> Bool {
        sources(in: folder).contains { file in needles.contains(where: file.text.contains) }
    }

    /// The real signals for each category. File timestamps are the date keys and `stat`-family calls, not `attributesOfItem` reading `.size`.
    private static let signals: [(category: String, needles: [String])] = [
        ("NSPrivacyAccessedAPICategoryUserDefaults", ["UserDefaults"]),
        ("NSPrivacyAccessedAPICategorySystemBootTime", ["systemUptime", "mach_absolute_time"]),
        ("NSPrivacyAccessedAPICategoryDiskSpace", ["volumeAvailableCapacity", "attributesOfFileSystem", "NSFileSystemFreeSize", "statfs"]),
        ("NSPrivacyAccessedAPICategoryFileTimestamp", [
            "NSFileCreationDate", "NSFileModificationDate", ".contentModificationDateKey", ".creationDateKey", ".contentAccessDateKey",
            "fileModificationDate", "getattrlist", "fstat(", "lstat(", " stat(",
        ]),
    ]

    @Test("the manifests are in the built app: the app's own, and the Screen Time extension's inside its bundle")
    func manifestsAreInTheBuiltApp() {
        #expect(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil, "the app bundles its manifest")
        // ExtensionKit extensions are embedded under Extensions/, not PlugIns/
        let report = Bundle.main.bundleURL.appendingPathComponent("Extensions/ScreenTimeReport.appex")
        #expect(Bundle(url: report)?.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil, "the extension bundles its own")
    }

    @Test("the app and the extension do not track and name no tracking domains")
    func noTracking() throws {
        for folder in [Self.appRoot, Self.reportRoot] {
            let manifest = try manifest(in: folder)
            #expect(manifest["NSPrivacyTracking"] as? Bool == false)
            #expect((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        }
    }

    @Test("every required-reason API the code calls has its category and a reason; nothing is declared that is not called")
    func declarationsMatchTheCode() throws {
        for (folder, name) in [(Self.appRoot, "app"), (Self.reportRoot, "ScreenTimeReport")] {
            let declared = try declared(in: folder)
            for signal in Self.signals {
                let used = uses(signal.needles, in: folder)
                if used {
                    #expect(declared[signal.category]?.isEmpty == false, "\(name): \(signal.category) is called but not declared")
                }
                if !used {
                    #expect(declared[signal.category] == nil, "\(name): \(signal.category) is declared but not called")
                }
            }
        }
    }

    @Test("a shared App Group defaults suite declares 1C8F.1, in the app and in the extension that reads it")
    func appGroupDefaultsReason() throws {
        for folder in [Self.appRoot, Self.reportRoot] {
            #expect(uses(["UserDefaults(suiteName:"], in: folder))
            #expect(try declared(in: folder)["NSPrivacyAccessedAPICategoryUserDefaults"]?.contains("1C8F.1") == true)
        }
        #expect(try declared(in: Self.appRoot)["NSPrivacyAccessedAPICategoryUserDefaults"]?.contains("CA92.1") == true)
    }

    @Test("the collected data is exactly what the new backend receives, each linked, not tracking, for app functionality")
    func collectedData() throws {
        let collected = try #require(try manifest(in: Self.appRoot)["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        #expect(Set(collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }) == Self.expectedData)
        for entry in collected {
            #expect(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool == true)
            #expect(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool == false)
            #expect(entry["NSPrivacyCollectedDataTypePurposes"] as? [String] == ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
        }
    }

    @Test("disk space is read only for a report the person sends: the device snapshot is built nowhere else (what makes 7D9E.1 true)")
    func diskSpaceOnlyInReports() {
        let allowed: Set = ["Environment.swift", "AppEnvironment.swift", "ReportBuilder.swift"]
        let callers = sources(in: Self.appRoot.appendingPathComponent("Platform"))
            .filter { $0.text.contains("Sources.device") || $0.text.contains("sources: .device") || $0.text.contains("freeDiskBytes()") }
            .map(\.name)
        #expect(Set(callers).isSubset(of: allowed), "\(callers)")
        let launch = sources(in: Self.appRoot).filter { $0.name == "RetrospectApp.swift" }
        #expect(launch.allSatisfy { !$0.text.contains("freeDiskBytes") && !$0.text.contains("Sources.device") })
    }
}
