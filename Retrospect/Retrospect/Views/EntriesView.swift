import SwiftUI

enum EntryFilterType: String, CaseIterable {
    case all = "All"
    case text = "Written"
    case video = "Video"
    case voice = "Voice"
}

struct EntriesView: View {
    @ObservedObject private var entryManager = EntryManager.shared
    @State private var selectedFilter: EntryFilterType = .all
    @State private var searchText = ""
    @State private var selectedEntry: Entry?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                
                // Filter Tabs
                filterTabs
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                
                // Entries List
                if filteredEntries.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredEntries) { entry in
                                EntryCard(
                                    entry: entry,
                                    onTap: {
                                        selectedEntry = entry
                                    },
                                    onDelete: {
                                        deleteEntry(entry)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(LinearColors.backgroundGrey.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: $selectedEntry) { entry in
            EntryDetailView(entry: entry)
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LinearColors.textSecondary)
            
            TextField("Search entries...", text: $searchText)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(LinearColors.textPrimary)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(LinearColors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.input)
                .fill(LinearColors.inputBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.input)
                .stroke(LinearColors.inputBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Filter Tabs
    private var filterTabs: some View {
        HStack(spacing: 12) {
            ForEach(EntryFilterType.allCases, id: \.self) { filter in
                FilterTab(
                    title: filter.rawValue,
                    isSelected: selectedFilter == filter,
                    count: countForFilter(filter)
                ) {
                    HapticManager.shared.playSelectionChanged()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = filter
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "folder" : "magnifyingglass")
                .font(.system(size: 60, weight: .thin))
                .foregroundColor(LinearColors.textSecondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Entries Yet" : "No Results Found")
                    .font(.serifHeadline)
                    .fontWeight(.bold)
                    .foregroundColor(LinearColors.textPrimary)
                
                Text(searchText.isEmpty ? "Your written reflections and video journals will appear here" : "Try adjusting your search or filters")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(LinearColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - Computed Properties
    private var filteredEntries: [Entry] {
        var entries = entryManager.getAllEntries()
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .text:
            entries = entries.filter { $0.type == .text }
        case .video:
            entries = entries.filter { $0.type == .video }
        case .voice:
            entries = entries.filter { $0.type == .voice }
        }
        
        // Apply search
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                entry.content.localizedCaseInsensitiveContains(searchText) ||
                entry.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
        
        return entries
    }
    
    private func countForFilter(_ filter: EntryFilterType) -> Int {
        let allEntries = entryManager.getAllEntries()
        switch filter {
        case .all:
            return allEntries.count
        case .text:
            return allEntries.filter { $0.type == .text }.count
        case .video:
            return allEntries.filter { $0.type == .video }.count
        case .voice:
            return allEntries.filter { $0.type == .voice }.count
        }
    }
    
    // MARK: - Delete Entry
    private func deleteEntry(_ entry: Entry) {
        HapticManager.shared.playWarningNotification()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            entryManager.deleteEntry(withId: entry.id)
        }
    }
}

// MARK: - Filter Tab Component
struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                
                Text("\(count)")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(isSelected ? .white : LinearColors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? LinearColors.accent : LinearColors.cardBackground)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? LinearColors.accent : LinearColors.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

