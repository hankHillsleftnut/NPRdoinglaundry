//
//  DarkGoalsView.swift
//  Retrospect
//
//  Goals management view in dark UI
//

import SwiftUI

// MARK: - Goal Category
enum GoalCategory: String, CaseIterable {
    case health = "Health & Fitness"
    case career = "Career & Work"
    case relationships = "Relationships"
    case personal = "Personal Growth"
    case skills = "Skills & Learning"
    case finance = "Finance"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .health: return "heart.fill"
        case .career: return "briefcase.fill"
        case .relationships: return "person.2.fill"
        case .personal: return "sparkles"
        case .skills: return "book.fill"
        case .finance: return "dollarsign.circle.fill"
        case .other: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .health: return LinearColors.Minimal.error
        case .career: return LinearColors.Minimal.iconBlue
        case .relationships: return LinearColors.Minimal.iconPink
        case .personal: return LinearColors.Minimal.iconPurple
        case .skills: return LinearColors.Minimal.iconOrange
        case .finance: return LinearColors.Minimal.iconGreen
        case .other: return LinearColors.Minimal.accent
        }
    }
    
    // Keywords to detect category from goal text
    static func categorize(_ goal: String) -> GoalCategory {
        let lowercased = goal.lowercased()
        
        // Health & Fitness
        if lowercased.contains("health") || lowercased.contains("exercise") || lowercased.contains("workout") ||
           lowercased.contains("gym") || lowercased.contains("weight") || lowercased.contains("fitness") ||
           lowercased.contains("run") || lowercased.contains("sleep") || lowercased.contains("diet") ||
           lowercased.contains("eat") || lowercased.contains("meditation") || lowercased.contains("yoga") ||
           lowercased.contains("walk") || lowercased.contains("body") || lowercased.contains("muscle") {
            return .health
        }
        
        // Career & Work
        if lowercased.contains("work") || lowercased.contains("career") || lowercased.contains("job") ||
           lowercased.contains("promotion") || lowercased.contains("business") || lowercased.contains("professional") ||
           lowercased.contains("office") || lowercased.contains("meeting") || lowercased.contains("project") ||
           lowercased.contains("deadline") || lowercased.contains("boss") || lowercased.contains("colleague") ||
           lowercased.contains("salary") || lowercased.contains("interview") {
            return .career
        }
        
        // Relationships
        if lowercased.contains("relationship") || lowercased.contains("friend") || lowercased.contains("family") ||
           lowercased.contains("partner") || lowercased.contains("dating") || lowercased.contains("marriage") ||
           lowercased.contains("social") || lowercased.contains("connect") || lowercased.contains("love") ||
           lowercased.contains("parent") || lowercased.contains("sibling") || lowercased.contains("child") ||
           lowercased.contains("mom") || lowercased.contains("dad") || lowercased.contains("wife") ||
           lowercased.contains("husband") || lowercased.contains("boyfriend") || lowercased.contains("girlfriend") {
            return .relationships
        }
        
        // Skills & Learning
        if lowercased.contains("learn") || lowercased.contains("skill") || lowercased.contains("study") ||
           lowercased.contains("read") || lowercased.contains("course") || lowercased.contains("class") ||
           lowercased.contains("practice") || lowercased.contains("master") || lowercased.contains("improve") ||
           lowercased.contains("develop") || lowercased.contains("language") || lowercased.contains("coding") ||
           lowercased.contains("programming") || lowercased.contains("education") || lowercased.contains("book") {
            return .skills
        }
        
        // Finance
        if lowercased.contains("money") || lowercased.contains("save") || lowercased.contains("invest") ||
           lowercased.contains("budget") || lowercased.contains("finance") || lowercased.contains("debt") ||
           lowercased.contains("income") || lowercased.contains("expense") || lowercased.contains("retire") ||
           lowercased.contains("wealth") || lowercased.contains("financial") || lowercased.contains("$") {
            return .finance
        }
        
        // Personal Growth
        if lowercased.contains("habit") || lowercased.contains("mindful") || lowercased.contains("confident") ||
           lowercased.contains("anxiety") || lowercased.contains("stress") || lowercased.contains("therapy") ||
           lowercased.contains("self") || lowercased.contains("mental") || lowercased.contains("emotional") ||
           lowercased.contains("balance") || lowercased.contains("gratitude") || lowercased.contains("journal") ||
           lowercased.contains("growth") || lowercased.contains("better") || lowercased.contains("goal") {
            return .personal
        }
        
        return .other
    }
}

