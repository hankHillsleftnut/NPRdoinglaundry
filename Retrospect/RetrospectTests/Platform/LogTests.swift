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

    /// Every String, Substring, Character, URL or Data anywhere inside `value`,
    /// through enums, structs, optionals and collections.
    private static func contentValues(in value: Any) -> [Any] {
        switch value {
        case is String, is Substring, is Character, is URL, is NSString, is NSURL, is Data, is NSData:
            return [value]
        default:
            return Mirror(reflecting: value).children.flatMap { contentValues(in: $0.value) }
        }
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
            case .installChecked: [.installChecked(.wipedLeftovers)]
            case .installCheckFailed: [.installCheckFailed(status: -25308)]
            }
        }
    }

    fileprivate enum Kind: CaseIterable {
        case refreshed, outbox, requestSent, unknownErrorCode, launchOptionIgnored, installChecked, installCheckFailed
    }

    fileprivate var kind: Kind {
        switch self {
        case .refreshed: .refreshed
        case .outbox: .outbox
        case .requestSent: .requestSent
        case .unknownErrorCode: .unknownErrorCode
        case .launchOptionIgnored: .launchOptionIgnored
        case .installChecked: .installChecked
        case .installCheckFailed: .installCheckFailed
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
