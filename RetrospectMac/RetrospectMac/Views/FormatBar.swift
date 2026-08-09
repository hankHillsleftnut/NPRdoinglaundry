import SwiftUI

/// The quiet formatting toolbar that sits in the writing card's top bar: a paragraph-style
/// picker (Body / Title / Heading / Subhead) plus Bold and Italic toggles. It mirrors the live
/// caret state via `EditorController` and applies formatting to the selection.
struct FormatBar: View {
    @EnvironmentObject var editor: EditorController

    var body: some View {
        HStack(spacing: 4) {
            Menu {
                Button("Body") { editor.applyHeading(0) }
                Button("Title") { editor.applyHeading(1) }
                Button("Heading") { editor.applyHeading(2) }
                Button("Subhead") { editor.applyHeading(3) }
            } label: {
                HStack(spacing: 3) {
                    Text(editor.styleName)
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                }
                .font(.journalTool)
                .foregroundColor(Ink.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Paragraph style")

            Divider().frame(height: 14).overlay(Ink.border)

            FormatToggle(symbol: "bold", active: editor.isBold, help: "Bold (⌘B)") { editor.toggleBold() }
            FormatToggle(symbol: "italic", active: editor.isItalic, help: "Italic (⌘I)") { editor.toggleItalic() }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(Ink.cream.opacity(0.6))
        )
    }
}

/// A small square toggle button for a symbolic trait (bold / italic), warmly highlighted when on.
private struct FormatToggle: View {
    let symbol: String
    let active: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(active ? Ink.emphasis : Ink.secondary)
                .frame(width: 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(active ? Ink.accent.opacity(0.9) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
