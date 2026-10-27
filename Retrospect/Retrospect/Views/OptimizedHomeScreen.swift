import AVKit
import Combine
import LocalAuthentication
import SwiftUI

// MARK: - Performance Optimized Home Screen

struct OptimizedHomeScreen: View {
    // Core ViewModels - kept as StateObjects for performance
    @StateObject private var viewModel = TranscriptViewModel(openAIService: .shared, textToSpeechService: .shared)
    @ObservedObject private var goalsManager = GoalsManager.shared

    // Minimal HomeScreen state - only essential items
    @State private var selectedTab: HomeTab = .reflections
    @State private var showingSplash = true
    @State private var showingNamePrompt = false
    @AppStorage("userName") private var storedUserName: String = ""

    /// Cached expensive computations
    @State private var cachedFirstName: String = ""

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Main Content Area
                    if showingSplash {
                        SplashScreenView(isPresented: $showingSplash)
                            .transition(.opacity)
                    } else {
                        mainContentView(geometry: geometry)
                    }

                    // Bottom Navigation Bar - Always at bottom
                    if !showingSplash {
                        BottomNavigationBar(selectedTab: $selectedTab)
                            .zIndex(1) // Ensure navigation stays on top
                    }

                    // Audio Player Container
                    AudioPlayerContainer(viewModel: viewModel)
                        .zIndex(2)

                    // Name Input Card
                    if showingNamePrompt {
                        NameInputCard(
                            isPresented: $showingNamePrompt,
                            storedUserName: $storedUserName
                        )
                        .zIndex(3)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            setupInitialState()
        }
        .onChange(of: showingSplash) { newValue in
            if !newValue, storedUserName.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingNamePrompt = true
                }
            }
        }
        .onChange(of: storedUserName) { newName in
            // Cache first name computation
            cachedFirstName = newName.components(separatedBy: " ").first ?? newName
        }
    }

    private func mainContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top Navigation Bar
            TopNavigationBar()
                .padding(.horizontal, 24)
                .padding(.top, 8)

            // Optimized Tab Content with Lazy Loading
            OptimizedTabView(
                selectedTab: $selectedTab,
                viewModel: viewModel,
                goalsManager: goalsManager
            )
        }
        .background(
            LinearColors.backgroundGrey
                .ignoresSafeArea()
        )
    }

    private func setupInitialState() {
        // Cache first name on startup
        cachedFirstName = storedUserName.components(separatedBy: " ").first ?? storedUserName

        // Force light mode for consistent performance
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = .light
            }
        }
    }
}

// MARK: - Bottom Navigation Bar Component

struct BottomNavigationBar: View {
    @Binding var selectedTab: HomeTab

    var body: some View {
        NavBarContainer(selectedTab: $selectedTab)
            .keyboardAware(behavior: .none, additionalPadding: Layout.safeAreaBottomOffset + 16)
    }
}

// MARK: - Name Input Card Component

struct NameInputCard: View {
    @Binding var isPresented: Bool
    @Binding var storedUserName: String
    @State private var userName = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        if isPresented {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("Welcome to Retrospect")
                            .font(.serifDisplay)
                            .fontWeight(.bold)
                            .foregroundColor(LinearColors.textPrimary)

                        Text("What should we call you?")
                            .font(.serifBody)
                            .foregroundColor(LinearColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Enter your name", text: $userName)
                            .font(.serifBody)
                            .foregroundColor(LinearColors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: BorderRadius.input)
                                    .fill(LinearColors.inputBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: BorderRadius.input)
                                            .stroke(
                                                isNameFieldFocused ? LinearColors.focusRing : LinearColors.inputBorder,
                                                lineWidth: isNameFieldFocused ? 2 : 1
                                            )
                                    )
                            )
                            .focused($isNameFieldFocused)
                    }

                    HStack(spacing: 12) {
                        Button("Skip") {
                            isPresented = false
                        }
                        .coStarSecondaryButton()

                        Button("Continue") {
                            storedUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
                            isPresented = false
                        }
                        .coStarPrimaryButton()
                        .disabled(userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.card)
                        .fill(LinearColors.cardBackground)
                        .shadow(
                            color: Shadows.cardShadow.color,
                            radius: Shadows.cardShadow.radius,
                            x: Shadows.cardShadow.x,
                            y: Shadows.cardShadow.y
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.card)
                                .stroke(LinearColors.cardBorder, lineWidth: BorderWidth.standard)
                        )
                )
                .padding(.horizontal, 24)
                .coStarCard()

                Spacer()
            }
            .background(
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isNameFieldFocused = false
                    }
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isNameFieldFocused = true
                }
            }
        }
    }
}
