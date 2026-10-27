//
//  DarkEntriesView.swift
//  Retrospect
//
//  Entries list view in dark UI (Written and Voice entries)
//

import SwiftUI

enum DarkEntryFilter: String, CaseIterable {
    case all = "All"
    case text = "Written"
    case voice = "Voice"
}

// MARK: - Time Period for grouping

enum TimePeriod: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case pastWeek = "Past 7 Days"
    case pastMonth = "Past 30 Days"
    case older = "Older"

    static func period(for date: Date) -> TimePeriod {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return .today
        } else if calendar.isDateInYesterday(date) {
            return .yesterday
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                  date > weekAgo {
            return .pastWeek
        } else if let monthAgo = calendar.date(byAdding: .day, value: -30, to: now),
                  date > monthAgo {
            return .pastMonth
        } else {
            return .older
        }
    }
}

struct DarkEntriesView: View {
    @ObservedObject private var entryManager = EntryManager.shared
    @Binding var activeEntry: Entry?
    @State private var selectedFilter: DarkEntryFilter = .all
    @State private var searchText = ""
    @State private var isSearching = false

    @State private var headerOpacity: Double = 0
    @State private var keyboardHeight: CGFloat = 0

    init(activeEntry: Binding<Entry?> = .constant(nil)) {
        _activeEntry = activeEntry
    }

    /// Header styling
    var body: some View {
        FigmaLightPageScaffold(
            title: "Entries",
            hideHeader: isSearching || activeEntry != nil
        ) {
            VStack(spacing: 0) {
                if let entry = activeEntry {
                    FigmaLightInlineEntryReader(entry: entry, activeEntry: $activeEntry)
                } else if filteredEntries.isEmpty {
                    emptyState
                } else {
                    DarkFilterTabsCompact(selectedFilter: $selectedFilter)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .padding(.bottom, 12)

                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(TimePeriod.allCases, id: \.self) { period in
                                let periodEntries = entriesFor(period: period)
                                if !periodEntries.isEmpty {
                                    HStack {
                                        Text(period.rawValue)
                                            .font(FigmaLightTheme.mono(13, weight: .medium))
                                            .foregroundColor(FigmaLightTheme.mutedText)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 4)

                                    GroupedEntriesContainer(
                                        entries: periodEntries,
                                        onTap: { entry in
                                            activeEntry = entry
                                        },
                                        onDelete: { entry in
                                            deleteEntry(entry)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 140)
                    }
                    .mask(
                        VStack(spacing: 0) {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black.opacity(0.3), location: 0.3),
                                    .init(color: .black.opacity(0.7), location: 0.6),
                                    .init(color: .black, location: 1.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 16)
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 80)
                        }
                    )
                }

                Spacer(minLength: 0)

                if activeEntry == nil {
                    EntriesFloatingSearchBar(
                        searchText: $searchText,
                        isSearching: $isSearching
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 80 : 10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: keyboardHeight)
                }
            }
            .opacity(headerOpacity)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearching)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                headerOpacity = 1
            }

            // Observe keyboard
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        keyboardHeight = keyboardFrame.height
                    }
                }
            }

            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    keyboardHeight = 0
                }
            }
        }
    }

    private var filteredEntries: [Entry] {
        var entries = entryManager.getAllEntries()

        // Filter out video entries (not supported in dark UI)
        entries = entries.filter { $0.type != .video }

        // Apply type filter
        switch selectedFilter {
        case .all:
            break
        case .text:
            entries = entries.filter { $0.type == .text }
        case .voice:
            entries = entries.filter { $0.type == .voice }
        }

        // Apply search
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                    entry.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort by date, newest first
        return entries.sorted { $0.date > $1.date }
    }

    private func entriesFor(period: TimePeriod) -> [Entry] {
        filteredEntries.filter { TimePeriod.period(for: $0.date) == period }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(FigmaLightTheme.rowSurface)
                    .frame(width: 100, height: 100)

                Image(systemName: searchText.isEmpty ? "folder" : "magnifyingglass")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(FigmaLightTheme.mutedText)
            }

            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Entries Yet" : "No Results")
                    .font(FigmaLightTheme.title(30))
                    .foregroundColor(FigmaLightTheme.primaryText.opacity(0.72))

                Text(searchText.isEmpty ? "Your journal entries and voice\nnotes will appear here" : "Try a different search term")
                    .font(FigmaLightTheme.body(15))
                    .foregroundColor(FigmaLightTheme.mutedText)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private func deleteEntry(_ entry: Entry) {
        HapticManager.shared.playWarningNotification()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            entryManager.deleteEntry(withId: entry.id)
        }
    }
}

// MARK: - Grouped Entries Container

