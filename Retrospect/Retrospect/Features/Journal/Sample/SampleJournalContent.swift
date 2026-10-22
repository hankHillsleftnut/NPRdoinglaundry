//
//  SampleJournalContent.swift
//  UI1.0: the journal's sample content. Every value contract 02's fixtures already hold is copied
//  from them exactly (SampleJournalContentTests decodes the fixtures and compares, so the two can't
//  drift); the rest is invented, lowercase and plausible, with no real person's words (contracts
//  rule 8). Every value is listed in docs/design/sample-data-ledger.md.
//
import Foundation

enum SampleJournalContent {
    typealias Journal = Flows.Journal

    // MARK: - Ids

    /// fixtures/02/entries.today.json, the typed entry.
    static let firstEntryId = "00000000-0000-4000-8000-000000000901"
    /// fixtures/02/entries.today.json, the voice entry.
    static let voiceEntryId = "00000000-0000-4000-8000-000000000902"
    /// fixtures/02/entries.today.json, the imported entry Retro hasn't read yet.
    static let waitingEntryId = "00000000-0000-4000-8000-000000000103"

    /// The day every sample sits on (the fixtures' day).
    static let today = "2026-10-21"

    // MARK: - Entries

    /// Today's thread, oldest first: the three fixture entries, then three invented ones.
    static var todayEntries: [Journal.Entry] {
        [
            // fixtures/02/entries.today.json
            Seed(
                id: "00000000-0000-4000-8000-000000000101",
                client: firstEntryId,
                kind: .typed,
                text: "dentist at 3 today, dreading it",
                at: "2026-10-21T13:02:11.410Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000102",
                client: voiceEntryId,
                kind: .voice,
                text: "walked the long way home by the canal. felt lighter after.",
                at: "2026-10-21T18:40:02.000Z",
                reading: .reading
            ).entry,
            Seed(
                id: waitingEntryId,
                client: nil,
                kind: .imported,
                text: "notes from the planning call: ship the first version friday",
                at: "2026-10-21T20:15:44.120Z",
                reading: .waiting
            ).entry,
            // invented
            Seed(
                id: "00000000-0000-4000-8000-000000000104",
                client: "00000000-0000-4000-8000-000000000903",
                kind: .typed,
                text: "lunch outside for once. twenty minutes, no phone.",
                at: "2026-10-21T20:40:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000105",
                client: "00000000-0000-4000-8000-000000000904",
                kind: .voice,
                text: "can't stop running through the friday demo in my head.",
                at: "2026-10-21T21:05:30.000Z",
                reading: .reading
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000106",
                client: "00000000-0000-4000-8000-000000000905",
                kind: .typed,
                text: "booked the next dentist visit before i could talk myself out of it",
                at: "2026-10-21T21:30:12.000Z",
                reading: .waiting
            ).entry,
        ]
    }

    /// Earlier days in the drawer (invented), newest first.
    static var earlierEntries: [Journal.Entry] {
        [
            Seed(
                id: "00000000-0000-4000-8000-000000000111",
                client: "00000000-0000-4000-8000-000000000911",
                kind: .typed,
                text: "slept badly again. the deadline is in my head before i'm awake.",
                at: "2026-10-20T07:12:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000112",
                client: "00000000-0000-4000-8000-000000000912",
                kind: .voice,
                text: "good call with sam about the launch plan",
                at: "2026-10-20T15:44:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000113",
                client: "00000000-0000-4000-8000-000000000913",
                kind: .typed,
                text: "cooked instead of ordering in. small win.",
                at: "2026-10-20T19:20:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000121",
                client: "00000000-0000-4000-8000-000000000921",
                kind: .typed,
                text: "long run by the canal this morning",
                at: "2026-10-19T08:05:00.000Z",
                reading: .read
            ).entry,
            Seed(
                id: "00000000-0000-4000-8000-000000000122",
                client: "00000000-0000-4000-8000-000000000922",
                kind: .typed,
                text: "priya's birthday dinner. stayed out later than planned.",
                at: "2026-10-19T22:31:00.000Z",
                reading: .read
            ).entry,
        ].sorted { $0.createdAt > $1.createdAt }
    }

