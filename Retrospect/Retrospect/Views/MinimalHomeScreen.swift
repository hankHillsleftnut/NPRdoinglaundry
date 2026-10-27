//
//  MinimalHomeScreen.swift
//  Retrospect
//
//  Dark, minimalist journaling interface with italic serif headline
//  and pill-shaped input. Accessible from Advanced Settings.
//

import SwiftUI

struct MinimalHomeScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var journalText = ""
    @State private var attachedImages: [UIImage] = []
    @State private var selectedTab: MinimalTab = .journal
    @State private var showingVoiceRecording = false
    @State private var showImagePicker = false
    @State private var isShowingGoals = false
    @State private var isShowingSettings = false
    
    // Animation states
    @State private var headlineOpacity: Double = 0
    @State private var headlineOffset: CGFloat = 20
    @State private var inputOpacity: Double = 0
    @State private var inputOffset: CGFloat = 30
    @State private var tabBarOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Pure black background
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Close button - top right
                HStack {
                    Spacer()
                    
                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.tabText)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(LinearColors.Minimal.inputBackground)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Main content based on selected tab
                Group {
                    switch selectedTab {
                    case .journal:
                        journalContent
                    case .podcasts:
                        placeholderContent(title: "Podcasts", icon: "square.stack.fill")
                    case .goals:
                        placeholderContent(title: "Goals", icon: "scope")
                    case .entries:
                        placeholderContent(title: "Entries", icon: "text.book.closed.fill")
                    case .settings:
                        placeholderContent(title: "Settings", icon: "gearshape.fill")
                    }
                }
                
                Spacer()
                
                // Bottom tab bar
                MinimalTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .opacity(tabBarOpacity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            animateIn()
        }
        .fullScreenCover(isPresented: $showingVoiceRecording) {
            VoiceRecordingView()
        }
    }
    
    // MARK: - Journal Tab Content
    
    private var journalContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: 80)
            
            // Italic headline - the hero element
            Text("How do you\nwant to rewire\nthe mind\ntoday?")
                .font(.minimalHeadline)
                .foregroundColor(LinearColors.Minimal.headlineText.opacity(0.7))
                .lineSpacing(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .opacity(headlineOpacity)
                .offset(y: headlineOffset)
            
            Spacer()
            
            // Input field
            MinimalJournalInput(
                text: $journalText,
                attachedImages: $attachedImages,
                onMicTap: {
                    showingVoiceRecording = true
                },
                onPlusTap: {
                    showImagePicker = true
                }
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .opacity(inputOpacity)
            .offset(y: inputOffset)
        }
        .sheet(isPresented: $showImagePicker) {
            ImageAttachmentPicker(
                selectedImages: $attachedImages,
                isPresented: $showImagePicker
            )
        }
    }
    
    // MARK: - Placeholder Content for Other Tabs
    
    private func placeholderContent(title: String, icon: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(LinearColors.Minimal.tabText)
            
            Text(title)
                .font(.minimalHeadline)
                .foregroundColor(LinearColors.Minimal.headlineText)
            
            Text("Coming soon")
                .font(.minimalInput)
                .foregroundColor(LinearColors.Minimal.placeholderText)
            
            Spacer()
        }
    }
    
    // MARK: - Animations
    
    private func animateIn() {
        // Staggered entrance animation
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
            headlineOpacity = 1
            headlineOffset = 0
        }
        
        withAnimation(.easeOut(duration: 0.6).delay(0.25)) {
            inputOpacity = 1
            inputOffset = 0
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            tabBarOpacity = 1
        }
    }
}

#Preview {
    MinimalHomeScreen()
}

