import Foundation
@testable import Retrospect
import Testing

/// FR.b1.root: the live first run on the root. Its steps follow the one plan (`FlowPlan.edges`) restricted to
/// what is built, so there is no second route table; the flags that route into and out of it are per person,
/// erased with the store, never inherited; a relaunch resumes on the live seam's kept answers.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LiveFirstRunHostTests {
    private func settle(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0 ..< 500 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition(), "did not settle")
    }

    @Test("this bite hosts the questions only")
    func steps() {
        #expect(LiveFirstRunHost.Step.allCases == [.questions])
    }

    #if DEBUG
    @Test("the host's steps are the plan's screens after 'begin', in the plan's order, restricted to the steps built live")
    func stepsFollowThePlan() {
        let built = Set(LiveFirstRunHost.Step.allCases.map(\.rawValue))
        // the plan, walked from "you're in" along forward edges, keeping only the live steps
        var walked: [String] = []
        var at = FirstRunScreen.youreIn
        while let next = FlowPlan.edges.first(where: { $0.from == at && !$0.event.hasPrefix("back") && !$0.event.hasSuffix("Back") }) {
            at = next.to
            if built.contains(at.rawValue) {
                walked.append(at.rawValue)
            }
            if at == .firstHome {
                break
            }
        }
        #expect(walked == LiveFirstRunHost.Step.allCases.map(\.rawValue))
        #expect(FlowPlan.edges.contains { $0.from == .youreIn && $0.event == "begin" && $0.to == .questions }, "begin leads to the questions")
    }
    #endif

    @Test("the flags: begin starts the first run, leaving it marks it done; each is read back; unreadable is nil")
    func flags() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let flags = Store.PersonFlags(database: database)
        #expect(await flags.firstRun() == Store.PersonFlags.FirstRun(started: false, done: false))

        #expect(await flags.markFirstRunStarted())
        #expect(await flags.firstRun() == Store.PersonFlags.FirstRun(started: true, done: false))
        #expect(await flags.markFirstRunDone())
        #expect(await flags.firstRun() == Store.PersonFlags.FirstRun(started: true, done: true))

        await flags.close()
        #expect(await flags.firstRun() == nil)
        #expect(await flags.markFirstRunDone() == false)
    }

    @Test("sign-out mid-flow leaves nothing for the next sign-in: the flags and the kept answers are gone, the first run starts over")
    func signOutMidFlowLeavesNothing() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let environment = Platform.AppEnvironment.preview(openDatabase: { _ in database })
        await environment.sessionDidChange(to: "user-a").value
        let flags = try #require(environment.personFlags)
        #expect(await environment.markYoureInSeen())
        #expect(await flags.markFirstRunStarted())
        let seam = try #require(environment.firstRun)
        try await settle { seam.isLoaded }
        #expect(await seam.answer(.namePlace, text: "sam.", given: .typed) == .saved)

        await environment.sessionWillChange().value
        await environment.sessionDidChange(to: "user-a").value

        #expect(await environment.personFlags?.firstRun() == Store.PersonFlags.FirstRun(started: false, done: false))
        #expect(await environment.youreInSeen() == false)
        let next = try #require(environment.firstRun)
        try await settle { next.isLoaded }
        #expect(next.answeredKeys.isEmpty, "B (or A again after Log Out) starts at Q1")
    }

    @Test("a relaunch resumes: the flags and the kept answers come back for the same person, so the host opens past them")
    func relaunchResumes() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("host-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let open: @Sendable (String) throws -> Store.LocalDatabase = { try Store.LocalDatabase.onDisk(ownerUserID: $0, directory: directory) }
        let first = Platform.AppEnvironment.preview(openDatabase: open)
        await first.sessionDidChange(to: "user-a").value
        _ = await first.markYoureInSeen()
        _ = await first.personFlags?.markFirstRunStarted()
        let seam = try #require(first.firstRun)
        try await settle { seam.isLoaded }
        _ = await seam.answer(.namePlace, text: "sam.", given: .typed)
        _ = await seam.answer(.yearFromNow, text: "the seed is raised.", given: .typed)
        await first.closeStore(erasing: false) // the app dies: nothing erased

        let relaunched = Platform.AppEnvironment.preview(openDatabase: open)
        await relaunched.sessionDidChange(to: "user-a").value
        let again = try #require(relaunched.firstRun)
        try await settle { again.isLoaded }

        #expect(await relaunched.personFlags?.firstRun() == Store.PersonFlags.FirstRun(started: true, done: false))
        #expect(again.answeredKeys == [.namePlace, .yearFromNow])
        #expect(again.kept[.namePlace] == "sam.")
        // the page the host builds opens on the third question
        #expect(QuestionsModel(data: again, kept: again.kept).question?.key == .careMost)
        await relaunched.closeStore(erasing: false)
    }
}
