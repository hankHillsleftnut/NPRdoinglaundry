import SwiftUI
import AVFoundation
import ActivityKit

// MARK: - Mood Types
enum PodcastMood: String, CaseIterable {
    case positive = "positive"
    case neutral = "neutral"
    case reflective = "reflective"
    case energetic = "energetic"
    case calm = "calm"
    case mysterious = "mysterious"
    case happy = "happy"
    case melancholic = "melancholic"
    
    var colors: [Color] {
        switch self {
        case .positive:
            return [
                .orange, .yellow, .red,
                .yellow, LinearColors.backgroundLight, .orange,
                .red, .orange, .yellow
            ]
        case .neutral:
            return [
                .blue, .mint, .cyan,
                .mint, LinearColors.backgroundLight, .mint,
                .cyan, .mint, .blue
            ]
        case .reflective:
            return [
                .purple, .indigo, .blue,
                .indigo, LinearColors.backgroundLight, .indigo,
                .blue, .indigo, .purple
            ]
        case .energetic:
            return [
                .red, .orange, .yellow,
                .orange, .pink, .yellow,
                .yellow, .red, .orange
            ]
        case .calm:
            return [
                .blue, .green, .mint,
                .green, LinearColors.backgroundLight, .mint,
                .mint, .blue, .green
            ]
        case .mysterious:
            return [
                .purple, .indigo, LinearColors.charcoalBase,
                .indigo, LinearColors.textSecondary, .purple,
                LinearColors.charcoalBase, .purple, .indigo
            ]
        case .happy:
            return [
                .yellow, .orange, .pink,
                .orange, LinearColors.backgroundLight, .pink,
                .pink, .yellow, .orange
            ]
        case .melancholic:
            return [
                .blue, .purple, LinearColors.textSecondary,
                .purple, LinearColors.backgroundLight, LinearColors.textSecondary,
                LinearColors.textSecondary, .blue, .purple
            ]
        }
    }
    
    var animationSpeed: Double {
        switch self {
        case .energetic, .happy:
            return 0.8
        case .positive:
            return 1.2
        case .calm, .reflective, .melancholic:
            return 2.0
        case .neutral, .mysterious:
            return 1.5
        }
    }
    
    var intensity: Double {
        switch self {
        case .energetic, .happy:
            return 0.15
        case .positive:
            return 0.12
        case .calm, .reflective:
            return 0.08
        case .neutral, .mysterious, .melancholic:
            return 0.10
        }
    }
    
    var displayName: String {
        switch self {
        case .positive: return "Positive"
        case .neutral: return "Neutral"
        case .reflective: return "Reflective"
        case .energetic: return "Energetic"
        case .calm: return "Calm"
        case .mysterious: return "Mysterious"
        case .happy: return "Happy"
        case .melancholic: return "Melancholic"
        }
    }
}

// MARK: - Audio Session Manager
class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
}

// MARK: - Grain Effect
struct GrainEffect: View {
    @State private var time: CGFloat = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, size in
                context.addFilter(.colorMatrix(
                    .init(
//                        .monochrome(color: .white, intensity: 1)
                    )
                ))
                
                let scale: CGFloat = 1.2
                let xOffset = CGFloat(time * 10).truncatingRemainder(dividingBy: size.width * scale)
                let yOffset = CGFloat(time * 8).truncatingRemainder(dividingBy: size.height * scale)
                
                context.drawLayer { ctx in
                    for _ in 0..<2000 {
                        let x = CGFloat.random(in: -xOffset...(size.width * scale - xOffset))
                        let y = CGFloat.random(in: -yOffset...(size.height * scale - yOffset))
                        let rect = CGRect(x: x, y: y, width: 1, height: 1)
                        ctx.fill(Path(rect), with: .color(.white.opacity(0.1)))
                    }
                }
            }
            .onChange(of: timeline.date) { _ in
                time += 1/30
            }
            .blendMode(.overlay)
            .opacity(0.15)
        }
    }
}

// MARK: - Animated Mesh Gradient View
struct AnimatedMeshGradient: View {
    let mood: PodcastMood
    
