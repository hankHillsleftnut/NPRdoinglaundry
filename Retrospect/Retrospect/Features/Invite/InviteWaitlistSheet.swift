//
//  InviteWaitlistSheet.swift
//  PI1: "join the waitlist" (to be drawn; built on the lean in docs/team/flows/first-run/views.md).
//  A sheet: a title, one line, an optional note of at most 280 characters (the count appears at
//  240), the lit "join" and a text "cancel". Joined is only shown after the door said so.
//
import SwiftUI

struct InviteWaitlistSheet: View {
    @Bindable var model: InviteModel
    @State private var note = ""
    @FocusState private var focused: Bool

    static let limit = 280
    static let counterFrom = 240

    /// At most 280 UTF-16 units (the door counts them that way), never cutting a character in half.
    static func clipped(_ text: String) -> String {
        var out = ""
        for character in text {
            guard out.utf16.count + String(character).utf16.count <= limit else { break }
            out.append(character)
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space4) {
            Text("join the waitlist")
                .rText(.inkCard)
                .foregroundStyle(RColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("we'll send you a link when there's a place.")
                .rText(.body)
                .foregroundStyle(RColor.textSecondary)
            RSunkenField(radius: RDimension.radiusField) {
                EmptyView()
            } content: {
                TextField("anything you'd like us to know?", text: $note, axis: .vertical)
                    .rText(.body)
                    .foregroundStyle(RColor.textPrimary)
                    .lineLimit(1 ... 4)
                    .focused($focused)
                    .padding(.horizontal, RDimension.space3)
                    .padding(.vertical, RDimension.space2)
                    .onChange(of: note) { _, new in
                        if new.utf16.count > Self.limit {
                            note = Self.clipped(new)
                        }
                    }
                    .accessibilityIdentifier("waitlist.note")
            } trailing: {
                EmptyView()
            }
            if note.utf16.count >= Self.counterFrom {
                Text("\(note.utf16.count) / \(Self.limit)")
                    .rText(.ticketFigure)
                    .foregroundStyle(RColor.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            RButton(title: "join", status: status) {
                Task { await model.join(reason: note) }
            }
            .accessibilityIdentifier("waitlist.join")
            RButton(title: "cancel", variant: .text) { model.closeWaitlist() }
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, RDimension.layoutSheetInset)
        .padding(.bottom, RDimension.space6)
    }

    private var status: RButton.Status {
        switch model.waitlist {
        case .joining: .pending
        case .failed: .error("couldn't join. try again.")
        case _ where !model.isOnline: .disabled(reason: "connect to join")
        default: .rest
        }
    }
}
