import Foundation
@testable import Retrospect
import Testing

struct LogTests {
    @Test("a log event has no string payload")
    func aLogEventHasNoStringPayload() {
        for event in Platform.Log.Event.everyCase {
            #expect(Self.textValues(in: event).isEmpty, "\(event) carries text")
        }
    }

    @Test("the no-text check catches a string, a URL and text nested inside a value")
    func theNoTextCheckCatchesText() {
        enum Leaky {
            case words(String)
            case link(URL)
            case nested(count: Int, inner: [Substring])
        }
        #expect(Self.textValues(in: Leaky.words("invented")).count == 1)
        #expect(Self.textValues(in: Leaky.link(URL(fileURLWithPath: "/invented"))).count == 1)
        #expect(Self.textValues(in: Leaky.nested(count: 1, inner: ["invented"])).count == 1)
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

    @Test("the system sink writes every event without failing")
    func theSystemSinkWritesEveryEvent() {
        let sink = Platform.Log.SystemSink()
        for event in Platform.Log.Event.everyCase {
            sink.record(event)
        }
    }

    /// Every String, Substring, Character or URL anywhere inside `value`.
    private static func textValues(in value: Any) -> [Any] {
        switch value {
        case is String, is Substring, is Character, is URL, is NSString, is NSURL:
            return [value]
        default:
            return Mirror(reflecting: value).children.flatMap { textValues(in: $0.value) }
        }
    }
}

extension Platform.Log.Event {
    /// One of every case. The switch in `kind` has no default, so a new case
    /// doesn't compile until it has a sample here too.
    static var everyCase: [Self] {
        Kind.allCases.map { kind in
            switch kind {
            case .refreshed: .refreshed
            case .outboxDrained: .outboxDrained(sent: 3, failed: 1)
            }
        }
    }

    fileprivate enum Kind: CaseIterable {
        case refreshed, outboxDrained
    }

    fileprivate var kind: Kind {
        switch self {
        case .refreshed: .refreshed
        case .outboxDrained: .outboxDrained
        }
    }
}
