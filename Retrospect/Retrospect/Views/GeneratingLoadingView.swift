import SwiftUI

struct GeneratingLoadingView: View {
    @ObservedObject var viewModel: TranscriptViewModel
    @State private var currentLoadingIndex = 0
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var particleOffset: CGFloat = 0
    
    private let loadingMessages = [
        "Analyzing your reflections...",
        "Connecting patterns...",
        "Generating insights...",
        "Crafting your personalized content...",
        "Almost ready..."
    ]
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Animated loading indicator
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .stroke(LinearColors.accent.opacity(0.3), lineWidth: 3)
                        .frame(width: 80, height: 80)
                    
                    // Inner pulsing circle
                    Circle()
                        .fill(LinearColors.accent)
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulseScale)
                        .opacity(0.8)
                    
                    // Rotating accent
                    Circle()
                        .stroke(LinearColors.accent, lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: rotationAngle))
                        .opacity(0.8)
                }
                .onAppear {
                    // Start animations
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                    
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulseScale = 1.2
                    }
                }
                
                // Loading text
                VStack(spacing: 12) {
                    Text(currentLoadingIndex < loadingMessages.count ? loadingMessages[currentLoadingIndex] : "Finalizing...")
                        .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.5), value: currentLoadingIndex)
                    
                    // Status from view model
                    if !viewModel.processingStatus.isEmpty {
                        Text(viewModel.processingStatus)
                            .font(.serifSubheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 40)
                
                // Progress indicator
                HStack(spacing: 6) {
                    ForEach(0..<loadingMessages.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentLoadingIndex ? LinearColors.accent : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentLoadingIndex ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: currentLoadingIndex)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(Color.black.opacity(0.8))
            )
            .padding(.horizontal, 40)
        }
        .onAppear {
            // Cycle through loading messages
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                if currentLoadingIndex < loadingMessages.count - 1 {
                    currentLoadingIndex += 1
                }
            }
        }
    }
}

struct DeepResearchGeneratingView: View {
    @ObservedObject var viewModel: TranscriptViewModel
    @State private var currentPhase = 0
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var brainPulse: CGFloat = 1.0
    @State private var searchPulse: CGFloat = 1.0
    @State private var timeElapsed: TimeInterval = 0
    @State private var timer: Timer?
    
    private let researchPhases = [
        ResearchPhase(
            title: "Planning Research Strategy",
            description: "AI is analyzing your reflections to identify key research areas",
            icon: "brain.head.profile",
            duration: 30
        ),
        ResearchPhase(
            title: "Searching Scientific Literature",
            description: "Finding relevant studies and expert insights",
            icon: "magnifyingglass",
            duration: 120
        ),
        ResearchPhase(
            title: "Analyzing Research Findings",
            description: "Evaluating sources and extracting key insights",
            icon: "doc.text.magnifyingglass",
            duration: 180
        ),
        ResearchPhase(
            title: "Synthesizing Insights",
            description: "Connecting research to your personal patterns",
            icon: "link.circle",
            duration: 60
        ),
        ResearchPhase(
            title: "Crafting Your Podcast",
            description: "Creating personalized, research-backed content",
            icon: "waveform.and.mic",
            duration: 90
        )
    ]
    
    struct ResearchPhase {
        let title: String
        let description: String
        let icon: String
        let duration: TimeInterval
    }
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Research indicator with brain animation
                ZStack {
                    // Outer research ring
                    Circle()
                        .stroke(LinearColors.deepAccent.opacity(0.3), lineWidth: 3)
                        .frame(width: 100, height: 100)
                    
                    // Brain icon with pulse
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .scaleEffect(brainPulse)
                    
                    // Rotating search rings
                    Circle()
                        .stroke(LinearColors.accent, lineWidth: 4)
                        .frame(width: 100, height: 100)
                        .rotationEffect(Angle(degrees: rotationAngle))
                        .opacity(0.6)
                    
                    Circle()
                        .stroke(LinearColors.deepAccent, lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .rotationEffect(Angle(degrees: -rotationAngle * 0.7))
                        .opacity(0.4)
                }
                .onAppear {
                    withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                    
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        brainPulse = 1.3
                    }
                }
                
