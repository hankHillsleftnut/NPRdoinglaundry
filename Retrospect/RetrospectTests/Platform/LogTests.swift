import Foundation
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct LogTests {
    @Test("a log event has no text or data payload")
    func aLogEventHasNoTextOrDataPayload() {
        for event in Platform.Log.Event.everyCase {
            #expect(Self.contentValues(in: event).isEmpty, "\(event) carries content")
        }
    }

    @Test("the no-content check catches text, data and URLs, also inside optionals and collections")
    func theNoContentCheckCatchesContent() {
        enum Leaky {
            case words(String)
            case link(URL)
            case bytes(Data)
            case maybe(String?)
            case nested(count: Int, inner: [Substring])
        }
        #expect(Self.contentValues(in: Leaky.words("invented")).count == 1)
        #expect(Self.contentValues(in: Leaky.link(URL(fileURLWithPath: "/invented"))).count == 1)
        #expect(Self.contentValues(in: Leaky.bytes(Data([1]))).count == 1)
        #expect(Self.contentValues(in: Leaky.maybe("invented")).count == 1)
        #expect(Self.contentValues(in: Leaky.nested(count: 1, inner: ["invented"])).count == 1)
    }

    @Test("the samples cover every kind of event, and every outbox event, once")
    func theSamplesCoverEveryKindOfEvent() {
        let kinds = Platform.Log.Event.everyCase.map(\.kind)
        #expect(Set(kinds) == Set(Platform.Log.Event.Kind.allCases))
        #expect(kinds.count == Platform.Log.Event.Kind.allCases.count - 1 + Platform.Log.Outbox.everyCase.count)
        #expect(Set(Platform.Log.Outbox.everyCase.map(\.kind)) == Set(Platform.Log.Outbox.Kind.allCases))
        #expect(Platform.Log.Outbox.everyCase.count == Platform.Log.Outbox.Kind.allCases.count)
    }

    @Test("the recorder sink records events in order")
    func theRecorderSinkRecordsEventsInOrder() {
        let recorder = Platform.Log.Recorder()
        let sink: any Platform.LogSink = recorder

        sink.record(.outbox(.drained(sent: 2, failed: 0)))
        sink.record(.refreshed)
        sink.record(.outbox(.drained(sent: 0, failed: 1)))

        #expect(recorder.events == [.outbox(.drained(sent: 2, failed: 0)), .refreshed, .outbox(.drained(sent: 0, failed: 1))])
    }

    /// A smoke test: the unified log can't be read back here, so this proves
    /// only that every case reaches a log line without trapping.
    @Test("smoke: the system sink accepts every event")
    func theSystemSinkAcceptsEveryEvent() {
        let sink = Platform.Log.SystemSink()
        for event in Platform.Log.Event.everyCase {
            sink.record(event)
        }
    }

    private static func contentValues(in value: Any) -> [Any] {
        ContentCheck.values(in: value)
    }
}

