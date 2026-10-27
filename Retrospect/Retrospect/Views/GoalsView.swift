import SwiftUI

struct GoalsView: View {
    @ObservedObject private var goalsManager = GoalsManager.shared
    @State private var newGoalText = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            // Clean light grey background (CoStar style)
            LinearColors.backgroundGrey
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Your Goals")
                        .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                        .foregroundColor(LinearColors.textPrimary)

                    Text("\(goalsManager.goalsCount) active goals")
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textSecondary)
                }
                .padding(.top, 20)
                .padding(.horizontal)

                // Add Goal Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add New Goal")
                        .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                        .foregroundColor(LinearColors.textPrimary)
                        .padding(.horizontal, 4)

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .fill(LinearColors.inputBackground)
                            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)

                        // Separate stroke layer
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .strokeBorder(
                                isInputFocused ? LinearColors.accent : LinearColors.border,
                                lineWidth: isInputFocused ? 1.5 : 1.0
                            )

                        HStack {
                            // Placeholder and TextField
                            ZStack(alignment: .leading) {
                                if newGoalText.isEmpty {
                                    Text("What do you want to achieve this week?")
                                        .foregroundColor(LinearColors.secondaryText.opacity(0.7))
                                        .allowsHitTesting(false)
                                        .opacity(isInputFocused ? 0 : 1)
                                }

                                TextField("", text: $newGoalText)
                                    .focused($isInputFocused)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(LinearColors.primaryText)
                                    .onSubmit {
                                        addGoal()
                                    }
                            }

                            // Add Button
                            Button(action: addGoal) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(newGoalText.trimmingCharacters(in: .whitespaces).isEmpty ?
                                        LinearColors.secondaryText.opacity(0.5) : LinearColors.accent)
                                    .font(.title2)
                            }
                            .disabled(newGoalText.trimmingCharacters(in: .whitespaces).isEmpty)
                            .opacity(newGoalText.isEmpty ? 0 : 1)
                            .animation(.easeInOut(duration: 0.2), value: newGoalText.isEmpty)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .frame(height: 55)
                    .animation(.easeInOut(duration: 0.2), value: isInputFocused)

                    if !newGoalText.isEmpty {
                        HStack {
                            Text("Press Enter to add goal")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(LinearColors.secondaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)

                // Goals List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if goalsManager.goals.isEmpty {
                            // Empty State
                            VStack(spacing: 16) {
                                Image(systemName: "target")
                                    .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                                    .foregroundColor(LinearColors.secondaryText)

                                Text("No goals yet")
                                    .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                    .foregroundColor(LinearColors.primaryText)

                                Text("Add your first goal to get started with personalized insights")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(LinearColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(goalsManager.goals, id: \.self) { goal in
                                GoalPill(
                                    goal: goal,
                                    onRemove: {
                                        removeGoal(goal)
                                    },
                                    onToggle: {
                                        // Toggle functionality not implemented in GoalsManager
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }

                Spacer()
            }
        }
        .overlay(
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(LinearColors.secondaryText)
                    }
                }
                .padding()
                Spacer()
            }
        )
    }

    private func addGoal() {
        HapticManager.shared.playSuccessNotification() // Goal added successfully
        goalsManager.addGoal(newGoalText)
        newGoalText = ""
        isInputFocused = false
    }

    private func removeGoal(_ goal: String) {
        HapticManager.shared.playMediumImpact() // Goal removal feedback
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            goalsManager.removeGoal(goal)
        }
    }
}

struct GoalPill: View {
    let goal: String
    let onRemove: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Goal Text
            Text(goal)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LinearColors.textPrimary)
                .lineLimit(2)

            Spacer()

            // Action Buttons
            HStack(spacing: 12) {
                // Remove Button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .strokeBorder(
                    LinearColors.cardBorder,
                    lineWidth: 1
                )
        )
    }
}

struct GoalsView_Previews: PreviewProvider {
    static var previews: some View {
        GoalsView()
    }
}