                // Current phase information
                VStack(spacing: 16) {
                    if currentPhase < researchPhases.count {
                        let phase = researchPhases[currentPhase]
                        
                        // Phase icon and title
                        HStack(spacing: 12) {
                            Image(systemName: phase.icon)
                                .font(.title2)
                                .foregroundColor(LinearColors.accent)
                                .scaleEffect(searchPulse)
                            
                            Text(phase.title)
                                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        // Phase description
                        Text(phase.description)
                            .font(.serifSubheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Dynamic status from view model
                    if !viewModel.deepResearchProgress.isEmpty {
                        Text(viewModel.deepResearchProgress)
                            .font(.serifSubheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                
                // Phase progress indicators
                HStack(spacing: 8) {
                    ForEach(0..<researchPhases.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentPhase ? LinearColors.accent : Color.white.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .scaleEffect(index == currentPhase ? 1.3 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: currentPhase)
                    }
                }
                
                // Time estimate
                VStack(spacing: 8) {
                    Text("Deep Research in Progress")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("This may take 5-30 minutes depending on research complexity")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    
                    // Time elapsed
                    if timeElapsed > 0 {
                        Text("Time elapsed: \(Int(timeElapsed / 60)):\(String(format: "%02d", Int(timeElapsed) % 60))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(Color.black.opacity(0.8))
            )
            .padding(.horizontal, 30)
        }
        .onAppear {
            // Start icon pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                searchPulse = 1.2
            }
            
            // Start timer for elapsed time
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                timeElapsed += 1
                
                // Update phase based on time elapsed
                updatePhaseBasedOnTime()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func updatePhaseBasedOnTime() {
        var cumulativeTime: TimeInterval = 0
        
        for (index, phase) in researchPhases.enumerated() {
            cumulativeTime += phase.duration
            if timeElapsed <= cumulativeTime {
                if currentPhase != index {
                    currentPhase = index
                }
                break
            }
        }
    }
}

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct InsightGeneratingView: View {
    @ObservedObject var viewModel: TranscriptViewModel
    @State private var currentLoadingIndex = 0
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var particleOffset: CGFloat = 0
    
    private let loadingMessages = [
        "Analyzing your reflections...",
        "Connecting patterns...",
        "Generating insights...",
        "Crafting your personalized content...",
        "Almost ready..."
    ]
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Animated loading indicator
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .stroke(LinearColors.accent.opacity(0.3), lineWidth: 3)
                        .frame(width: 80, height: 80)
                    
                    // Inner pulsing circle
                    Circle()
                        .fill(LinearColors.accent)
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulseScale)
                        .opacity(0.8)
                    
                    // Rotating accent
                    Circle()
                        .stroke(LinearColors.accent, lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: rotationAngle))
                        .opacity(0.8)
                }
                .onAppear {
                    // Start animations
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                    
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulseScale = 1.2
                    }
                }
                
                // Loading text
                VStack(spacing: 12) {
                    Text(currentLoadingIndex < loadingMessages.count ? loadingMessages[currentLoadingIndex] : "Finalizing...")
                        .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.5), value: currentLoadingIndex)
                    
                    // Status from view model
                    if !viewModel.processingStatus.isEmpty {
                        Text(viewModel.processingStatus)
                            .font(.serifSubheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 40)
                
                // Progress indicator
                HStack(spacing: 6) {
                    ForEach(0..<loadingMessages.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentLoadingIndex ? LinearColors.accent : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentLoadingIndex ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: currentLoadingIndex)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(Color.black.opacity(0.8))
            )
            .padding(.horizontal, 40)
        }
        .onAppear {
            // Cycle through loading messages
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                if currentLoadingIndex < loadingMessages.count - 1 {
                    currentLoadingIndex += 1
                }
            }
        }
    }
}
