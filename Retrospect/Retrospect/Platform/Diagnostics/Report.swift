import Foundation

extension Platform.Diagnostics {
    /// One report, exactly as `POST /v2/diagnostics` takes it (DG.1's
    /// `DiagnosticsReport`, strict: every key present, unknown keys refused).
    /// Everything but `note` is ids from closed lists, counts and times; the
    /// note is the one free text, written to us on purpose and labelled so.
    struct Report: Codable, Equatable, Sendable {
        /// Lowercase UUID; also the request's `Idempotency-Key`.
        let reportId: String
        let createdAt: Date
        /// "what happened?", trimmed, at most `maxNoteCharacters`; null when empty.
        let note: String?
        let environment: Environment
        let account: Account
        let events: [Stamped<Event>]
        let network: [Stamped<Request>]
        let outbox: OutboxSummary
        let failures: [Stamped<Failure>]
        let performance: Performance
        let crashes: [Stamped<Crash>]

        /// The door's limit, in UTF-16 units (see `cut`).
        static let maxNoteCharacters = 1000

        init(
            reportID: UUID,
            createdAt: Date,
            note: String?,
            environment: Environment,
            account: Account,
            events: [Stamped<Event>],
            network: [Stamped<Request>],
            outbox: OutboxSummary,
            failures: [Stamped<Failure>],
            performance: Performance,
            crashes: [Stamped<Crash>]
        ) {
            reportId = reportID.uuidString.lowercased()
            self.createdAt = createdAt
            self.note = Self.cleaned(note)
            self.environment = environment
            self.account = account
            self.events = Array(events.suffix(Ring.events.cap))
            self.network = Array(network.suffix(Ring.network.cap))
            self.outbox = outbox
            self.failures = Array(failures.suffix(Ring.failures.cap))
            self.performance = performance
            self.crashes = Array(crashes.suffix(Ring.crashes.cap))
        }

        /// The note trimmed and cut to the door's limit; nil when nothing is left.
        static func cleaned(_ note: String?) -> String? {
            guard let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
            return cut(trimmed)
        }

        /// `text` cut to the door's limit, which counts UTF-16 units (`z.string().max(1000)`), not
        /// characters: an emoji is two or more. Cut on a character boundary, never inside one.
        static func cut(_ text: String) -> String {
            guard text.utf16.count > maxNoteCharacters else { return text }
            var units = 0
            var kept = text.startIndex
            for index in text.indices {
                let next = text.index(after: index)
                units += text[index ..< next].utf16.count
                if units > maxNoteCharacters {
                    break
                }
                kept = next
            }
            return String(text[..<kept])
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(reportId, forKey: .reportId)
            try container.encode(createdAt, forKey: .createdAt)
            // Present as null when empty: the door's schema wants the key.
            try container.encode(note, forKey: .note)
            try container.encode(environment, forKey: .environment)
            try container.encode(account, forKey: .account)
            try container.encode(events, forKey: .events)
            try container.encode(network, forKey: .network)
            try container.encode(outbox, forKey: .outbox)
            try container.encode(failures, forKey: .failures)
            try container.encode(performance, forKey: .performance)
            try container.encode(crashes, forKey: .crashes)
        }
    }

    /// Who's sending, as the app last saw it; never an email or a name.
    struct Account: Codable, Equatable, Sendable {
        enum Provider: String, CaseIterable, Codable, Sendable {
            case apple, google
        }

        /// Contract 00 §4's access state.
        enum Access: String, CaseIterable, Codable, Sendable {
            case waitlisted, approved, member, staff, suspended
        }

        enum Entitlement: String, CaseIterable, Codable, Sendable {
            case none, trial, active, expired
        }

        let provider: Provider
        let access: Access
        let entitlement: Entitlement

        init(provider: Provider, access: Access, entitlement: Entitlement) {
            self.provider = provider
            self.access = access
            self.entitlement = entitlement
        }
    }

    /// The outbox's state at report time: counts, the age of the oldest
    /// unsent item, and the last contract codes it was refused with.
    struct OutboxSummary: Codable, Equatable, Sendable {
        static let maxFailureCodes = 10

        let queued: Int
        let sending: Int
        let sent: Int
        let failed: Int
        /// Null when nothing is waiting.
        let oldestAgeSeconds: Int?
        let lastFailureCodes: [ErrorCode]

        init(queued: Int, sending: Int, sent: Int, failed: Int, oldestAgeSeconds: Int?, lastFailureCodes: [ErrorCode]) {
            self.queued = max(0, queued)
            self.sending = max(0, sending)
            self.sent = max(0, sent)
            self.failed = max(0, failed)
            self.oldestAgeSeconds = oldestAgeSeconds.map { max(0, $0) }
            self.lastFailureCodes = Array(lastFailureCodes.suffix(Self.maxFailureCodes))
        }

        static let empty = OutboxSummary(queued: 0, sending: 0, sent: 0, failed: 0, oldestAgeSeconds: nil, lastFailureCodes: [])

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(queued, forKey: .queued)
            try container.encode(sending, forKey: .sending)
            try container.encode(sent, forKey: .sent)
            try container.encode(failed, forKey: .failed)
            try container.encode(oldestAgeSeconds, forKey: .oldestAgeSeconds)
            try container.encode(lastFailureCodes, forKey: .lastFailureCodes)
        }
    }

    /// Launch time, hitches, memory warnings and thermal changes. Nothing
    /// measures these yet (DG.5 sends `none`); the fields are the door's.
    struct Performance: Codable, Equatable, Sendable {
        struct HitchRate: Codable, Equatable, Sendable {
            let screen: Screen
            /// 0...1
            let ratio: Double

            init(screen: Screen, ratio: Double) {
                self.screen = screen
                self.ratio = min(max(ratio, 0), 1)
            }
        }

        enum ThermalState: String, CaseIterable, Codable, Sendable {
            case nominal, fair, serious, critical
        }

        struct ThermalChange: Codable, Equatable, Sendable {
            let state: ThermalState

            init(state: ThermalState) {
                self.state = state
            }
        }

        /// Null until measured.
        let launchMs: Int?
        let hitchRates: [HitchRate]
        let memoryWarnings: Int
        let thermalChanges: [Stamped<ThermalChange>]

        init(launchMs: Int?, hitchRates: [HitchRate], memoryWarnings: Int, thermalChanges: [Stamped<ThermalChange>]) {
            self.launchMs = launchMs.map(Limits.ms.clamp)
            self.hitchRates = Array(hitchRates.prefix(200))
            self.memoryWarnings = max(0, memoryWarnings)
            self.thermalChanges = Array(thermalChanges.suffix(200))
        }

        static let none = Performance(launchMs: nil, hitchRates: [], memoryWarnings: 0, thermalChanges: [])

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(launchMs, forKey: .launchMs)
            try container.encode(hitchRates, forKey: .hitchRates)
            try container.encode(memoryWarnings, forKey: .memoryWarnings)
            try container.encode(thermalChanges, forKey: .thermalChanges)
        }
    }
}