extension Platform.Log.Event {
    /// One of every case, and one of every outbox event. The switch in `kind`
    /// has no default, so a new case doesn't compile until it has a sample
    /// here too. Optional payloads are sampled non-nil, so the no-content
    /// check sees what they can hold.
    static var everyCase: [Self] {
        Kind.allCases.flatMap { kind -> [Self] in
            switch kind {
            case .refreshed: [.refreshed]
            case .outbox: Platform.Log.Outbox.everyCase.map { .outbox($0) }
            case .requestSent: [.requestSent(path: .meta, status: 200, ms: 12)]
            case .unknownErrorCode: [.unknownErrorCode(path: .meta)]
            case .launchOptionIgnored: [.launchOptionIgnored(.unknownValue(.data))]
            case .signedIn: [.signedIn(provider: .apple, isNew: true)]
            case .nonceUnavailable: [.nonceUnavailable(status: -4)]
            case .installChecked: [.installChecked(.wipedLeftovers)]
            case .installCheckFailed: [.installCheckFailed(status: -25308)]
            case .installCheckErrored: [.installCheckErrored]
            case .refreshRetried: [.refreshRetried]
            case .refreshFailed: [.refreshFailed(.timedOut)]
            case .sessionRevoked: [.sessionRevoked]
            case .signedOut: [.signedOut(reason: .revoked, serverNotified: false)]
            case .requestReplayed: [.requestReplayed(path: .meta)]
            case .keychainWriteFailed: [.keychainWriteFailed(.mirror, status: -25308)]
            case .sessionLocked: [.sessionLocked(status: -25308)]
            case .sessionNotConnected: [.sessionNotConnected]
            case .appleCredentialRevoked: [.appleCredentialRevoked]
            case .legacyRefresh: [.legacyRefresh(.refreshed)]
            case .stagingResolvedToLocal: [.stagingResolvedToLocal]
            case .inviteReceived: [.inviteReceived]
            case .inviteChecked: [.inviteChecked(.usable)]
            case .inviteTorn: [.inviteTorn(.yours)]
            case .versionFloor: [.versionFloor(.current)]
            case .versionUnreadable: [.versionUnreadable(.floor)]
            case .diagnosticsWriteFailed: [.diagnosticsWriteFailed]
            }
        }
    }

    fileprivate enum Kind: CaseIterable {
        case refreshed, outbox, requestSent, unknownErrorCode, launchOptionIgnored, signedIn, nonceUnavailable, installChecked,
             installCheckFailed, installCheckErrored, refreshRetried, refreshFailed, sessionRevoked, signedOut, requestReplayed,
             keychainWriteFailed, sessionLocked, sessionNotConnected, appleCredentialRevoked, legacyRefresh, stagingResolvedToLocal,
             inviteReceived, inviteChecked, inviteTorn, versionFloor, versionUnreadable, diagnosticsWriteFailed
    }

    fileprivate var kind: Kind {
        switch self {
        case .refreshed: .refreshed
        case .outbox: .outbox
        case .requestSent: .requestSent
        case .unknownErrorCode: .unknownErrorCode
        case .launchOptionIgnored: .launchOptionIgnored
        case .signedIn: .signedIn
        case .nonceUnavailable: .nonceUnavailable
        case .installChecked: .installChecked
        case .installCheckFailed: .installCheckFailed
        case .installCheckErrored: .installCheckErrored
        case .refreshRetried: .refreshRetried
        case .refreshFailed: .refreshFailed
        case .sessionRevoked: .sessionRevoked
        case .signedOut: .signedOut
        case .requestReplayed: .requestReplayed
        case .keychainWriteFailed: .keychainWriteFailed
        case .sessionLocked: .sessionLocked
        case .sessionNotConnected: .sessionNotConnected
        case .appleCredentialRevoked: .appleCredentialRevoked
        case .legacyRefresh: .legacyRefresh
        case .stagingResolvedToLocal: .stagingResolvedToLocal
        case .inviteReceived: .inviteReceived
        case .inviteChecked: .inviteChecked
        case .inviteTorn: .inviteTorn
        case .versionFloor: .versionFloor
        case .versionUnreadable: .versionUnreadable
        case .diagnosticsWriteFailed: .diagnosticsWriteFailed
        }
    }
}

extension Platform.Log.Outbox {
    static var everyCase: [Self] {
        Kind.allCases.map { kind in
            switch kind {
            case .enqueued: .enqueued(operation: .entryCreate)
            case .drained: .drained(sent: 3, failed: 1)
            case .sent: .sent(operation: .entryCreate, attempts: 2, ms: 340)
            case .retry: .retry(operation: .entryCreate, code: .upstreamTimeout)
            case .dead: .dead(operation: .entryCreate, code: .invalidRequest)
            case .paused: .paused(code: .offline)
            }
        }
    }

    fileprivate enum Kind: CaseIterable {
        case enqueued, drained, sent, retry, dead, paused
    }

    fileprivate var kind: Kind {
        switch self {
        case .enqueued: .enqueued
        case .drained: .drained
        case .sent: .sent
        case .retry: .retry
        case .dead: .dead
        case .paused: .paused
        }
    }
}
