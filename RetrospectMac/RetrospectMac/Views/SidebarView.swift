import SwiftUI

/// The reveal sidebar: wordmark, a "new entry" affordance, the reverse-chronological entry
/// list, and a quiet account footer. Hidden until the menu button is pressed.
struct SidebarView: View {
    @EnvironmentObject var store: JournalStore
    @EnvironmentObject var api: RetrospectAPI
    @EnvironmentObject var auth: AuthManager
    @State private var showingSignIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Retrospect")
                .font(.journalBrand)
                .foregroundColor(Ink.emphasis)
                .padding(.horizontal, Metrics.md)
                .padding(.top, Metrics.sm)
                .padding(.bottom, Metrics.md)

            Button(action: { withAnimation { store.newEntry() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                    Text("New entry")
                    Spacer()
                }
                .font(.journalMeta)
                .foregroundColor(Ink.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, Metrics.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().background(Ink.border).padding(.vertical, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(store.sortedEntries) { entry in
                        EntryRow(entry: entry, isSelected: entry.id == store.selectedID)
                            .onTapGesture { store.selectedID = entry.id }
                            .contextMenu {
                                Button("Delete", role: .destructive) { store.delete(id: entry.id) }
                            }
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)
            Divider().background(Ink.border)
            accountFooter
                .padding(.horizontal, Metrics.md)
                .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accountFooter: some View {
        Group {
            if api.isAuthenticated {
                HStack(spacing: 8) {
                    Circle().fill(Ink.success).frame(width: 7, height: 7)
                    Text(api.currentEmail ?? "Signed in")
                        .font(.journalMeta).foregroundColor(Ink.tertiary)
                        .lineLimit(1)
                    Spacer()
                    Button("Sign out") { auth.signOut() }
                        .buttonStyle(.plain).font(.journalMeta).foregroundColor(Ink.secondary)
                }
            } else {
                Button(action: { showingSignIn = true }) {
                    HStack(spacing: 8) {
                        Circle().fill(Ink.tertiary).frame(width: 7, height: 7)
                        Text("Sign in to sync").font(.journalMeta).foregroundColor(Ink.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingSignIn) { SignInView() }
            }
        }
    }
}

private struct EntryRow: View {
    let entry: JournalEntry
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
                .font(.journalEntryTitle)
                .foregroundColor(Ink.emphasis)
                .lineLimit(1)
            Text(dateLabel)
                .font(.journalMeta)
                .foregroundColor(Ink.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Ink.accent.opacity(0.5) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d · h:mm a"
        return f.string(from: entry.createdAt)
    }
}
