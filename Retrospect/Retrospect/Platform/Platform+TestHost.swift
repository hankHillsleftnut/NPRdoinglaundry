import Foundation

extension Platform {
    /// True while the app is only hosting unit tests. The app delegate and the
    /// root view check it first, so a test run starts no services, schedules
    /// nothing and draws no screens. A UI test's launched app doesn't have this
    /// variable, so UI tests still get the real app.
    static let isRunningUnitTests: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}