    /// The `long` scenario's entry: about 1,200 characters of one person's evening.
    static var longEntry: Journal.Entry {
        let sentences = [
            "the day started fine and then the planning call ran over by an hour,",
            "so lunch was a sandwich at the desk again and i told myself it was only this week.",
            "by four i'd read the same paragraph of the spec three times without taking any of it in.",
            "i went for the long walk by the canal after work because that's the one thing that reliably helps,",
            "and it did, a bit: the light on the water, the man with the two old dogs who always nods.",
            "on the way back i rang my sister and we talked about nothing for twenty minutes, which was exactly right.",
            "then i got home and opened the laptop 'just to check one thing' and lost another hour.",
            "i think the pattern is that i don't stop when i'm tired, i stop when i'm empty,",
            "and those aren't the same, and the second one costs me the next morning too.",
            "tomorrow i want to close the laptop at seven and actually mean it.",
            "writing it here so someone holds me to it, even if that someone is just me reading this back.",
            "also: dentist on tuesday. still dreading it. booked it anyway.",
        ]
        return Seed(
            id: "00000000-0000-4000-8000-000000000107",
            client: "00000000-0000-4000-8000-000000000906",
            kind: .typed,
            text: sentences.joined(separator: " "),
            at: "2026-10-21T22:10:00.000Z",
            reading: .read
        ).entry
    }

    /// The `long` scenario's drawer: 60 invented entries, three a day for twenty days, newest first.
    static var sixtyEntries: [Journal.Entry] {
        let lines = [
            "short walk at lunch", "read before bed instead of scrolling", "the standup ran long again",
            "called mum on the way home", "gym, finally", "a slow morning, coffee by the window",
            "too many meetings, no real work", "cooked the soup from the weekend", "went to bed at ten",
            "the bike needs fixing before it rains", "lunch with sam", "quiet evening, nothing to report",
        ]
        let start = Date(timeIntervalSince1970: 1_792_584_000) // 2026-10-21T12:00:00Z, the fixtures' day
        return (0 ..< 60).map { index in
            let dayOffset = index / 3
            let date = start.addingTimeInterval(-Double(dayOffset) * 86400 - Double(index % 3) * 3600)
            let id = String(format: "00000000-0000-4000-8000-%012d", 1000 + index)
            return Seed(id: id, client: nil, kind: .typed, text: lines[index % lines.count], at: iso(date), reading: .read).entry
        }
    }

    // MARK: - Brief (fixtures/02/brief.latest.*.json)

    /// fixtures/02/brief.latest.v1.json: three parts, one with a why.
    static let brief = Journal.Brief(
        id: "00000000-0000-4000-8000-000000000201",
        date: today,
        kind: .brief,
        parts: [
            .init(
                text: "you've slept under seven hours four nights running.",
                why: nil,
                sources: [.init(kind: .pattern, id: "00000000-0000-4000-8000-000000000301", label: "short sleep, four nights")],
                startSeconds: nil
            ),
            .init(
                text: "the planning call is at 10. you said friday is the ship date.",
                why: "here for your goal: ship the first version",
                sources: [
                    .init(kind: .entry, id: "00000000-0000-4000-8000-000000000103", label: nil),
                    .init(kind: .fact, id: "00000000-0000-4000-8000-000000000302", label: nil),
                ],
                startSeconds: nil
            ),
            .init(
                text: "you walked by the canal again. you said it helps.",
                why: nil,
                sources: [.init(kind: .entry, id: "00000000-0000-4000-8000-000000000102", label: nil)],
                startSeconds: nil
            ),
        ],
        audio: nil,
        createdAt: Date(timeIntervalSince1970: 1_792_569_480) // 2026-10-21T07:58:00Z
    )

    /// The `long` scenario's brief: a first part long enough to fill three lines (invented).
    static var longBrief: Journal.Brief {
        var parts = brief.parts
        parts[0] = .init(
            text: "you've slept under seven hours four nights running, the planning call moved to 10, "
                + "and you said twice this week that friday is the ship date.",
            why: nil,
            sources: parts[0].sources,
            startSeconds: nil
        )
        return Journal.Brief(id: brief.id, date: brief.date, kind: brief.kind, parts: parts, audio: nil, createdAt: brief.createdAt)
    }

