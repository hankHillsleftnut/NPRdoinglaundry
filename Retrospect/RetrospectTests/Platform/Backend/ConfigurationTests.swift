import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ConfigurationTests {
    private let info: [String: Any] = ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "42"]

    @Test("production talks to the production server")
    func productionTalksToTheProductionServer() {
        let configuration = Backend.Configuration.resolve(.production, info: info, isRelease: false)

        #expect(configuration.environment == .production)
        #expect(configuration.baseURL.absoluteString == "https://retrospect-api.onrender.com")
    }

    @Test("local talks to the backend on this Mac")
    func localTalksToTheBackendOnThisMac() {
        let configuration = Backend.Configuration.resolve(.local, info: info, isRelease: false)

        #expect(configuration.environment == .local)
        #expect(configuration.baseURL.absoluteString == "http://localhost:3000")
    }

    @Test("staging means local staging until Render staging exists")
    func stagingMeansLocalStaging() {
        let configuration = Backend.Configuration.resolve(.staging, info: info, isRelease: false)

        #expect(configuration.environment == .local)
        #expect(configuration.baseURL.absoluteString == "http://localhost:3000")
    }

    @Test("a release build resolves every environment to production", arguments: Backend.Environment.allCases)
    func aReleaseBuildResolvesToProduction(_ environment: Backend.Environment) {
        let configuration = Backend.Configuration.resolve(environment, info: info, isRelease: true)

        #expect(configuration.environment == .production)
        #expect(configuration.baseURL.absoluteString == "https://retrospect-api.onrender.com")
    }

    @Test("the app version reads as short version and build")
    func theAppVersionReadsAsShortVersionAndBuild() {
        #expect(Backend.Configuration.appVersion(from: info) == "1.0 (42)")
    }

    @Test("a bundle without a version reads 0 (0)")
    func aBundleWithoutAVersionReadsZero() {
        #expect(Backend.Configuration.appVersion(from: nil) == "0 (0)")
        #expect(Backend.Configuration.appVersion(from: ["CFBundleVersion": "7"]) == "0 (7)")
    }

    @Test("the app's own bundle has a version")
    func theAppsOwnBundleHasAVersion() {
        let version = Backend.Configuration.resolve(.production).appVersion
        #expect(version.range(of: #"^\S+ \(\S+\)$"#, options: .regularExpression) != nil)
        #expect(version != "0 (0)")
    }
}