struct DarkGoalsView: View {
    @ObservedObject private var goalsManager = GoalsManager.shared
    @State private var searchText = ""
    @State private var newGoalText = ""
    @State private var isSearching = false
    @State private var isAdding = false
    
    @State private var headerOpacity: Double = 0
    @State private var keyboardHeight: CGFloat = 0
    
    // Header styling
    private let headerHeight: CGFloat = 50
    
    // Filtered goals based on search
    private var filteredGoals: [String] {
        if searchText.isEmpty {
            return goalsManager.goals
        }
        return goalsManager.goals.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Group goals by category
    private func goalsFor(category: GoalCategory) -> [String] {
        filteredGoals.filter { GoalCategory.categorize($0) == category }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                if !isSearching && !isAdding {
                    header
                        .opacity(headerOpacity)
                }
                
                // Goals List
                if goalsManager.goals.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Group goals by category
                            ForEach(GoalCategory.allCases, id: \.self) { category in
                                let categoryGoals = goalsFor(category: category)
                                if !categoryGoals.isEmpty {
                                    // Section header
                                    HStack {
                                        Text(category.rawValue)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(LinearColors.Minimal.textTertiary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 4)
                                    
                                    // Grouped goals container
                                    GroupedGoalsContainer(
                                        goals: categoryGoals,
                                        category: category,
                                        onDelete: { goal in
                                            deleteGoal(goal)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 140)
                    }
                    .mask(
                        VStack(spacing: 0) {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black.opacity(0.3), location: 0.3),
                                    .init(color: .black.opacity(0.7), location: 0.6),
                                    .init(color: .black, location: 1.0)
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
                
                // Floating search + add bar at bottom (above keyboard when active)
                GoalsFloatingBar(
                    searchText: $searchText,
                    isSearching: $isSearching,
                    newGoalText: $newGoalText,
                    isAdding: $isAdding,
                    onSubmitGoal: { goal in
                        goalsManager.addGoal(goal)
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 80 : 8)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: keyboardHeight)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isAdding)
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
    
    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            // Title
            Text("Goals")
                .font(.custom("EBGaramond12-Italic", size: 46))
                .foregroundColor(LinearColors.Minimal.textPrimary)
            
            // Goal count pill
            Text("\(goalsManager.goalsCount)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(LinearColors.Minimal.backgroundCard)
                        .overlay(
                            Capsule()
                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                        )
                )
            
            Spacer()
        }
        .frame(height: headerHeight)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(LinearColors.Minimal.backgroundCard)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "scope")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            }
            
            VStack(spacing: 8) {
                Text("No Goals Yet")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                
                Text("Add goals to personalize your\npodcast insights")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private func deleteGoal(_ goal: String) {
        HapticManager.shared.playMediumImpact()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            goalsManager.removeGoal(goal)
        }
    }
}

// MARK: - Grouped Goals Container
struct GroupedGoalsContainer: View {
    let goals: [String]
    let category: GoalCategory
    let onDelete: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(goals.enumerated()), id: \.element) { index, goal in
                GroupedGoalRow(
                    goal: goal,
                    category: category,
                    onDelete: { onDelete(goal) }
                )
                
                // Divider (not after last item)
                if index < goals.count - 1 {
                    HStack {
                        Spacer()
                            .frame(width: 58) // Offset from left (icon width + padding)
                        Rectangle()
                            .fill(LinearColors.Minimal.border)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearColors.Minimal.backgroundCardLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - Individual Goal Row (within grouped container)
struct GroupedGoalRow: View {
    let goal: String
    let category: GoalCategory
    let onDelete: () -> Void
    
    @State private var showDeleteConfirm = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(category.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(category.color)
            }
            
            // Goal text
            Text(goal)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Delete button
            Button(action: {
                showDeleteConfirm = true
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .confirmationDialog("Delete Goal", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this goal?")
        }
    }
}


#Preview {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()
        
        DarkGoalsView()
    }
}


