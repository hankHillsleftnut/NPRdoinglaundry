//
//  FlowTypes.swift
//  The shapes every flow protocol shares (ui-engineer.md §4, the seam). Views read these;
//  sample data (Features/…/Sample) and live data (Platform) both produce them, so swapping
//  one for the other never changes what a screen can show.
//
import Foundation

/// Why a read or a write didn't work, in the terms a screen needs to pick its state
/// (C39: error with try again, offline line, gone). Platform maps contract 00's error
/// codes and transport failures onto these; views never see a status code.
enum FlowFailure: Error, Hashable, Sendable {
    /// No connection, or the request couldn't reach the server.
    case network
    /// The server or the brain failed (contract 00: internal, upstream_*).
    case server
    /// The thing doesn't exist, or isn't yours (contract 00: not_found).
    case notFound
    /// Too many tries; try again after this many seconds (contract 00: rate_limited).
    case rateLimited(retryAfterSeconds: Int?)
    /// The day's model spend is used up (contract 00: spend_limited).
    case spendLimited(retryAfterSeconds: Int?)
    /// This version of the app is too old (contract 00: update_required).
    case updateRequired
    /// Signed out or the session ended (contract 00: session_revoked).
    case signedOut
    /// Anything the app doesn't recognise yet.
    case unknown
}

/// A value a screen waits for. `loading` never carries stale content: a screen showing
/// cached content while offline is `loaded`, with the flow's `isOnline` false.
enum Loadable<Value: Sendable>: Sendable {
    case loading
    case loaded(Value)
    case failed(FlowFailure)

    var value: Value? {
        if case let .loaded(value) = self {
            return value
        }
        return nil
    }
}

extension Loadable: Equatable where Value: Equatable {}
extension Loadable: Hashable where Value: Hashable {}

/// One page of a cursor-paged list (contracts: `{ items, nextCursor }`).
struct Page<Item: Sendable>: Sendable {
    let items: [Item]
    /// Pass back to get the next page; nil on the last page.
    let nextCursor: String?
}

extension Page: Equatable where Item: Equatable {}
extension Page: Hashable where Item: Hashable {}

/// Contracts rule 5: enums are closed lists, and a value the app doesn't know decodes to
/// `unknown` instead of failing the whole response.
protocol ContractEnum: RawRepresentable, Codable, Sendable, Hashable where RawValue == String {
    static var unknown: Self { get }
}

extension ContractEnum {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unknown
    }
}

extension JSONDecoder {
    /// Contracts rule 2: ISO 8601 UTC with milliseconds (`2026-10-21T08:00:04.200Z`); a value
    /// without milliseconds is accepted too. Calendar days stay strings (`YYYY-MM-DD`).
    /// PL1.1a's client uses this same decoder.
    static var contract: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            if let date = try? Date(text, strategy: .iso8601) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "not an ISO 8601 date")
        }
        return decoder
    }
}
