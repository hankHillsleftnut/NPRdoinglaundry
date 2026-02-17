import SwiftUI

// === WELCOME CARD SCREEN ===
// Paginated welcome experience showing app features

struct WelcomeCardScreen: View {
    let onNext: () -> Void
    
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            // App's background
            LinearColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Spacer for top padding
                Spacer()
                    .frame(height: 60)
                
                // Paginated content
                TabView(selection: $currentPage) {
                    WelcomeFeaturePage(
                        iconName: "pencil.and.outline",
                        title: "Write Your Thoughts",
                        description: "Journal entries capture your reflections and experiences.",
                        subtitle: "Not required to generate your podcast",
                        currentPage: 0,
                        totalPages: 3,
                        onNext: {
                            withAnimation {
                                currentPage = 1
                            }
                        }
                    )
                    .tag(0)
                    
                    WelcomeFeaturePage(
                        iconName: "video.fill",
                        title: "Record Video Reflections",
                        description: "Visual journals add depth to your weekly insights.",
                        subtitle: "Not required to generate your podcast",
                        currentPage: 1,
                        totalPages: 3,
                        onNext: {
                            withAnimation {
                                currentPage = 2
                            }
                        }
                    )
                    .tag(1)
                    
                    WelcomeFeaturePage(
                        iconName: "mic.fill",
                        title: "Capture Audio Thoughts",
                        description: "Speak your mind and we'll transcribe it for you.",
                        subtitle: "Not required to generate your podcast",
                        currentPage: 2,
                        totalPages: 3,
                        onNext: {
                            onNext()
                        }
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
    }
}

// MARK: - Welcome Feature Page Component
struct WelcomeFeaturePage: View {
    let iconName: String
    let title: String
    let description: String
    let subtitle: String
    let currentPage: Int
    let totalPages: Int
    let onNext: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 72, weight: .regular))
                .foregroundColor(LinearColors.accent)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isAnimating)
            
            Spacer()
                .frame(height: 48)
            
            // Title
            Text(title)
                .font(.custom("EBGaramond12-Regular", size: 32))
                .foregroundColor(LinearColors.textDisplay)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, 40)
                .offset(y: isAnimating ? 0 : 20)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: isAnimating)
            
            Spacer()
                .frame(height: 16)
            
            // Description
            Text(description)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, 40)
                .offset(y: isAnimating ? 0 : 20)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: isAnimating)
            
            Spacer()
                .frame(height: 24)
            
            // Subtitle
            Text(subtitle)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, 40)
                .offset(y: isAnimating ? 0 : 20)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: isAnimating)
            
            Spacer()
            
            // Next button
            nextButton
                .padding(.horizontal, 28)
                .padding(.bottom, 60)
                .offset(y: isAnimating ? 0 : 20)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: isAnimating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
    
    private var nextButton: some View {
        Button(action: {
            playButtonTapHaptic()
            onNext()
        }) {
            Text(currentPage == totalPages - 1 ? "Get Started" : "Next")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .kerning(0)
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .shadow(color: LinearColors.cardShadow, radius: 2, x: 0, y: 2)
                .frame(maxWidth: .infinity)
                .frame(height: 66)
                .contentShape(Rectangle())
        }
        .frame(height: 66)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            LinearColors.metalGray,
                            LinearColors.charcoalCard
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(LinearColors.warmHighlight.opacity(0.4), lineWidth: 2)
                        .blur(radius: 0.5)
                        .offset(x: 0, y: 2)
                        .mask(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(gradient: Gradient(colors: [LinearColors.textPrimary, Color.clear]), startPoint: .top, endPoint: .bottom)))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearColors.cardBorder, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearColors.textPrimary.opacity(0.8), lineWidth: 2)
                .blur(radius: 1)
                .offset(x: 0, y: -1)
                .mask(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(gradient: Gradient(colors: [LinearColors.textPrimary, Color.clear]), startPoint: .top, endPoint: .bottom)))
        )
        .shadow(color: LinearColors.cardShadow, radius: 17, x: 0, y: 4)
        .shadow(color: LinearColors.cardShadow, radius: 3, x: 0, y: 2)
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if pressing {
                playButtonTouchDownHaptic()
            } else {
                playButtonTouchUpHaptic()
            }
        }, perform: {})
    }
    
    // MARK: - Haptic Functions
    private func playButtonTapHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred(intensity: 0.8)
    }
    
    private func playButtonTouchDownHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred(intensity: 0.6)
    }
    
    private func playButtonTouchUpHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred(intensity: 0.8)
    }
}

// MARK: - Preview
#Preview {
    WelcomeCardScreen(
        onNext: {
            print("Onboarding complete")
        }
    )
}

