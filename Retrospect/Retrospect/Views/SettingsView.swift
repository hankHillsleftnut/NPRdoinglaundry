import SwiftUI
import AVFoundation
import Speech

// === SETTINGS VIEW - Apple-Inspired Category Navigation ===
// Redesigned with reduced information density and clear hierarchy

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SettingsView: View {
    @State private var showProfilePersonalization = false
    @State private var showAppearance = false
    @State private var showAudioPlayback = false
    @State private var showPrivacySecurity = false
    @State private var showIntegrationsData = false
    @State private var showAdvanced = false
    @State private var showOnboarding = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isScrolled: Bool = false
    
    // MARK: - Elegant Header Computed Properties
    
    // Smooth scroll progress for refined animations
    private var scrollProgress: CGFloat {
        let threshold: CGFloat = 80
        if scrollOffset >= 0 { return 0 }
        return min(abs(scrollOffset) / threshold, 1.0)
    }
    
    // Sophisticated title size scaling
    private var headerTitleSize: CGFloat {
        let minSize: CGFloat = 22
        let maxSize: CGFloat = 32
        return maxSize - (scrollProgress * (maxSize - minSize))
    }
    
    // Refined title kerning
    private var headerTitleKerning: CGFloat {
        let minKerning: CGFloat = -0.3
        let maxKerning: CGFloat = -0.8
        return maxKerning - (scrollProgress * (maxKerning - minKerning))
    }
    
    // Elegant positioning
    private var titleVerticalOffset: CGFloat {
        let maxOffset: CGFloat = -4
        return scrollProgress * maxOffset
    }
    
    // Sophisticated spacing
    private var horizontalPadding: CGFloat {
        let minPadding: CGFloat = 24
        let maxPadding: CGFloat = 32
        return maxPadding - (scrollProgress * (maxPadding - minPadding))
    }
    
    private var topPadding: CGFloat {
        let minPadding: CGFloat = 16
        let maxPadding: CGFloat = 24
        return maxPadding - (scrollProgress * (maxPadding - minPadding))
    }
    
    private var bottomPadding: CGFloat {
        let minPadding: CGFloat = 12
        let maxPadding: CGFloat = 20
        return maxPadding - (scrollProgress * (maxPadding - minPadding))
    }
    
    // Refined visual effects
    private var headerHeight: CGFloat {
        let minHeight: CGFloat = 60
        let maxHeight: CGFloat = 80
        return maxHeight - (scrollProgress * (maxHeight - minHeight))
    }
    
    private var separatorOpacity: CGFloat {
        return scrollProgress * 0.4
    }
    
    // MARK: - Elegant Header View
    
    private var elegantHeader: some View {
        ZStack(alignment: .bottom) {
            // Sophisticated background treatment
            headerBackground
            
            // Refined title with elegant positioning - transitions from left to center
            HStack {
                if scrollProgress < 0.5 {
                    // Left-aligned at top
                    Text("Settings")
                        .font(.custom("EBGaramond12-Regular", size: headerTitleSize))
                        .kerning(headerTitleKerning)
                        .foregroundColor(LinearColors.textDisplay)
                        .offset(y: titleVerticalOffset)
                    
                    Spacer()
                } else {
                    // Centered when scrolled
                    Spacer()
                    
                    Text("Settings")
                        .font(.custom("EBGaramond12-Regular", size: headerTitleSize))
                        .kerning(headerTitleKerning)
                        .foregroundColor(LinearColors.textDisplay)
                        .offset(y: titleVerticalOffset)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
        .frame(height: headerHeight)
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2), value: scrollProgress)
    }
    
    // Sophisticated background system
    private var headerBackground: some View {
        ZStack {
            // Base background matching main gradient
            LinearColors.background
            
            // Elegant overlay with terra-cotta accent
            LinearGradient(
                gradient: Gradient(colors: [
                    LinearColors.background.opacity(0.95),
                    LinearColors.terraCottaSubtle.opacity(0.1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(scrollProgress)
        }
        .background(.ultraThinMaterial.opacity(scrollProgress * 0.8), in: Rectangle())
        .ignoresSafeArea(.container, edges: .top)
        .overlay(
            // Subtle depth shadow when scrolled
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            LinearColors.cardShadow.opacity(0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(scrollProgress)
                .frame(height: 8)
                .offset(y: headerHeight),
            alignment: .bottom
        )
    }
    
    var body: some View {
        ZStack {
            // Background
            RadialGradient(
                gradient: Gradient(colors: [
                    LinearColors.backgroundLight,
                    LinearColors.background
                ]),
                center: .topLeading,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.width * 1.5
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Elegant Header
                elegantHeader
                
                // Elegant separator
                Rectangle()
                    .fill(LinearColors.cardBorder.opacity(separatorOpacity))
                    .frame(height: 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2), value: scrollProgress)
                
                ScrollView {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, 
                                       value: geometry.frame(in: .named("scroll")).minY)
                    }
                    .frame(height: 0)
                    
                    VStack(spacing: 16) {
                        // Category Navigation Cards
                        VStack(spacing: 16) {
                            // Profile & Personalization
                            SettingsCategoryCard(
                                title: "Profile & Personalization",
                                subtitle: "AI style and research preferences",
                                icon: "person.crop.circle.fill"
                            ) {
                                showProfilePersonalization = true
                            }
                            .padding(.horizontal, Spacing.containerMargin)
                            
                            // Appearance
                            SettingsCategoryCard(
                                title: "Appearance",
                                subtitle: "Themes and interface options",
                                icon: "paintbrush.fill"
                            ) {
                                showAppearance = true
                            }
                            .padding(.horizontal, Spacing.containerMargin)
                            
                            // Audio & Playback
                            SettingsCategoryCard(
                                title: "Audio & Playback",
                                subtitle: "Sound and playback settings",
                                icon: "speaker.wave.3.fill"
                            ) {
                                showAudioPlayback = true
                            }
                            .padding(.horizontal, Spacing.containerMargin)
                            
                            // Privacy & Security
                            SettingsCategoryCard(
                                title: "Privacy & Security",
                                subtitle: "Permissions and security features",
                                icon: "lock.shield.fill"
                            ) {
                                showPrivacySecurity = true
                            }
                            .padding(.horizontal, Spacing.containerMargin)
                            
                            // Integrations & Data
                            SettingsCategoryCard(
                                title: "Integrations & Data",
                                subtitle: "Connected services and data",
                                icon: "link.circle.fill"
                            ) {
                                showIntegrationsData = true
                            }
                            .padding(.horizontal, Spacing.containerMargin)
                            
                            // Advanced
                            SettingsCategoryCard(
                                title: "Advanced",
                                subtitle: "Developer and experimental features",
                                icon: "gearshape.2.fill"
                            ) {
                                showAdvanced = true
                            }
                            .padding(.horizontal, Spacing.containerMargin)
                        }
                        
                        // Onboarding Access Section
                        VStack(spacing: 12) {
                            Button(action: {
                                showOnboarding = true
                            }) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(LinearColors.accent.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(LinearColors.accent)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("View Onboarding")
                                            .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                            .foregroundColor(LinearColors.textPrimary)
                                            .multilineTextAlignment(.leading)
                                        
                                        Text("Replay the welcome experience")
                                            .font(.serifLabel)
                                            .foregroundColor(LinearColors.textSecondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(LinearColors.textTertiary)
                                }
                                .padding(Spacing.cardPadding)
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
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, Spacing.containerMargin)
                        }
                        .padding(.top, 24)
                        
                        // Logo Section
                    VStack(spacing: 8) {
                            SquircleLogo.small()
                        
                        Text("Retrospect")
                            .geistCaption()
                            .opacity(0.6)
                    }
                        .padding(.top, 32)
                    .padding(.bottom, 100)
                    }
                    .padding(.vertical, 24)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                    
                    // Update binary state for other UI elements if needed
                    let threshold: CGFloat = 20
                    isScrolled = value < -threshold
                }
            }
        }
        .sheet(isPresented: $showProfilePersonalization) {
            ProfilePersonalizationView()
        }
        .sheet(isPresented: $showAppearance) {
            AppearanceSettingsView()
        }
        .sheet(isPresented: $showAudioPlayback) {
            AudioSettingsView()
        }
        .sheet(isPresented: $showPrivacySecurity) {
            PrivacyAndSecurityView()
        }
        .sheet(isPresented: $showIntegrationsData) {
            IntegrationsDataView()
        }
        .sheet(isPresented: $showAdvanced) {
            AdvancedSettingsView()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlow()
        }
    }
}

// MARK: - Legacy Components (preserved for compatibility)

struct GoogleDocsSettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var googleDocsService: GoogleDocsService
    @State private var showAnimation = true
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient matching the app design
                RadialGradient(
                    gradient: Gradient(colors: [
                        LinearColors.backgroundLight,
                        LinearColors.background
                    ]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: UIScreen.main.bounds.width * 1.5
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    VStack(spacing: 16) {
                        HStack {
                            Button("Done") {
                                isPresented = false
                            }
                            .font(.serifBody)
                            .foregroundColor(LinearColors.accent)
                            
                            Spacer()
                            
                            Text("Google Docs")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(LinearColors.textPrimary)
                            
                            Spacer()
                            
                            // Spacer for balance
                            Text("Done")
                                .font(.serifBody)
                                .foregroundColor(.clear)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top)
                    .background(LinearColors.background)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                    
                    // Google Docs Integration Content - simplified view without onboarding page structure
                    VStack(spacing: 20) {
                        Text("Google Docs integration content would go here")
                            .font(.serifBody)
                            .foregroundColor(LinearColors.textSecondary)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .alert("Google Docs Connection Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            // Trigger initial animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    showAnimation = true
                }
            }
        }
    }
}

// MARK: - Settings Section Components (Legacy)
struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearColors.accent.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.serifBody).fontWeight(.semibold)
                            .foregroundColor(LinearColors.accent)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.geistTitle).kerning(TypographyKerning.titleKerning)
                            .foregroundColor(LinearColors.textPrimary)
                        
                        Text(subtitle)
                            .font(.serifLabel)
                            .foregroundColor(LinearColors.textSecondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                    .overlay(LinearColors.cardBorder.opacity(0.5))
            }
            
            // Section Content
            content()
        }
                                    .padding(.horizontal, Spacing.containerMargin)
        .padding(.vertical, 8)
    }
}

struct SettingsSubsection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                .foregroundColor(LinearColors.textPrimary)
            
            content()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