    private func getAnimatedPoints(date: Date) -> [SIMD2<Float>] {
        let basePoints: [(x: CGFloat, y: CGFloat)] = [
            (-0.3, -0.3), (0.5, -0.3), (1.3, -0.3),      // Top row
            (-0.3, 0.5), (0.5, 0.5), (1.3, 0.5),         // Middle row
            (-0.3, 1.3), (0.5, 1.3), (1.3, 1.3)          // Bottom row
        ]
        
        // Very slow breathing cycle (about 6-8 seconds per cycle)
        let breathingPhase = date.timeIntervalSince1970 * 0.008
        
        return basePoints.enumerated().map { index, point in
            let normalizedIndex = Double(index) / Double(basePoints.count)
            let timeOffset = normalizedIndex * .pi * 2  // Spread movement across points
            
            // Create a breathing cycle with easing
            let breathCycle = (sin(breathingPhase + timeOffset) * 0.5 + 0.5) // Normalized 0 to 1
            let easedBreathCycle = sin(breathCycle * .pi) // Apply easing for more natural movement
            
            // Calculate distance from center for radial movement
            let distanceFromCenter = sqrt(
                pow(point.x - 0.5, 2) + pow(point.y - 0.5, 2)
            )
            
            // Gentler breathing movement
            let breathingIntensity = mood.intensity * 0.6 // Reduced intensity
            let breathingAmount = easedBreathCycle * breathingIntensity
            
            // Move points slightly towards/away from center
            let directionX = (point.x - 0.5) / (distanceFromCenter + 0.01)
            let directionY = (point.y - 0.5) / (distanceFromCenter + 0.01)
            
            // Very subtle rotation (about 15-20 seconds per cycle)
            let rotationPhase = breathingPhase * 0.05
            let rotationAmount = sin(rotationPhase) * 0.01 // Reduced rotation
            
            // Combine breathing and subtle rotation
            let xOffset = directionX * breathingAmount + 
                         cos(rotationPhase) * rotationAmount * (point.y - 0.5)
            let yOffset = directionY * breathingAmount - 
                         sin(rotationPhase) * rotationAmount * (point.x - 0.5)
            
            // Calculate final positions with smooth clamping
            let finalX = point.x + xOffset
            let finalY = point.y + yOffset
            
            // Smoother clamping function
            let clampedX = -0.3 + (1.6 * (1 / (1 + exp(-3 * (finalX + 0.3)))))
            let clampedY = -0.3 + (1.6 * (1 / (1 + exp(-3 * (finalY + 0.3)))))
            
            return SIMD2<Float>(
                Float(clampedX),
                Float(clampedY)
            )
        }
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30, paused: false)) { timeline in
            ZStack {
                // Base gradient with more blur for softer effect
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: getAnimatedPoints(date: timeline.date),
                    colors: mood.colors
                )
                .blur(radius: 45)  // Increased blur for softer edges
                
                // Sharper overlay gradient
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: getAnimatedPoints(date: timeline.date),
                    colors: mood.colors
                )
                .opacity(0.6)  // Reduced opacity for softer look
                
                // Grain effect overlay
                GrainEffect()
                    .opacity(0.08)  // Reduced grain for smoother appearance
            }
        }
    }
}

struct AudioPlayerView: View {
    let transcript: String
    let mood: String?
    let generationType: GenerationType?
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var isPlaying: Bool
    @Binding var isExpanded: Bool
    
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var wordLines: [[String]] = []
    @State private var currentLineIndex = 0
    @State private var liveActivityID: String?
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var draggedProgress: Double = 0
    @State private var showTranscript = false
    
    // Animation states
    @State private var animateBackground = false
    @State private var animateWaveform = false
    
    private let wordsPerLine = 8
    private let gradientColors = [
        Color(red: 0.85, green: 0.47, blue: 0.36),  // Main accent
        Color(red: 0.95, green: 0.55, blue: 0.45),  // Lighter accent
        Color(red: 0.75, green: 0.35, blue: 0.25)   // Darker accent
    ]
    
    // Convert mood string to PodcastMood enum
    private var podcastMood: PodcastMood {
        guard let moodString = mood else { return .neutral }
        return PodcastMood(rawValue: moodString.lowercased()) ?? .neutral
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated background
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: animateBackground ? .topLeading : .bottomTrailing,
                    endPoint: animateBackground ? .bottomTrailing : .topLeading
                )
                .opacity(0.15)
                .blur(radius: 20)
                .animation(
                    Animation.easeInOut(duration: 3.0)
                        .repeatForever(autoreverses: true),
                    value: animateBackground
                )
                
