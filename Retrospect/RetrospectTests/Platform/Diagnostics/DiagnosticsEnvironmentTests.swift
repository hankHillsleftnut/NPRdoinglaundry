import Foundation
@testable import Retrospect
import Testing
import UIKit

@Suite(.timeLimit(.minutes(1)))
struct DiagnosticsEnvironmentTests {
    typealias Environment = Platform.Diagnostics.Environment

    private struct Report: Decodable {
        let environment: Environment
    }

    private func sources(
        info: [String: Any]? = ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"],
        os: OperatingSystemVersion = OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0),
        machine: String? = "iPhone17,1",
        locale: Locale = Locale(identifier: "en_US"),
        timeZone: TimeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt,
        contentSize: UIContentSizeCategory = .large,
        freeDiskBytes: Int64? = 8_000_000_000
    ) -> Environment.Sources {
        Environment.Sources(
            info: info, osVersion: os, machine: machine, locale: locale, timeZone: timeZone, contentSize: contentSize,
            reduceMotion: false, voiceOver: false, network: .wifi, freeDiskBytes: freeDiskBytes
        )
    }

    @Test("the snapshot from plain sources is the contract fixture's environment")
    func theSnapshotMatchesTheFixture() throws {
        let fixture = try JSONDecoder.contract.decode(Report.self, from: Fixtures.data("00", "diagnostics.request")).environment

        #expect(Environment(sources: sources()) == fixture)
    }

    @Test("the fixture's environment decodes and encodes back to the same JSON")
    func theFixtureRoundTrips() throws {
        let bytes = try Fixtures.data("00", "diagnostics.request")
        let decoded = try JSONDecoder.contract.decode(Report.self, from: bytes).environment
        let fixture = try #require(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])

        let back = try JSONSerialization.jsonObject(with: Backend.Coding.encoder.encode(decoded)) as? NSDictionary

        #expect(back == fixture["environment"] as? NSDictionary)
    }

    @Test("every string field is checked against the door's pattern; a value that fails is nil, never sent as is")
    func stringFieldsAreChecked() {
        let snapshot = Environment(sources: sources(
            info: ["CFBundleShortVersionString": "1.0-beta", "CFBundleVersion": "forty two"],
            machine: "Shaurya's iPhone",
            timeZone: TimeZone(identifier: "GMT") ?? .gmt
        ))

        #expect(snapshot.appVersion == nil)
        #expect(snapshot.build == nil)
        #expect(snapshot.deviceModel == nil)
        #expect(snapshot.timeZone == "GMT")
        #expect(Environment(sources: sources(info: nil)).appVersion == nil)
    }

    @Test("the device model is the hardware id, so the simulator's arm64 passes and a phone's name doesn't")
    func theDeviceModelIsTheHardwareID() {
        #expect(Environment(sources: sources(machine: "arm64")).deviceModel == "arm64")
        #expect(Environment(sources: sources(machine: "iPad16,3")).deviceModel == "iPad16,3")
        #expect(Environment(sources: sources(machine: "my phone")).deviceModel == nil)
        #expect(Environment(sources: sources(machine: nil)).deviceModel == nil)
    }

    @Test("the locale is languageCode_regionCode, or the language alone without a two-letter region")
    func theLocaleIsLanguageAndRegion() {
        #expect(Environment.localeCode(Locale(identifier: "en_US")) == "en_US")
        #expect(Environment.localeCode(Locale(identifier: "fr-CA")) == "fr_CA")
        #expect(Environment.localeCode(Locale(identifier: "es_419")) == "es")
        #expect(Environment.localeCode(Locale(identifier: "en")) == "en")
        #expect(Environment(sources: sources(locale: Locale(identifier: "zh_Hant_TW"))).locale == "zh_TW")
    }

    @Test("the OS version drops a zero patch and keeps a real one")
    func theOSVersionIsShort() {
        #expect(Environment(sources: sources(os: OperatingSystemVersion(majorVersion: 26, minorVersion: 1, patchVersion: 0))).osVersion == "26.1")
        #expect(Environment(sources: sources(os: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 2))).osVersion == "26.0.2")
    }

    @Test("free disk is a bucket, never the number", arguments: [
        (Int64(999_999_999), Environment.FreeDisk.under1GB),
        (1_000_000_000, .from1To5GB),
        (4_999_999_999, .from1To5GB),
        (5_000_000_000, .from5To20GB),
        (20_000_000_000, .over20GB),
    ])
    func freeDiskIsABucket(_ bytes: Int64, _ bucket: Environment.FreeDisk) {
        #expect(Environment(sources: sources(freeDiskBytes: bytes)).freeDisk == bucket)
        #expect(Environment(sources: sources(freeDiskBytes: nil)).freeDisk == nil)
    }

    @Test("every content size category the report names maps, and unspecified maps to nothing")
    func dynamicTypeMaps() {
        let categories: [UIContentSizeCategory] = [
            .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
            .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge,
        ]
        let mapped = categories.compactMap { Environment.DynamicType($0) }

        #expect(mapped == Environment.DynamicType.allCases)
        #expect(Environment.DynamicType(.unspecified) == nil)
    }

    @Test("the lists are the door's: dynamic type, network and free disk")
    func theListsAreTheDoors() {
        #expect(Environment.DynamicType.allCases.map(\.rawValue) == [
            "xSmall", "small", "medium", "large", "xLarge", "xxLarge", "xxxLarge", "ax1", "ax2", "ax3", "ax4", "ax5",
        ])
        #expect(Environment.Network.allCases.map(\.rawValue) == ["wifi", "cellular", "wired", "none", "unknown"])
        #expect(Environment.FreeDisk.allCases.map(\.rawValue) == ["under_1gb", "1_to_5gb", "5_to_20gb", "over_20gb"])
    }

    @Test("reachability feeds the network: offline is none, online is unknown (a route, not its kind), and the phone's snapshot carries it")
    @MainActor
    func reachabilityFeedsTheNetwork() {
        #expect(Environment.Network(isOnline: false) == .none)
        #expect(Environment.Network(isOnline: true) == .unknown)
        #expect(Environment(sources: .device(isOnline: false)).network == Environment.Network.none)
        #expect(Environment(sources: .device(isOnline: true)).network == .unknown)
        #expect(Environment(sources: .device).network == .unknown)
    }

    @Test("the phone's own snapshot has a model, locale and time zone that pass the door's checks")
    @MainActor
    func thePhonesSnapshotPasses() {
        let snapshot = Environment(sources: .device)

        #expect(snapshot.deviceModel != nil)
        #expect(snapshot.locale != nil)
        #expect(snapshot.timeZone != nil)
        #expect(snapshot.osVersion != nil)
        #expect(snapshot.freeDisk != nil)
    }
}
