import SwiftUI

// MARK: - Optimized Tab View with Lazy Loading
struct OptimizedTabView: View {
    @Binding var selectedTab: HomeTab
    @ObservedObject var viewModel: TranscriptViewModel
    @ObservedObject var goalsManager: GoalsManager
    
    // Cache screen calculations once
    @State private var cachedScreenWidth = UIScreen.main.bounds.width
    @State private var cachedScreenHeight = UIScreen.main.bounds.height
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selectedTab) {
                // Reflections Tab - Always loaded since it's the default
                reflectionsTabContent
                    .frame(width: cachedScreenWidth)
                    .tag(HomeTab.reflections)
                
                // Entries Tab - Lazy loaded only when selected
                Group {
                    if selectedTab == .entries {
                        EntriesView()
                            .frame(width: cachedScreenWidth)
                    } else {
                        // Placeholder to maintain TabView structure
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: cachedScreenWidth)
                    }
                }
                .tag(HomeTab.entries)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
            .onAppear {
                // Cache screen dimensions once
                cachedScreenWidth = geometry.size.width
                cachedScreenHeight = geometry.size.height
            }
        }
    }
    
    private var reflectionsTabContent: some View {
        VStack(spacing: 0) {
            // Use the optimized ReflectionsInputCard
            ReflectionsInputCard(
                viewModel: viewModel,
                goalsManager: goalsManager
            )
            
            Spacer()
            
            // Show transcript details or floating generate button
            if let transcript = viewModel.transcript {
                TranscriptDetailsCard(transcript: transcript)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            } else if shouldShowFloatingGenerateButton {
                FloatingGenerateButton(
                    viewModel: viewModel,
                    goalsManager: goalsManager
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
    }
    
    private var shouldShowFloatingGenerateButton: Bool {
        !viewModel.isProcessing && 
        viewModel.transcript == nil && 
        !goalsManager.goals.isEmpty
    }
}

// MARK: - Floating Generate Button (Optimized)
struct FloatingGenerateButton: View {
    @ObservedObject var viewModel: TranscriptViewModel
    @ObservedObject var goalsManager: GoalsManager
    
    // Cached computation for ready state
    @State private var isReadyToGenerate = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ClickyButton(
                    text: "Generate from Goals",
                    isDisabled: !isReadyToGenerate || viewModel.isProcessing
                ) {
                    generateFromGoals()
                }
                .opacity(viewModel.isProcessing || !isReadyToGenerate ? 0.6 : 1.0)
                Spacer()
            }
            .keyboardAware(behavior: .none, additionalPadding: 100)
        }
        .onAppear {
            updateReadyState()
        }
        .onChange(of: goalsManager.goals) { _, _ in
            updateReadyState()
        }
    }
    
    private func updateReadyState() {
        isReadyToGenerate = !goalsManager.goals.isEmpty
    }
    
    private func generateFromGoals() {
        let goalsText = goalsManager.goalContextForGeneration.map { "- \($0)" }.joined(separator: "\n")
        viewModel.generateTranscript(text: goalsText, goals: goalsManager.goalContextForGeneration)
    }
}

// MARK: - Transcript Details Card (Optimized)
struct TranscriptDetailsCard: View {
    let transcript: TranscriptModel
    @State private var isShowingDetails = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    isShowingDetails = true
                }) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Insights Ready")
                                .font(.serifLabel).fontWeight(.semibold)
                                .foregroundColor(LinearColors.textPrimary)
                            
                            Text("Tap to view your personalized reflection")
                                .font(.serifCaption)
                                .foregroundColor(LinearColors.textSecondary)
                                .lineLimit(1)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.serifCaption)
                            .foregroundColor(LinearColors.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .coStarCard()
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Spacer()
            }
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $isShowingDetails) {
            // Use existing transcript detail view from HomeScreen
            Text(transcript.processedTranscript ?? "No transcript available")
                .padding()
        }
    }
}

// MARK: - Tab Item Data Structure
struct TabItem {
    let tab: HomeTab
    let icon: String
    let title: String
}