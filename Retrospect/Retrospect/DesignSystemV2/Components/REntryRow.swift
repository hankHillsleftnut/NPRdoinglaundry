//
//  REntryRow.swift
//  M14 C31: one entry in the journal drawer (Paper c:entry-row/drawer/rest 1FQH-0, unsent 1FQ8-0,
//  searching DRA-0). Your own words in SF 17 (--tracking-card, leading snug, two lines) over one
//  Geist 12 meta line, 4 apart, 12 padding all round. Pressed takes surface.wash on a radius.default
//  corner (Paper 9Z8-0: one step lighter than a search match, so a pressed result keeps it). In
//  search, the matched words are accent.text, medium (Paper DRA-0; screen rule 14, blue's fourth
//  job). Not sent: the meta line becomes "not sent · tap to retry" in status.dangerText, and a tap
//  retries. Waiting (offline): "waiting to send", grey, never red.
//
import SwiftUI

struct REntryRow: View {
    enum Status: Equatable {
        /// Sent: the meta line ("today · 9:12").
        case rest
        /// Offline, saved on the phone: "waiting to send", grey.
        case waiting
        /// Didn't send: "not sent · tap to retry"; the row's tap retries.
        case notSent
    }

    /// Your words, exactly as you wrote or said them.
    let words: String
    /// Time and kind, already worded ("today · 9:12", "voice note · 1:42").
    let meta: String
    /// Search matches in `words`, as UTF-16 offsets and lengths (contract 02 §5).
    var matches: [Range<Int>] = []
    var status: Status = .rest
    /// Opens the entry in the thread, or retries when it didn't send.
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: RDimension.space1) {
                Self.highlighted(words, matches: matches)
                    .rText(.entryWords)
                    .foregroundStyle(RColor.textPrimary)
                    // two lines, then an ellipsis; four at accessibility sizes
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    .multilineTextAlignment(.leading)
                metaLine
            }
            .padding(RDimension.space3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(RDrawerRowStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(status == .notSent ? "double tap to retry" : "")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var metaLine: some View {
        switch status {
        case .rest:
            Text(meta)
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
        case .waiting:
            statusLine("waiting to send", glyph: "wifi.slash", color: RColor.textLabel, glyphTint: RColor.iconMuted)
        case .notSent:
            statusLine("not sent · tap to retry", glyph: "arrow.clockwise", color: RColor.statusDangerText, glyphTint: RColor.statusDangerText)
                .rBlurReplace()
        }
    }

    /// A glyph on the words' baseline, sized by their font, 4 apart (Paper 1FQ8-0).
    private func statusLine(_ text: String, glyph: String, color: Color, glyphTint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: RDimension.space1) {
            Image(systemName: glyph)
                .imageScale(.small)
                .foregroundStyle(glyphTint)
            Text(text).foregroundStyle(color)
        }
        .rText(.metaLine)
    }

    private var accessibilityText: String {
        switch status {
        case .rest: "\(words), \(meta.replacingOccurrences(of: " · ", with: ", "))"
        case .waiting: "\(words), waiting to send"
        case .notSent: "\(words), not sent"
        }
    }

    /// The words with each match as an accent.text, medium run.
    static func highlighted(_ words: String, matches: [Range<Int>]) -> Text {
        segments(words, matches: matches).reduce(Text(verbatim: "")) { text, segment in
            segment.matched
                ? text + Text(verbatim: segment.text).fontWeight(.medium).foregroundStyle(RColor.accentText)
                : text + Text(verbatim: segment.text)
        }
    }

    /// The words cut at each match. Matches are UTF-16 offsets (contract 02 §5); one that falls
    /// outside the words, overlaps an earlier one, or splits a character is skipped.
    static func segments(_ words: String, matches: [Range<Int>]) -> [(text: String, matched: Bool)] {
        let utf16 = words.utf16
        var result: [(text: String, matched: Bool)] = []
        var cursor = words.startIndex
        for match in matches.sorted(by: { $0.lowerBound < $1.lowerBound })
            where match.lowerBound >= 0 && match.upperBound <= utf16.count && !match.isEmpty {
            let lower = utf16.index(utf16.startIndex, offsetBy: match.lowerBound)
            let upper = utf16.index(utf16.startIndex, offsetBy: match.upperBound)
            guard let start = lower.samePosition(in: words), let end = upper.samePosition(in: words), start >= cursor
            else { continue }
            if cursor < start {
                result.append((String(words[cursor ..< start]), false))
            }
            result.append((String(words[start ..< end]), true))
            cursor = end
        }
        if cursor < words.endIndex {
            result.append((String(words[cursor...]), false))
        }
        return result
    }
}

extension RTextStyle {
    /// Your words in a drawer row (1FQH-0): SF 17, --tracking-card, leading snug.
    static let entryWords = RTextStyle(
        family: .text,
        size: RDimension.fontSizeBody,
        weight: .regular,
        tracking: RNumber.fontTrackingCard,
        leading: RTextStyle.textMd.leading,
        relativeTo: .body
    )
}

/// The drawer row's press: surface.wash on a radius.default corner, in over 80ms and back over 240.
private struct RDrawerRowStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? RColor.surfaceWash : .clear, in: RShape.rect(RDimension.radiusDefault))
            .animation(
                reduceMotion
                    ? RMotion.standard(RNumber.motionDurationFast)
                    : RMotion.standard(configuration.isPressed ? RNumber.motionDurationPressIn : RNumber.motionDurationPressOut),
                value: configuration.isPressed
            )
    }
}

#if DEBUG
/// Lab page "entryrow": rest, a match, waiting and not sent, on the drawer's underlay.
struct REntryRowGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space0) {
                caption("rest")
                REntryRow(words: "slept badly, long day of meetings", meta: "2 messages · 22:40") {}
                caption("search · standup")
                REntryRow(words: "the 9am standup again", meta: "today · 9:12", matches: [8 ..< 15]) {}
                REntryRow(words: "standup ran long again", meta: "tue 14 oct · 10:05", matches: [0 ..< 7]) {}
                caption("long words: two lines, then an ellipsis")
                REntryRow(
                    words: "the day started fine and then the planning call ran over by an hour, so lunch was a sandwich at the desk again",
                    meta: "today · 13:02"
                ) {}
                caption("waiting (offline)")
                REntryRow(words: "on the train, no signal", meta: "today · 8:05", status: .waiting) {}
                caption("not sent")
                REntryRow(words: "the fundraise article you shared", meta: "today · 8:10", status: .notSent) {}
            }
            .padding(RDimension.space4)
        }
        .background(RColor.backgroundUnderlay)
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
            .padding(.top, RDimension.space4)
            .padding(.horizontal, RDimension.space3)
    }
}

#Preview("entry row") { REntryRowGallery() }
#endif
