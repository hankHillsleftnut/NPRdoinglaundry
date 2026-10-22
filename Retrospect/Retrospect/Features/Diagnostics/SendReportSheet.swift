//
//  SendReportSheet.swift
//  DG.6: "send a report" (docs/team/flows/diagnostics.md). Not drawn in Paper, so it is built
//  from the system's own parts, by the sheet rules (design-system/components/sheet-and-dialog.md):
//  a title, one line saying what is sent, an optional "what happened?" field, "what's included"
//  as counts, and the lit send pinned at the foot while the middle scrolls. Offline is fine:
//  the report is saved and goes later, and the line under the button says so.
//
import SwiftUI

struct SendReportSheet: View {
    @Bindable var model: SendReportModel
    var isOnline = true

    @FocusState private var noteFocused: Bool

    var body: some View {
        VStack(spacing: RDimension.space4) {
            Text("send a report")
                .rText(.displayTitle)
                .foregroundStyle(RColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            ScrollView {
                VStack(alignment: .leading, spacing: RDimension.space6) {
                    Text("this sends what the app did in your recent sessions, so we can fix what went wrong.")
                        .rText(.bodyReading)
                        .foregroundStyle(RColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    noteField
                    included
                }
            }
            .scrollClipDisabled()
            .scrollDismissesKeyboard(.interactively)
            .frame(minHeight: RDimension.space0, maxHeight: .infinity)
            RButton(title: "send", status: buttonStatus) {
                noteFocused = false
                Task { await model.send() }
            }
            .accessibilityIdentifier("report.send")
        }
        .padding(.bottom, RDimension.spaceScreenMargin)
        .task { await model.load() }
    }

    private var buttonStatus: RButton.Status {
        switch model.phase {
        case .editing: .rest
        case .sending: .pending
        case .failed: .error("couldn't save the report. try again.")
        case .queued: .pending
        }
    }

    private var notePrompt: Text {
        Text("a few words help").foregroundStyle(RColor.textPlaceholder)
    }

    private var noteFootnote: String {
        isOnline
            ? "this is the only text we read. write it for us."
            : "you're offline. the report is saved and sent when you're back."
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: RDimension.space1) {
            RSectionLabel(title: "what happened? (optional)")
            RSunkenField(alignment: .top, radius: RDimension.radiusField) {
                EmptyView()
            } content: {
                TextField("", text: $model.note, prompt: notePrompt, axis: .vertical)
                    .rText(.body)
                    .foregroundStyle(RColor.textPrimary)
                    .tint(RColor.textPrimary)
                    .lineLimit(2 ... 6)
                    .focused($noteFocused)
                    .padding(.horizontal, RDimension.space2)
                    .padding(.vertical, RDimension.space3)
                    .accessibilityLabel("what happened? optional")
                    .accessibilityIdentifier("report.note")
            } trailing: {
                EmptyView()
            }
            Text(noteFootnote)
                .rText(.metaLine)
                .foregroundStyle(RColor.textLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var included: some View {
        VStack(alignment: .leading, spacing: RDimension.space1) {
            RSectionLabel(title: "what's included")
            if let counts = model.included {
                RSettingsGroup(inset: .full) {
                    row("recent activity", counts.events, unit: "events")
                    row("requests to the server", counts.requests)
                    row("problems", counts.problems)
                    row("waiting to send", counts.unsent)
                }
                Text("no entries, voice notes or names. only how the app behaved\(period(counts.days))")
                    .rText(.metaLine)
                    .foregroundStyle(RColor.textLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, RDimension.space1)
            } else {
                RSkeleton(bars: [nil, nil, nil, nil])
            }
        }
    }

    private func period(_ days: Int) -> String {
        days > 0 ? ", over the last \(days) \(days == 1 ? "day" : "days")." : "."
    }

    private func row(_ title: String, _ count: Int, unit: String? = nil) -> some View {
        HStack {
            Text(title).rText(.body).foregroundStyle(RColor.textPrimary)
            Spacer(minLength: RDimension.space3)
            Text(unit.map { "\(count) \($0)" } ?? "\(count)")
                .rText(.figure)
                .foregroundStyle(RColor.textLabel)
        }
        .frame(minHeight: RDimension.sizeRowDefault)
        .accessibilityElement(children: .combine)
    }
}
