//
//  DarkGoalsView.swift
//  Retrospect
//
//  Goals management view — rich expandable cards with
//  description, motivation, and action items.
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

    init(from string: String) {
        let lower = string.lowercased()
        if lower.contains("health") || lower.contains("fitness") {
            self = .health
        } else if lower.contains("career") || lower.contains("work") {
            self = .career
        } else if lower.contains("relationship") {
            self = .relationships
        } else if lower.contains("personal") || lower.contains("growth") {
            self = .personal
        } else if lower.contains("skill") || lower.contains("learning") {
            self = .skills
        } else if lower.contains("finance") || lower.contains("money") {
            self = .finance
        } else {
            self = .other
        }
    }

    static func categorize(_ goal: String) -> GoalCategory {
        let lowercased = goal.lowercased()

        if lowercased.contains("health") || lowercased.contains("exercise") || lowercased.contains("workout") ||
           lowercased.contains("gym") || lowercased.contains("weight") || lowercased.contains("fitness") ||
           lowercased.contains("run") || lowercased.contains("sleep") || lowercased.contains("diet") ||
           lowercased.contains("eat") || lowercased.contains("meditation") || lowercased.contains("yoga") ||
           lowercased.contains("walk") || lowercased.contains("body") || lowercased.contains("muscle") {
            return .health
        }
        if lowercased.contains("work") || lowercased.contains("career") || lowercased.contains("job") ||
           lowercased.contains("promotion") || lowercased.contains("business") || lowercased.contains("professional") {
            return .career
        }
        if lowercased.contains("relationship") || lowercased.contains("friend") || lowercased.contains("family") ||
           lowercased.contains("partner") || lowercased.contains("dating") || lowercased.contains("social") {
            return .relationships
        }
        if lowercased.contains("learn") || lowercased.contains("skill") || lowercased.contains("study") ||
           lowercased.contains("read") || lowercased.contains("course") || lowercased.contains("book") {
            return .skills
        }
        if lowercased.contains("money") || lowercased.contains("save") || lowercased.contains("invest") ||
           lowercased.contains("budget") || lowercased.contains("finance") {
            return .finance
        }
        if lowercased.contains("habit") || lowercased.contains("mindful") || lowercased.contains("confident") ||
           lowercased.contains("stress") || lowercased.contains("mental") || lowercased.contains("growth") {
            return .personal
        }
        return .other
    }
}

// MARK: - Dark Goals View

struct DarkGoalsView: View {
    @ObservedObject private var goalsManager = GoalsManager.shared
    @State private var searchText = ""
    @State private var newGoalText = ""
    @State private var isSearching = false
    @State private var isAdding = false
    @State private var expandedGoalID: UUID?

    @State private var headerOpacity: Double = 0
    @State private var keyboardHeight: CGFloat = 0

    private let headerHeight: CGFloat = 50

    private var filteredGoals: [RichGoal] {
        if searchText.isEmpty {
            return goalsManager.richGoals
        }
        let query = searchText.lowercased()
        return goalsManager.richGoals.filter {
            $0.title.lowercased().contains(query) ||
            $0.goalDescription.lowercased().contains(query) ||
            $0.motivation.lowercased().contains(query)
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if !isSearching && !isAdding {
                    header
                        .opacity(headerOpacity)
                }

                if goalsManager.richGoals.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredGoals) { goal in
                                RichGoalCard(
                                    goal: goal,
                                    isExpanded: expandedGoalID == goal.id,
                                    onTap: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            if expandedGoalID == goal.id {
                                                expandedGoalID = nil
                                            } else {
                                                expandedGoalID = goal.id
                                            }
                                        }
                                        HapticManager.shared.playLightImpact()
                                    },
                                    onDelete: {
                                        deleteGoal(goal)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 140)
                    }
                }

                Spacer(minLength: 0)

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
            Text("Goals")
                .font(.custom("EBGaramond12-Italic", size: 46))
                .foregroundColor(LinearColors.Minimal.textPrimary)

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

    private func deleteGoal(_ goal: RichGoal) {
        HapticManager.shared.playMediumImpact()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if expandedGoalID == goal.id { expandedGoalID = nil }
            goalsManager.removeRichGoal(id: goal.id)
        }
    }
}

// MARK: - Rich Goal Card

struct RichGoalCard: View {
    let goal: RichGoal
    let isExpanded: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    private var category: GoalCategory {
        if goal.category.isEmpty || goal.category == "Other" {
            return GoalCategory.categorize(goal.title)
        }
        return GoalCategory(from: goal.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Always visible: collapsed header
            collapsedHeader

            if isExpanded && goal.hasDepth {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(0)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearColors.Minimal.backgroundCardLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isExpanded ? category.color.opacity(0.25) : LinearColors.Minimal.border,
                            lineWidth: 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .confirmationDialog("Delete Goal", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this goal?")
        }
    }

    // MARK: - Collapsed header

    private var collapsedHeader: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(category.color)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .lineLimit(isExpanded ? nil : 2)

                if !isExpanded && !goal.goalDescription.isEmpty {
                    Text(goal.goalDescription)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 14)

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(LinearColors.Minimal.textTertiary)

                if !isExpanded {
                    Image(systemName: category.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(category.color.opacity(0.7))
                }
            }
            .padding(.trailing, 14)
        }
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Rectangle()
                .fill(LinearColors.Minimal.border.opacity(0.5))
                .frame(height: 0.5)
                .padding(.horizontal, 14)

            // Full description
            if !goal.goalDescription.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(goal.goalDescription)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.85))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 30)
            }

            // Motivation / Why this matters
            if !goal.motivation.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Why this matters")
                        .font(.custom("EBGaramond12-Italic", size: 18))
                        .foregroundColor(category.color.opacity(0.9))

                    Text(goal.motivation)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 30)
            }

            // Action items
            if !goal.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next steps")
                        .font(.custom("EBGaramond12-Italic", size: 18))
                        .foregroundColor(category.color.opacity(0.9))

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(goal.actionItems, id: \.self) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .strokeBorder(category.color.opacity(0.5), lineWidth: 1.5)
                                    .frame(width: 16, height: 16)
                                    .padding(.top, 2)

                                Text(item)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 30)
            }

            // Category badge + delete
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .font(.system(size: 11, weight: .medium))
                    Text(category.rawValue)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(category.color.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(category.color.opacity(0.1))
                )

                Spacer()

                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(LinearColors.Minimal.textTertiary)
                        .padding(8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()

        DarkGoalsView()
    }
}