    /// fixtures/02/brief.latest.quiet.json: Retro's one line.
    static let quietLine = "nothing new since your last brief. i'll keep listening."

    /// 8:30 on the sample day, in the phone's own time zone (the brief's "ready by").
    static var readyBy: Date {
        var components = DateComponents()
        (components.year, components.month, components.day, components.hour, components.minute) = (2026, 10, 21, 8, 30)
        return Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    // MARK: - Guesses (fixtures/02/guesses.json)

    static func guess(_ status: Journal.Guess.Status) -> Journal.Guess {
        Journal.Guess(
            id: "00000000-0000-4000-8000-000000000401",
            question: "could the short nights be about the friday deadline?",
            framework: .init(name: "stress and sleep", source: "sleep research", wonders: "whether pressure at work shows up in your nights"),
            rationale: "the short nights started the week the ship date was set.",
            status: status,
            restsOn: [
                .init(kind: .pattern, id: "00000000-0000-4000-8000-000000000301", label: nil, text: "under seven hours, four nights running"),
                .init(kind: .entry, id: "00000000-0000-4000-8000-000000000103", label: nil, text: "ship the first version friday"),
            ]
        )
    }

    // MARK: - What Retro took (fixtures/02/took*.json)

    static let took = Journal.Took(
        items: [
            .init(kind: .fact, id: "00000000-0000-4000-8000-000000000302", text: "you have a dentist appointment on tuesdays at 3", sureness: .fairlySure),
            .init(kind: .fact, id: "00000000-0000-4000-8000-000000000303", text: "you find dentist visits stressful", sureness: .verySure),
            .init(kind: .pattern, id: "00000000-0000-4000-8000-000000000304", text: "you mention dread before appointments", sureness: .justAHunch),
        ],
        reading: .read
    )

    static let tookWaiting = Journal.Took(items: [], reading: .waiting)

    // MARK: - Corrections (fixtures/02/correction.*.json)

    static let halfMarathon = Journal.ClaimRef(kind: .fact, id: "00000000-0000-4000-8000-000000000305", text: "you're training for a half marathon")

    static let applied = Journal.CorrectionOutcome.applied(
        echo: "got it. i'll stop saying \"training for the half marathon\", and 2 things built on it.",
        target: halfMarathon,
        retired: 3
    )

    /// fixtures/02/correction.confirm.response.json
    static let confirmed = Journal.CorrectionOutcome.applied(
        echo: "got it. i'll stop saying \"training for the half marathon\".",
        target: halfMarathon,
        retired: 3
    )

    static let confirm = Journal.CorrectionOutcome.confirm(candidates: [
        .init(kind: .answer, id: "00000000-0000-4000-8000-000000000306", text: "you run to clear your head"),
        halfMarathon,
    ])

    static let askOwnWords = Journal.CorrectionOutcome.askOwnWords(
        quote: "i am going to run the half in march",
        writtenOn: "2026-09-02",
        target: halfMarathon
    )

    // MARK: - Failures (fixtures/02/error.*.json)

    static let networkFailure = Flows.Failure(.network)
    /// fixtures/02/error.internal.json's message.
    static let serverFailure = Flows.Failure(.server, message: "Something went wrong on our side.")

    // MARK: - Building entries

    /// One sample entry. Entries have no memberwise init (their identity rules live in the
    /// decoder), so a sample entry is decoded from the same JSON shape the server sends.
    struct Seed {
        let id: String
        let client: String?
        let kind: Journal.Entry.Kind
        let text: String
        /// ISO 8601, as the server sends it.
        let at: String
        let reading: Journal.Entry.Reading

        var entry: Journal.Entry {
            var json: [String: Any] = [
                "id": id, "kind": kind.rawValue, "text": text, "createdAt": at,
                "day": String(at.prefix(10)), "reading": reading.rawValue,
            ]
            json["clientEntryId"] = client
            guard let data = try? JSONSerialization.data(withJSONObject: json),
                  let entry = try? JSONDecoder.contract.decode(Journal.Entry.self, from: data)
            else {
                preconditionFailure("SampleJournalContent: entry \(id) doesn't decode")
            }
            return entry
        }
    }

    static func iso(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
}
