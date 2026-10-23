//
//  TicketCode.swift
//  C41.4: what the 13 tiles accept as the person types. The same alphabet and reading as
//  `Session.InviteCode` (Crockford: `I`/`L` read as 1, `O` as 0), applied a character at a time so
//  a half-typed code can show on the tiles. The code is never logged.
//
import Foundation

enum TicketCode {
    static let length = Session.InviteCode.length

    /// The tiles' text for whatever was typed or pasted: uppercase, dashes and spaces dropped,
    /// anything outside the alphabet refused (no character added), at most 13.
    static func tiles(from raw: String) -> String {
        var out = ""
        for character in raw.uppercased() {
            guard out.count < length else { break }
            switch character {
            case " ", "-": continue
            case "I", "L": out.append("1")
            case "O": out.append("0")
            default:
                if Session.InviteCode.alphabet.contains(character) {
                    out.append(character)
                }
            }
        }
        return out
    }

    /// The tiles grouped 4 · 4 · 4 · 1, as printed (`7KQ2 M9XD 4RTA B`).
    static func groups(of tiles: String) -> [String] {
        let characters = Array(tiles)
        return stride(from: 0, to: length, by: 4).map { start in
            guard start < characters.count else { return "" }
            return String(characters[start ..< min(start + 4, characters.count)])
        }
    }

    /// The code as VoiceOver should read it: characters spaced, never a word.
    static func spelled(_ tiles: String) -> String {
        tiles.map(String.init).joined(separator: " ")
    }
}