                // Main content
                VStack(spacing: 0) {
                    if isExpanded {
                        expandedView(geometry: geometry)
                    } else {
                        minimizedView
                    }
                }
                .background(
                    ZStack {
                        if isExpanded {
                            Color.white
                                .edgesIgnoringSafeArea(.all)
                                .opacity(1.0 - (Double(dragOffset.height) / 500.0))
                        } else {
                            BlurView(style: .systemUltraThinMaterial)
                                .edgesIgnoringSafeArea(.all)
                        }
                    }
                )
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if isExpanded {
                            // Only allow downward drag with smoother resistance
                            let translation = gesture.translation.height
                            if translation > 0 {
                                // Use cubic easing for more natural resistance
                                let dampedTranslation = pow(translation / 30, 0.7) * 30
                                withAnimation(.interactiveSpring()) {
                                    dragOffset = CGSize(width: 0, height: min(dampedTranslation, 500))
                                }
                            }
                        }
                    }
                    .onEnded { gesture in
                        let velocity = gesture.predictedEndLocation.y - gesture.location.y
                        let velocityThreshold = 300.0
                        let dismissThreshold = 100.0
                        
                        // Dismiss if dragged more than threshold or if velocity is high enough
                        if dragOffset.height > dismissThreshold || (dragOffset.height > 50 && velocity > velocityThreshold) {
                            withAnimation(.spring(
                                response: 0.6,  // Increased from 0.4 for gentler motion
                                dampingFraction: 0.92, // Increased from 0.85 for smoother settling
                                blendDuration: 0.4  // Increased from 0.3 for smoother blending
                            )) {
                                isExpanded = false
                                dragOffset = .zero
                            }
                        } else {
                            withAnimation(.spring(
                                response: 0.45,  // Increased from 0.35 for gentler bounce back
                                dampingFraction: 0.8,  // Increased from 0.7 for smoother settling
                                blendDuration: 0.3  // Increased from 0.2 for smoother blending
                            )) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
        }
        .frame(height: isExpanded ? nil : 64)
        .offset(y: isExpanded ? 0 : UIScreen.main.bounds.height - 64)
        .offset(y: dragOffset.height)
        .scaleEffect(
            isExpanded ? 1 : max(0.98, 1 - (dragOffset.height / 1000)),
            anchor: .top
        )
        .animation(.spring(
            response: 0.6,  // Increased from 0.4 for gentler motion
            dampingFraction: 0.88,  // Increased from 0.8 for smoother settling
            blendDuration: 0.4  // Increased from 0.3 for smoother blending
        ), value: isExpanded)
        .onAppear {
            prepareTranscriptForStreaming()
            setupPlayback()
            animateBackground = true
            
            // Start waveform animation
            withAnimation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
            ) {
                animateWaveform = true
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            AudioSessionManager.shared.deactivateAudioSession()
            endLiveActivity()
        }
    }
    
    // MARK: - Subviews
    
    private var minimizedView: some View {
        HStack(spacing: 16) {
            // Artwork/Icon with mood tag
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    if mood != nil {
                        AnimatedMeshGradient(mood: podcastMood)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "waveform")
                            .font(.serifBody)
                            .foregroundColor(LinearColors.accent)
                            .scaleEffect(animateWaveform ? 1.1 : 0.9)
                    }
                }
                
                // Chips container
                VStack(spacing: 2) {
                if let mood = mood {
                    Text(mood.capitalized)
                        .font(.serifCaption)
                        .foregroundColor(LinearColors.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    
                    if let generationType = generationType {
                        Text(generationType.displayName)
                            .font(.serifCaption)
                            .foregroundColor(LinearColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(LinearColors.accent.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.leading, 16)
            
            // Title and progress
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Insights")
                    .font(.serifLabel).fontWeight(.semibold)
                    .foregroundColor(LinearColors.primaryText)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(LinearColors.border)
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(LinearColors.accent)
                            .frame(width: geometry.size.width * progress, height: 2)
                    }
                }
                .frame(height: 2)
            }
            
            Spacer()
            
            // Play/Pause Button
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                    .foregroundColor(LinearColors.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 8)
            
            // Expand Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = true
                }
            }) {
                Image(systemName: "chevron.up")
                    .font(.serifBody)
                    .foregroundColor(LinearColors.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 8)
        }
        .frame(height: 64)
        .background(Color.white.opacity(0.98))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.black.opacity(0.1)),
            alignment: .top
        )
    }
    
    private func expandedView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Handle bar for drag gesture
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Artwork with mood tag
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: BorderRadius.card)
                                .fill(Color.white)
                                .frame(width: min(geometry.size.width * 0.6, 240), height: min(geometry.size.width * 0.6, 240))
                                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                            
                            if mood != nil {
                                AnimatedMeshGradient(mood: podcastMood)
                                    .frame(width: min(geometry.size.width * 0.6, 240), height: min(geometry.size.width * 0.6, 240))
                                    .clipShape(RoundedRectangle(cornerRadius: BorderRadius.card))
                            } else {
                                WaveformAnimationView(isPlaying: isPlaying)
                                    .frame(width: min(geometry.size.width * 0.3, 120))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        if let mood = mood {
                            Text(mood.capitalized)
                                .font(.serifLabel)
                                .foregroundColor(LinearColors.secondaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                        
                        if let generationType = generationType {
                            Text(generationType.displayName)
                                .font(.serifLabel)
                                .foregroundColor(LinearColors.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(LinearColors.accent.opacity(0.1))
                                )
                        }
                    }
                    .padding(.top, 20)
                    
                    // Title and subtitle
                    VStack(spacing: 8) {
                        Text("Weekly Insights")
                            .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                            .foregroundColor(LinearColors.primaryText)
                        
                        Text("AI-Generated Summary")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.secondaryText)
                    }
                    
                    // Time and progress slider
                    VStack(spacing: 8) {
                        // Custom slider
                        CustomSlider(
                            value: Binding(
                                get: { isDragging ? draggedProgress : progress },
                                set: { newValue in
                                    if let duration = audioPlayer?.duration {
                                        audioPlayer?.currentTime = duration * newValue
                                        currentTime = duration * newValue
                                    }
                                }
                            ),
                            isDragging: $isDragging,
                            draggedValue: $draggedProgress
                        )
                        .frame(height: 44)
                        
                        // Time labels
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.serifCaption)
                                .foregroundColor(LinearColors.secondaryText)
                            
                            Spacer()
                            
                            Text(formatTime(audioPlayer?.duration ?? 0))
                                .font(.serifCaption)
                                .foregroundColor(LinearColors.secondaryText)
                        }
                        .padding(.horizontal, 2)
                    }
                    .padding(.horizontal, 32)
                    
                    // Playback controls
                    HStack(spacing: 40) {
                        // Rewind button
                        Button(action: rewind15) {
                            Image(systemName: "gobackward.15")
                                .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                                .foregroundColor(LinearColors.primaryText)
                        }
                        
                        // Play/Pause button
                        Button(action: togglePlayback) {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                                    .foregroundColor(.white)
                                    .offset(x: isPlaying ? 0 : 2)
                            }
                            .padding(.horizontal, 140)
                            .padding(.vertical, 20)
                            .frame(width: 80, height: 80, alignment: .center)
                            .background(
                                LinearGradient(
                                    stops: [
                                        Gradient.Stop(color: Color(hex: "000000"), location: 0.00),
                                        Gradient.Stop(color: Color(hex: "171717"), location: 0.53),
                                        Gradient.Stop(color: Color(hex: "444444"), location: 1.00),
                                    ],
                                    startPoint: UnitPoint(x: 0.5, y: 0),
                                    endPoint: UnitPoint(x: 0.5, y: 1)
                                )
                            )
                            .cornerRadius(150)
                            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 150)
                                    .inset(by: -0.5)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 150)
                                    .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
                                    .blur(radius: 12)
                                    .offset(x: 0, y: 6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 150)
                                    .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                                    .blur(radius: 3)
                                    .offset(x: 0, y: 3)
                            )
                        }
                        
                        // Forward button
                        Button(action: forward15) {
                            Image(systemName: "goforward.15")
                                .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                                .foregroundColor(LinearColors.primaryText)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Transcript toggle
                    Button(action: { showTranscript.toggle() }) {
                        HStack {
                            Image(systemName: "text.quote")
                                .font(.system(size: 16))
                            Text("Show Transcript")
                                .font(.serifBody)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(LinearColors.accent)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: BorderRadius.card)
                                .stroke(LinearColors.accent, lineWidth: 1)
                        )
                    }
                    .padding(.top, 20)
                    
                    if showTranscript {
                        // Transcript text
                        Text(transcript)
                            .font(.system(size: 16))
                            .foregroundColor(LinearColors.secondaryText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: BorderRadius.card)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal)
                            .padding(.top, 20)
                    }
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    struct WaveformAnimationView: View {
        let isPlaying: Bool
        
        var body: some View {
            TimelineView(.animation) { _ in
                HStack(spacing: 4) {
                    ForEach(0..<15) { index in
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .fill(.white)
                            .frame(width: 3, height: isPlaying ? randomHeight(for: index) : 15)
                            .animation(
                                Animation
                                    .easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(index) * 0.1),
                                value: isPlaying
                            )
                    }
                }
            }
        }
        
        private func randomHeight(for index: Int) -> CGFloat {
            let base: Double = Date.timeIntervalSinceReferenceDate + Double(index)
            return 10 + abs(sin(base)) * 20
        }
    }
    
    struct CustomSlider: View {
        @Binding var value: Double
        @Binding var isDragging: Bool
        @Binding var draggedValue: Double
        
        var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(LinearColors.border)
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    // Progress track
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    LinearColors.accent,
                                    LinearColors.accent.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geometry.size.width, geometry.size.width * value)), height: 4)
                        .cornerRadius(2)
                    
                    // Drag handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .offset(x: max(0, min(geometry.size.width - 20, geometry.size.width * value - 10)))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    isDragging = true
                                    let newValue = max(0, min(1, (gesture.location.x) / geometry.size.width))
                                    
                                    // Haptic feedback at 10% progress milestones
                                    let progressPercent = Int(newValue * 10) // 10% chunks
                                    let oldProgressPercent = Int(value * 10)
                                    if progressPercent != oldProgressPercent {
                                        HapticManager.shared.playProgressMilestone()
                                    }
                                    
                                    draggedValue = newValue
                                    value = newValue
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var progress: Double {
        guard let duration = audioPlayer?.duration, duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    private func togglePlayback() {
        if isPlaying {
            HapticManager.shared.playMediumImpact() // Pause feedback
            audioPlayer?.pause()
        } else {
            HapticManager.shared.playAudioPlayback() // Play feedback
            audioPlayer?.play()
        }
        isPlaying.toggle()
    }
    
    private func rewind15() {
        HapticManager.shared.playLightImpact() // Quick navigation feedback
        guard let player = audioPlayer else { return }
        player.currentTime = max(0, player.currentTime - 15)
        currentTime = player.currentTime
    }
    
    private func forward15() {
        HapticManager.shared.playLightImpact() // Quick navigation feedback
        guard let player = audioPlayer else { return }
        player.currentTime = min(player.duration, player.currentTime + 15)
        currentTime = player.currentTime
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func setupPlayback() {
        AudioSessionManager.shared.configureAudioSession()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = audioPlayer {
                currentTime = player.currentTime
                updateCurrentLine()
            }
        }
    }
    
    private func prepareTranscriptForStreaming() {
        guard !transcript.isEmpty else { return }
        
        let words = transcript.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        
        wordLines = []
        var currentLine: [String] = []
        
        for word in words {
            currentLine.append(word)
            if currentLine.count >= wordsPerLine {
                wordLines.append(currentLine)
                currentLine = []
            }
        }
        
        if !currentLine.isEmpty {
            wordLines.append(currentLine)
        }
    }
    
    private func updateCurrentLine() {
        guard let player = audioPlayer, player.duration > 0 else { return }
        let progress = player.currentTime / player.duration
        currentLineIndex = Int(progress * Double(wordLines.count))
    }
    
    private func startLiveActivity() {
        // Implementation for live activity if needed
    }
    
    private func endLiveActivity() {
        // Implementation for ending live activity if needed
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