struct GroupedEntriesContainer: View {
    let entries: [Entry]
    let onTap: (Entry) -> Void
    let onDelete: (Entry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                GroupedEntryRow(
                    entry: entry,
                    onTap: { onTap(entry) },
                    onDelete: { onDelete(entry) }
                )

                // Divider (not after last item)
                if index < entries.count - 1 {
                    HStack {
                        Spacer()
                            .frame(width: 58) // Offset from left (icon width + padding)
                        Rectangle()
                            .fill(FigmaLightTheme.border.opacity(0.65))
                            .frame(height: 0.5)
                    }
                    .padding(.vertical, 4) // Add space around divider
                }
            }
        }
        .padding(.vertical, 8) // Breathing room at top and bottom of container
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(FigmaLightTheme.rowSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(FigmaLightTheme.border.opacity(0.75), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.045), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Individual Entry Row (within grouped container)

struct GroupedEntryRow: View {
    let entry: Entry
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    /// Generate a summary title from content (first ~60 chars, ending at word boundary)
    private var summaryTitle: String {
        let content = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)

        // If content is short, use it all
        if content.count <= 60 {
            return content.isEmpty ? "Untitled Entry" : content
        }

        // Find a good breakpoint (end of word) around 50-60 chars
        let targetLength = 55
        let searchRange = content.prefix(70)

        // Look for last space before target length
        if let lastSpace = searchRange.prefix(targetLength).lastIndex(of: " ") {
            let truncated = String(content[..<lastSpace])
            return truncated + "..."
        }

        // Fallback: just truncate
        return String(content.prefix(55)) + "..."
    }

    /// Format date and time nicely
    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: entry.date)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Type icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FigmaLightTheme.controlSurface)
                        .frame(width: 36, height: 36)

                    Image(systemName: entry.type == .voice ? "waveform" : "doc.text")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(FigmaLightTheme.mutedText)
                }

                // Content - just two lines: summary title and date/time
                VStack(alignment: .leading, spacing: 4) {
                    Text(summaryTitle)
                        .font(FigmaLightTheme.body(15, weight: .medium))
                        .foregroundColor(FigmaLightTheme.primaryText.opacity(0.82))
                        .lineLimit(1)

                    Text(formattedDateTime)
                        .font(FigmaLightTheme.mono(13))
                        .foregroundColor(FigmaLightTheme.mutedText)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(FigmaLightTheme.mutedText.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive, action: {
                showDeleteConfirm = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete Entry", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Dark Search Bar

struct DarkSearchBar: View {
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LinearColors.Minimal.textTertiary)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(LinearColors.Minimal.placeholderText)
                }

                TextField("", text: $text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .focused($isFocused)
                    .textFieldStyle(PlainTextFieldStyle())
            }

            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearColors.Minimal.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isFocused ? LinearColors.Minimal.borderFocus : LinearColors.Minimal.border,
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
    }
}

// MARK: - Dark Filter Tabs

struct DarkFilterTabs: View {
    @Binding var selectedFilter: DarkEntryFilter

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DarkEntryFilter.allCases, id: \.self) { filter in
                DarkFilterTab(
                    title: filter.rawValue,
                    isSelected: selectedFilter == filter
                ) {
                    HapticManager.shared.playSelectionChanged()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = filter
                    }
                }
            }
            Spacer()
        }
    }
}

struct DarkFilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? LinearColors.Minimal.buttonPrimaryText : LinearColors.Minimal.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? LinearColors.Minimal.accent : LinearColors.Minimal.backgroundCard)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? LinearColors.Minimal.accent : LinearColors.Minimal.border,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Compact Search Bar (for inline layout)

struct DarkSearchBarCompact: View {
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(LinearColors.Minimal.textTertiary)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(LinearColors.Minimal.placeholderText)
                }

                TextField("", text: $text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .focused($isFocused)
                    .textFieldStyle(PlainTextFieldStyle())
            }

            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearColors.Minimal.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isFocused ? LinearColors.Minimal.borderFocus : LinearColors.Minimal.border,
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
    }
}

// MARK: - Compact Filter Tabs (for inline layout)

struct DarkFilterTabsCompact: View {
    @Binding var selectedFilter: DarkEntryFilter

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DarkEntryFilter.allCases, id: \.self) { filter in
                Button(action: {
                    HapticManager.shared.playSelectionChanged()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = filter
                    }
                }) {
                    Text(filter.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(selectedFilter == filter ? FigmaLightTheme.primaryText.opacity(0.72) : FigmaLightTheme.mutedText)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .background(
                    selectedFilter == filter ?
                        Capsule().fill(FigmaLightTheme.controlSurface) :
                        Capsule().fill(Color.clear)
                )
            }
        }
        .padding(2)
        .background(
            Capsule()
                .fill(FigmaLightTheme.rowSurface.opacity(0.75))
                .overlay(
                    Capsule()
                        .strokeBorder(FigmaLightTheme.border.opacity(0.75), lineWidth: 1)
                )
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Dark Entry Card

struct DarkEntryCard: View {
    let entry: Entry
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Type icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(entry.type == .voice ? LinearColors.Minimal.accentSubtle : LinearColors.Minimal.backgroundCardHover)
                        .frame(width: 44, height: 44)

                    Image(systemName: entry.type == .voice ? "waveform" : "doc.text")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(entry.type == .voice ? LinearColors.Minimal.accent : LinearColors.Minimal.textSecondary)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .lineLimit(1)

                    Text(entry.contentPreview)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                        .lineLimit(2)

                    Text(formatDate(entry.date))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearColors.Minimal.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive, action: {
                showDeleteConfirm = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete Entry", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()

        DarkEntriesView()
    }
}
