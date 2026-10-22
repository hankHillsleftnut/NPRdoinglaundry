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

    @Test("the samples cover every kind of event, once")
    func theSamplesCoverEveryKindOfEvent() {
        let kinds = Platform.Log.Event.everyCase.map(\.kind)
        #expect(kinds.count == Platform.Log.Event.Kind.allCases.count)
        #expect(Set(kinds) == Set(Platform.Log.Event.Kind.allCases))
    }

    @Test("the recorder sink records events in order")
    func theRecorderSinkRecordsEventsInOrder() {
        let recorder = Platform.Log.Recorder()
        let sink: any Platform.LogSink = recorder

        sink.record(.outboxDrained(sent: 2, failed: 0))
        sink.record(.refreshed)
        sink.record(.outboxDrained(sent: 0, failed: 1))

        #expect(recorder.events == [.outboxDrained(sent: 2, failed: 0), .refreshed, .outboxDrained(sent: 0, failed: 1)])
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
    /// One of every case. The switch in `kind` has no default, so a new case
    /// doesn't compile until it has a sample here too. Optional payloads are
    /// sampled non-nil, so the no-content check sees what they can hold.
    static var everyCase: [Self] {
        Kind.allCases.map { kind in
            switch kind {
            case .refreshed: .refreshed
            case .outboxDrained: .outboxDrained(sent: 3, failed: 1)
            case .requestSent: .requestSent(path: .meta, status: 200, ms: 12)
            case .unknownErrorCode: .unknownErrorCode(path: .meta)
            case .launchOptionIgnored: .launchOptionIgnored(.unknownValue(.data))
            case .installChecked: .installChecked(.wipedLeftovers)
            case .installCheckFailed: .installCheckFailed(status: -25308)
            case .diagnosticsWriteFailed: .diagnosticsWriteFailed
            }
        }
    }

    fileprivate enum Kind: CaseIterable {
        case refreshed, outboxDrained, requestSent, unknownErrorCode, launchOptionIgnored, installChecked, installCheckFailed, diagnosticsWriteFailed
    }

    fileprivate var kind: Kind {
        switch self {
        case .refreshed: .refreshed
        case .outboxDrained: .outboxDrained
        case .requestSent: .requestSent
        case .unknownErrorCode: .unknownErrorCode
        case .launchOptionIgnored: .launchOptionIgnored
        case .installChecked: .installChecked
        case .installCheckFailed: .installCheckFailed
        case .diagnosticsWriteFailed: .diagnosticsWriteFailed
        }
    }
}
