import SwiftUI

/// The card-inside-a-card shell. The window is the warm cream outer card; a single white
/// page fills it with a thin margin that tucks up close to the traffic lights. The reveal
/// sidebar lives *inside* the page — pressing the menu button splits the card, sliding the
/// sidebar in from the left and pushing the writing column over.
struct RootView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var sync: SyncEngine
    @EnvironmentObject var editor: EditorController
    @State private var sidebarOpen = false

    var body: some View {
        ZStack {
            // Outer surface = the same opaque cream as the sidebar, so they read as one canvas
            // and only the white writing card stands apart.
            Ink.cream
            card
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .padding(.top, 30) // measured from the true window top; just clears the traffic lights
        }
        .background(WindowConfigurator())
        .ignoresSafeArea(.container, edges: .all)
        .frame(minWidth: 720, minHeight: 520)
    }

    // MARK: - The page (sidebar panel + shrinking writing card)

    private var card: some View {
        HStack(spacing: sidebarOpen ? Metrics.cardGap : 0) {
            if sidebarOpen {
                // Opaque cream panel, no stroke. Its presence narrows the writing card.
                SidebarView()
                    .frame(width: Metrics.sidebarWidth)
                    .background(Ink.cream)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.innerCardRadius))
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            writingCard
        }
    }

    /// The white writing surface — its own card with stroke + shadow. Shrinks width-wise as
    /// the sidebar takes space.
    private var writingCard: some View {
        writingColumn
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Ink.page)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.innerCardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.innerCardRadius)
                    .stroke(Ink.border, lineWidth: 1)
            )
            .shadow(color: Ink.shadow, radius: 14, x: 0, y: 6)
            // Moving the pointer brings the chrome back even mid-sentence.
            .onContinuousHover { phase in
                if case .active = phase { editor.revealChrome() }
            }
    }

    private var writingColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                menuButton
                Spacer()
                FormatBar()
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.top, 4)
            // Fade the chrome away while writing so nothing competes with the words.
            .opacity(editor.isTyping ? 0 : 1)
            .allowsHitTesting(!editor.isTyping)
            .animation(.easeOut(duration: 0.45), value: editor.isTyping)

            JournalPage()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var menuButton: some View {
        Button(action: { withAnimation(.spring(response: Metrics.revealDuration, dampingFraction: 0.85)) { sidebarOpen.toggle() } }) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Ink.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(sidebarOpen ? Ink.accent.opacity(0.6) : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Toggle sidebar (⌘\\)")
        .keyboardShortcut("\\", modifiers: .command)
    }
}

/// The writing surface: the entry's date and the editor, sharing one left edge, centered to a
/// comfortable measure. The gentle prompt is drawn inline inside the editor (see `MarkdownEditor`),
/// so date, prompt, and typed text all begin on the same vertical line.
private struct JournalPage: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var session: SessionMonitor
    @EnvironmentObject var sync: SyncEngine
    @EnvironmentObject var editor: EditorController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let entry = store.selectedEntry {
                Text(dateLabel(entry.createdAt))
                    .font(.journalMeta)
                    .foregroundColor(Ink.tertiary)
                    .frame(maxWidth: Metrics.writingMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, Metrics.sm)
                    .padding(.bottom, Metrics.sm)
            }

            MarkdownEditor(
                entryID: store.selectedID,
                markdown: store.selectedEntry?.markdown ?? "",
                placeholder: (store.selectedEntry?.isEmpty ?? true) ? Prompts.today() : "",
                controller: editor,
                onChange: { store.update(id: $0, markdown: $1) },
                onActivity: { session.registerActivity() }
            )
            .frame(maxWidth: Metrics.writingMaxWidth)
            .frame(maxWidth: .infinity)

            statusBar
        }
        .padding(.horizontal, Metrics.lg)
        .padding(.bottom, Metrics.sm)
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date).uppercased()
    }

    private var statusBar: some View {
        HStack {
            if editor.wordCount > 0 {
                Text("\(editor.wordCount) \(editor.wordCount == 1 ? "word" : "words")")
                    .font(.journalMeta).foregroundColor(Ink.tertiary)
            }
            Spacer()
            if sync.isFlushing {
                Text("Syncing…").font(.journalMeta).foregroundColor(Ink.tertiary)
            } else if !sync.status.isEmpty {
                Text(sync.status).font(.journalMeta).foregroundColor(Ink.tertiary)
            }
        }
        .padding(.horizontal, Metrics.md)
        .frame(height: 18)
        .opacity(editor.isTyping ? 0 : 1)
        .animation(.easeOut(duration: 0.45), value: editor.isTyping)
    }
}
