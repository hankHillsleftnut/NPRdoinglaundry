import SwiftUI
import AVKit

// Enhanced Linear-inspired color palette
struct LinearColors {
    static let background = Color(red: 0.06, green: 0.06, blue: 0.07)
    static let primaryText = Color.white
    static let secondaryText = Color.gray
    static let accent = Color(red: 0.2, green: 0.55, blue: 1)
    static let inputBackground = Color(red: 0.12, green: 0.12, blue: 0.13)
    static let border = Color(red: 0.2, green: 0.2, blue: 0.22)
    static let successGreen = Color(red: 0.3, green: 0.8, blue: 0.5)
    static let warningYellow = Color(red: 1.0, green: 0.8, blue: 0.2)
}

// Enhanced Text Input with Focused State
struct EnhancedTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearColors.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFocused ? LinearColors.accent : LinearColors.border, lineWidth: 1.5)
                )
            
            Group {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(LinearColors.secondaryText)
                        .padding(12)
                        .allowsHitTesting(false)
                        .opacity(isFocused ? 0 : 1)
                        .animation(.easeInOut(duration: 0.15), value: isFocused)
                        .transition(.opacity)
                }
            }
            
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundColor(LinearColors.primaryText)
                .padding(12)
                .focused($isFocused)
                .lineSpacing(0)
                .frame(minHeight: 100, alignment: .topLeading)
        }
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// Animated Button Style with Haptic Feedback
struct AnimatedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(LinearColors.accent)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _ in
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
    }
}

struct ContentView: View {
    @StateObject private var viewModel: TranscriptViewModel
    @State private var inputText = ""
    @State private var goals = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isShowingDetails = false
    @State private var animateGeneration = false
    
    // New state for launch animations
    @State private var isAppearing = true
    @State private var headerOffset: CGFloat = 50
    @State private var inputOffset: CGFloat = 100
    @State private var buttonOffset: CGFloat = 150
    
    init() {
        let openAIService = OpenAIService(apiKey: "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")
        let textToSpeechService = TextToSpeechService()
        _viewModel = StateObject(wrappedValue: TranscriptViewModel(
            openAIService: openAIService,
            textToSpeechService: textToSpeechService
        ))
    }
    
    var body: some View {
        ZStack {
            LinearColors.background.edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 24) {
                // Header with Launch Animation
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Retrospect")
                            .font(.systemGaramond(size: 36, weight: .bold))
                            .foregroundColor(LinearColors.primaryText)
                            .offset(x: isAppearing ? headerOffset : 0)
                            .opacity(isAppearing ? 0 : 1)
                        
                        Spacer()
                        
                        Image(systemName: "sparkles")
                            .foregroundColor(LinearColors.accent)
                            .scaleEffect(animateGeneration ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animateGeneration)
                            .offset(x: isAppearing ? headerOffset : 0)
                            .opacity(isAppearing ? 0 : 1)
                    }
                    
                    Text("Your Weekly Life Insights")
                        .font(.subheadline)
                        .foregroundColor(LinearColors.secondaryText)
                        .offset(x: isAppearing ? headerOffset : 0)
                        .opacity(isAppearing ? 0 : 1)
                }
                .animation(.spring(response: 0.7, dampingFraction: 0.7, blendDuration: 0.5)
                    .delay(0.2), value: isAppearing)
                
                // Input Sections with Progressive Disclosure and Launch Animation
                VStack(spacing: 16) {
                    // Weekly Reflections
                    InputSection(
                        title: "Weekly Reflections",
                        placeholder: "Capture your thoughts, challenges, and experiences...",
                        text: $inputText
                    )
                    .offset(y: isAppearing ? inputOffset : 0)
                    .opacity(isAppearing ? 0 : 1)
                    
                    // Goals
                    InputSection(
                        title: "This Week's Goals",
                        placeholder: "List your goals (comma-separated)",
                        text: $goals
                    )
                    .offset(y: isAppearing ? inputOffset + 50 : 0)
                    .opacity(isAppearing ? 0 : 1)
                }
                .animation(.spring(response: 0.7, dampingFraction: 0.7, blendDuration: 0.5)
                    .delay(0.4), value: isAppearing)
                
                // Generate Button with Launch Animation
                Button(action: generateTranscript) {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Generate Insights")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AnimatedButtonStyle())
                .disabled(inputText.isEmpty || goals.isEmpty || viewModel.isProcessing)
                .offset(y: isAppearing ? buttonOffset : 0)
                .opacity(isAppearing ? 0 : 1)
                .animation(.spring(response: 0.7, dampingFraction: 0.7, blendDuration: 0.5)
                    .delay(0.6), value: isAppearing)
                
                // Enhanced Processing and Error States
                Group {
                    if viewModel.isProcessing {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.accent))
                            Text("Generating insights...")
                                .foregroundColor(LinearColors.secondaryText)
                        }
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                    }
                    
                    if let errorMessage = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                
                // Transcript and Audio Section with Contextual Actions
                if let transcript = viewModel.transcript {
                    VStack(spacing: 12) {
                        Button(action: { isShowingDetails.toggle() }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("View Transcript")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AnimatedButtonStyle())
                        
                        if let audioURL = transcript.audioFileURL {
                            Button(action: { playAudio(url: audioURL) }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Listen to Audio")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(AnimatedButtonStyle())
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .sheet(isPresented: $isShowingDetails) {
                EnhancedTranscriptDetailView(transcript: viewModel.transcript?.processedTranscript ?? "")
            }
            .onAppear {
                // Trigger launch animation
                animateGeneration = true
                
                // Stagger the appearance of elements
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        isAppearing = false
                    }
                }
            }
        }
    }
    
    // Reusable Input Section
    private func InputSection(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(LinearColors.primaryText)
            
            EnhancedTextField(
                placeholder: placeholder,
                text: text
            )
            .frame(minHeight: 100)
        }
    }
    
    private func generateTranscript() {
        let goalsList = goals.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        viewModel.generateTranscript(text: inputText, goals: goalsList)
    }
    
    private func playAudio(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            
            // Haptic feedback for audio play
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        } catch {
            print("Error playing audio: \(error)")
        }
    }
}

// Enhanced Transcript Detail View
struct EnhancedTranscriptDetailView: View {
    let transcript: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            LinearColors.background.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Weekly Insights")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(LinearColors.primaryText)
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = transcript
                            // Haptic feedback for copy
                            let impact = UINotificationFeedbackGenerator()
                            impact.notificationOccurred(.success)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(LinearColors.accent)
                        }
                    }
                    
                    Divider()
                        .background(LinearColors.border)
                    
                    // Markdown-styled text
                    VStack(alignment: .leading, spacing: 12) {
                        // Headers
                        Text("# Weekly Reflection Insights")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(LinearColors.primaryText)
                        
                        // Sections
                        Group {
                            Text("## 🌟 Highlights")
                                .font(.headline)
                                .foregroundColor(LinearColors.accent)
                            
                            Text(transcript)
                                .foregroundColor(LinearColors.primaryText)
                                .lineSpacing(6)
                        }
                    }
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
