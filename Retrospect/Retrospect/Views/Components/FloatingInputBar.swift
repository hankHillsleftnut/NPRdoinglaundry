//
//  FloatingInputBar.swift
//  Retrospect
//
//  Reusable floating input bar that expands into a full search/input UI
//  Used for Entries search and Goals search/add
//

import SwiftUI

// MARK: - Floating Search Bar (Legacy - for reference)
struct FloatingSearchBar: View {
    @Binding var searchText: String
    @Binding var isExpanded: Bool
    let placeholder: String
    var onSearch: ((String) -> Void)? = nil
    
    var body: some View {
        Button(action: {
            HapticManager.shared.playLightImpact()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded = true
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
                
                Text(searchText.isEmpty ? placeholder : searchText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(searchText.isEmpty ? LinearColors.Minimal.placeholderText : LinearColors.Minimal.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearColors.Minimal.inputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Entries Floating Search Bar (Pill-shaped, inline search)
struct EntriesFloatingSearchBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    @FocusState private var isSearchFocused: Bool
    
    private let barHeight: CGFloat = 52
    
    var body: some View {
        HStack(spacing: 10) {
            // Only show search icon when not actively typing
            if !isSearching || searchText.isEmpty {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LinearColors.Minimal.textTertiary)
            }
            
            if isSearching {
                TextField("Search entries...", text: $searchText)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .focused($isSearchFocused)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                    }
                }
                
                Button(action: { dismissSearch() }) {
                    Text("Done")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.accent)
                }
            } else {
                Text("Search entries...")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.placeholderText)
                    .lineLimit(1)
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: barHeight)
        .background(
            Capsule()
                .fill(LinearColors.Minimal.inputBackground)
                .overlay(
                    Capsule()
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
        )
        .onTapGesture {
            if !isSearching {
                HapticManager.shared.playLightImpact()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isSearching = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearching)
    }
    
    private func dismissSearch() {
        isSearchFocused = false
        searchText = ""
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSearching = false
        }
    }
}

// MARK: - Goals Floating Bar (Swappable Search + Add)
enum GoalsInputMode {
    case idle      // Neither active - show search bar + plus button
    case searching // Search bar expanded, plus button visible
    case adding    // Search button visible, add bar expanded
}

struct GoalsFloatingBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @Binding var newGoalText: String
    @Binding var isAdding: Bool
    let onSubmitGoal: (String) -> Void
    
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isAddFocused: Bool
    
    private let barHeight: CGFloat = 52
    
    private var mode: GoalsInputMode {
        if isAdding { return .adding }
        if isSearching { return .searching }
        return .idle
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // LEFT SIDE
            if mode == .adding {
                // Search icon button (circle) on left when adding
                Button(action: {
                    switchToSearch()
                }) {
                    ZStack {
                        Circle()
                            .fill(LinearColors.Minimal.inputBackground)
                            .overlay(
                                Circle()
                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                            )
                            .frame(width: barHeight, height: barHeight)
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textTertiary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.scale.combined(with: .opacity))
            } else {
                // Search bar (wide) on left when idle or searching
                searchBar
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
            
            // RIGHT SIDE
            if mode == .adding {
                // Add input bar (wide) on right when adding
                addInputBar
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            } else {
                // Plus button (circle) on right when idle or searching
                Button(action: {
                    switchToAdd()
                }) {
                    ZStack {
                        Circle()
                            .fill(LinearColors.Minimal.accent)
                            .frame(width: barHeight, height: barHeight)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: mode)
    }
    
    // MARK: - Search Bar (Wide)
    private var searchBar: some View {
        HStack(spacing: 10) {
            // Only show search icon when not actively typing
            if !isSearching || searchText.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            }
            
            if isSearching {
                TextField("Search goals...", text: $searchText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .focused($isSearchFocused)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                }
                }
                
                Button(action: { dismissSearch() }) {
                    Text("Done")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.accent)
                }
            } else {
                Text("Search goals...")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.placeholderText)
                    .lineLimit(1)
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: barHeight)
        .background(
            Capsule()
                .fill(LinearColors.Minimal.inputBackground)
                .overlay(
                    Capsule()
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
        )
        .onTapGesture {
            if !isSearching {
                HapticManager.shared.playLightImpact()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isSearching = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            }
        }
    }
    
    // MARK: - Add Input Bar (Wide)
    private var addInputBar: some View {
        HStack(spacing: 10) {
            TextField("Add a new goal...", text: $newGoalText)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .focused($isAddFocused)
                .onSubmit {
                    submitGoal()
                }
            
            if !newGoalText.isEmpty {
                Button(action: { newGoalText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
            }
        }
            
            // Submit button
            Button(action: { submitGoal() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(
                        newGoalText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? LinearColors.Minimal.textTertiary
                        : LinearColors.Minimal.accent
                    )
            }
            .disabled(newGoalText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .frame(height: barHeight)
        .background(
            Capsule()
                .fill(LinearColors.Minimal.inputBackground)
                .overlay(
                    Capsule()
                        .strokeBorder(LinearColors.Minimal.accent.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Actions
    private func switchToSearch() {
        HapticManager.shared.playLightImpact()
        isAddFocused = false
        newGoalText = ""
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isAdding = false
            isSearching = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isSearchFocused = true
        }
    }
    
    private func switchToAdd() {
        HapticManager.shared.playLightImpact()
        isSearchFocused = false
        searchText = ""
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isSearching = false
            isAdding = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isAddFocused = true
        }
    }
    
    private func dismissSearch() {
        isSearchFocused = false
        searchText = ""
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSearching = false
        }
    }
    
    private func submitGoal() {
        let trimmed = newGoalText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        HapticManager.shared.playSuccessNotification()
        onSubmitGoal(trimmed)
        newGoalText = ""
        isAddFocused = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isAdding = false
        }
    }
}

// MARK: - Floating Search + Add Bar (for Goals)
struct FloatingSearchAddBar: View {
    @Binding var searchText: String
    @Binding var isSearchExpanded: Bool
    @Binding var isAddExpanded: Bool
    let searchPlaceholder: String
    var onSearch: ((String) -> Void)? = nil
    var onAdd: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 10) {
            // Search bar (flexible width)
            Button(action: {
                HapticManager.shared.playLightImpact()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isSearchExpanded = true
                }
            }) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
                
                    Text(searchText.isEmpty ? searchPlaceholder : searchText)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(searchText.isEmpty ? LinearColors.Minimal.placeholderText : LinearColors.Minimal.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
            }
            .padding(.horizontal, 14)
                .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearColors.Minimal.inputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                    )
            )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Add button
            Button(action: {
                HapticManager.shared.playMediumImpact()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isAddExpanded = true
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearColors.Minimal.accent)
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Expanded Search Overlay
struct ExpandedSearchOverlay<Content: View>: View {
    @Binding var isExpanded: Bool
    @Binding var searchText: String
    let placeholder: String
    @ViewBuilder let content: () -> Content
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
        ZStack {
                // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissOverlay()
                }
            
            VStack(spacing: 0) {
                    // Results area (content provides its own ScrollView if needed)
                content()
                
                    // Search input at bottom (above keyboard)
                    VStack(spacing: 0) {
                        // Divider
                        Rectangle()
                            .fill(LinearColors.Minimal.border)
                            .frame(height: 1)
                        
                        // Input bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                    
                    TextField(placeholder, text: $searchText)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .focused($isFocused)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                        }
                    }
                    
                    Button(action: {
                        dismissOverlay()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.accent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                        .background(LinearColors.Minimal.background)
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
            }
        }
    }
    
    private func dismissOverlay() {
        isFocused = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded = false
        }
    }
}

// MARK: - Expanded Add Goal Overlay
struct ExpandedAddGoalOverlay: View {
    @Binding var isExpanded: Bool
    @Binding var goalText: String
    let onSubmit: (String) -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
        ZStack {
                // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissOverlay()
                }
            
            VStack {
                Spacer()
                
                // Input bar at bottom (above keyboard)
                    VStack(spacing: 0) {
                        // Divider
                        Rectangle()
                            .fill(LinearColors.Minimal.border)
                            .frame(height: 1)
                        
                        // Input bar
                HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.accent)
                            
                            TextField("Add a new goal...", text: $goalText)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .focused($isFocused)
                        .onSubmit {
                            submitGoal()
                        }
                    
                            // Add button
                    Button(action: {
                        submitGoal()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(
                                goalText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? LinearColors.Minimal.textTertiary
                                : LinearColors.Minimal.accent
                            )
                    }
                    .disabled(goalText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                        .background(LinearColors.Minimal.background)
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
            }
        }
    }
    
    private func submitGoal() {
        let trimmedText = goalText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }
        
        HapticManager.shared.playSuccessNotification()
        onSubmit(trimmedText)
        dismissOverlay()
    }
    
    private func dismissOverlay() {
        isFocused = false
        goalText = ""
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded = false
        }
    }
}

#Preview("Search Bar") {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            FloatingSearchBar(
                searchText: .constant(""),
                isExpanded: .constant(false),
                placeholder: "Search entries..."
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
}

#Preview("Search + Add Bar") {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            FloatingSearchAddBar(
                searchText: .constant(""),
                isSearchExpanded: .constant(false),
                isAddExpanded: .constant(false),
                searchPlaceholder: "Search goals..."
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
}
