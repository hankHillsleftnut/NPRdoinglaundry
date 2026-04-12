import SwiftUI
import Combine

// MARK: - Reflections Input State Management
class ReflectionsInputState: ObservableObject {
    @Published var inputText = ""
    @Published var isGenerating = false
    @Published var showingErrorAlert = false
    @Published var animateGeneration = false
    
    // Animation states
    @Published var isAppearing = true
    @Published var inputOffset: CGFloat = 100
    
    // Debouncing
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceDelay: TimeInterval = 0.3
    
    init() {
        // Initialization complete - using shared KeyboardManager instead
    }
    
    func onInputTextChange(_ newText: String) {
        inputText = newText
        
        // Debounce expensive operations
        debounceWorkItem?.cancel()
        debounceWorkItem = DispatchWorkItem { [weak self] in
            // Perform any expensive text processing here
            self?.processTextInput(newText)
        }
        
        if let workItem = debounceWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        }
    }
    
    private func processTextInput(_ text: String) {
        // Add any expensive text processing logic here
        // This runs only after user stops typing for 0.3 seconds
    }
    
    func startGeneration() {
        isGenerating = true
        animateGeneration = true
    }
    
    func stopGeneration() {
        isGenerating = false
        animateGeneration = false
    }
}

// MARK: - Reflections Input Card Component
struct ReflectionsInputCard: View {
    @StateObject private var inputState = ReflectionsInputState()
    @ObservedObject var viewModel: TranscriptViewModel
    @ObservedObject var goalsManager: GoalsManager
    @FocusState private var focusedField: InputField?
    
    // Cached screen calculations
    @State private var cachedScreenWidth = UIScreen.main.bounds.width
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth = cachedScreenWidth - (Layout.cardHorizontalPadding * 2) - (Layout.cardPeekAmount * 2)
            let cardHeight = cardWidth / Layout.cardAspectRatio
            let textFieldHeight = cardHeight - 120
            
            HStack {
                VStack(spacing: 0) {
                    // Title
                    HStack {
                        Text("Weekly Reflections")
                            .font(.serifHeadline).fontWeight(.bold)
                            .foregroundColor(LinearColors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Enhanced Text Input
                    ZStack(alignment: .topLeading) {
                        if inputState.inputText.isEmpty {
                            Text("What patterns did you notice this week? What challenged you, and what felt meaningful?")
                                .font(.serifBody)
                                .foregroundColor(LinearColors.textPlaceholder)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                        
                        TextEditor(text: Binding(
                            get: { inputState.inputText },
                            set: { inputState.onInputTextChange($0) }
                        ))
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .focused($focusedField, equals: .reflections)
                        .scrollContentBackground(.hidden)
                    }
                    .frame(height: textFieldHeight)
                    
                    // Goals Button
                    HStack {
                        Button(action: { /* Goals action */ }) {
                            HStack(spacing: 8) {
                                Image(systemName: "target")
                                    .font(.serifLabel)
                                Text("Goals (\(goalsManager.goals.count))")
                                    .font(.serifLabel).fontWeight(.medium)
                            }
                            .foregroundColor(LinearColors.buttonText)
                        }
                        .coStarSecondaryButton()
                        
                        Spacer()
                        
                        // Generate Button
                        ClickyButton(
                            text: inputState.isGenerating ? "Generating..." : "Generate Insights",
                            isDisabled: inputState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || inputState.isGenerating
                        ) {
                            generateTranscript()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .frame(width: cardWidth, height: cardHeight)
                .padding(.leading, Layout.cardHorizontalPadding + Layout.cardPeekAmount)
                
                Spacer()
            }
        }
        .frame(height: nil)
        .offset(y: inputState.isAppearing ? inputState.inputOffset : 0)
        .opacity(inputState.isAppearing ? 0 : 1)
        .coStarCard()
        .onAppear {
            // Cache screen width once
            cachedScreenWidth = UIScreen.main.bounds.width
            
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                inputState.isAppearing = false
            }
        }
        .alert("Error", isPresented: $inputState.showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    private func generateTranscript() {
        guard !inputState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        inputState.startGeneration()
        focusedField = nil // Dismiss keyboard
        
        viewModel.generateTranscript(text: inputState.inputText, goals: goalsManager.goalContextForGeneration)
        
        // Monitor completion
        let cancellable = viewModel.$isProcessing
            .sink { isProcessing in
                if !isProcessing {
                    inputState.stopGeneration()
                    if viewModel.errorMessage != nil {
                        inputState.showingErrorAlert = true
                    }
                }
            }
        
        // Store cancellable to prevent deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cancellable.cancel()
        }
    }
}