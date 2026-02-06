//
//  DarkFocusModeCard.swift
//  Retrospect
//
//  Full-screen journaling input for dark minimal UI
//  Expands from the pill input when tapped
//

import SwiftUI

struct DarkFocusModeCard: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    let keyboardHeight: CGFloat
    let isSendEnabled: Bool
    let onSend: () -> Void
    let onMicTap: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    @GestureState private var dragOffset: CGFloat = 0
    
    // Animation states for smooth expansion
    @State private var cardScale: CGFloat = 0.92
    @State private var cardOpacity: Double = 0
    @State private var cardOffsetY: CGFloat = 60
    
    // Get safe area from UIKit for accurate values
    private var topSafeArea: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return window?.safeAreaInsets.top ?? 59 // Default to iPhone 15 Pro Max value
    }
    
    private var bottomSafeArea: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return window?.safeAreaInsets.bottom ?? 34
    }
    
    var body: some View {
        let screenHeight = UIScreen.main.bounds.height
        
        // Calculate positions
        // X button position: below safe area
        let xButtonTopOffset: CGFloat = topSafeArea + 12
        
        // Card starts lower - giving room for black dismiss area and X button
        let cardTopOffset: CGFloat = topSafeArea + 70
        
        // Bottom: Above keyboard with 12pt padding, or 40pt from bottom when no keyboard
        let bottomOffset: CGFloat = keyboardHeight > 0 ? (keyboardHeight + 12) : (bottomSafeArea + 40)
        
        // Card height fills between card top and bottom
        let cardHeight: CGFloat = screenHeight - cardTopOffset - bottomOffset
        
        ZStack(alignment: .top) {
            // Dismiss area at top (tappable black area)
            VStack {
                Color.clear
                    .frame(height: cardTopOffset)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.shared.playLightImpact()
                        dismissCard()
                    }
                Spacer()
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        if value.translation.height > 0 {
                            state = value.translation.height * 0.5
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            HapticManager.shared.playMediumImpact()
                            dismissCard()
                        }
                    }
            )
            
            // X button outside the card
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        dismissCard()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(LinearColors.Minimal.inputBackground)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.top, xButtonTopOffset)
                .opacity(cardOpacity)
                
                Spacer()
            }
            
            // Card content (starts lower)
            VStack(spacing: 0) {
                // Card
                VStack(spacing: 0) {
                    // Text Editor
                    ZStack(alignment: .topLeading) {
                        // Placeholder
                        if text.isEmpty {
                            Text("Capture your thoughts, challenges, and experiences...")
                                .font(.system(size: 17, weight: .regular, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.placeholderText)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .allowsHitTesting(false)
                        }
                        
                        // Text editor
                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .lineSpacing(6)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .focused($isTextFieldFocused)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Bottom bar with mic and send buttons
                    HStack(spacing: 12) {
                        // Mic button
                        Button(action: {
                            HapticManager.shared.playMediumImpact()
                            onMicTap()
                        }) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(LinearColors.Minimal.inputBackground)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        // Character count
                        if !text.isEmpty {
                            Text("\(text.count)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                        }
                        
                        // Send button
                        Button(action: {
                            HapticManager.shared.playMediumImpact()
                            onSend()
                        }) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(isSendEnabled ? .white : LinearColors.Minimal.textTertiary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(isSendEnabled ? LinearColors.Minimal.accent : LinearColors.Minimal.inputBackground)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    isSendEnabled ? LinearColors.Minimal.accent : LinearColors.Minimal.border,
                                                    lineWidth: 1
                                                )
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!isSendEnabled)
                        .scaleEffect(isSendEnabled ? 1.0 : 0.95)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSendEnabled)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(height: max(cardHeight, 200))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(LinearColors.Minimal.backgroundCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 10)
                )
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .padding(.top, cardTopOffset)
            .offset(y: dragOffset + cardOffsetY)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        if value.translation.height > 0 {
                            state = value.translation.height * 0.5
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            HapticManager.shared.playMediumImpact()
                            dismissCard()
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: keyboardHeight)
        .onAppear {
            // Smooth expansion animation
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
                cardScale = 1.0
                cardOpacity = 1.0
                cardOffsetY = 0
            }
            
            // Auto-focus when appearing (after animation starts)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func dismissCard() {
        // Animate out with reverse of entry animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            cardScale = 0.92
            cardOpacity = 0
            cardOffsetY = 60
            isTextFieldFocused = false
        }
        
        // Dismiss after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
    }
}

#Preview("With Keyboard") {
    ZStack {
        Color.black.opacity(0.7)
            .ignoresSafeArea()
        
        DarkFocusModeCard(
            text: .constant(""),
            isPresented: .constant(true),
            keyboardHeight: 336,
            isSendEnabled: false,
            onSend: {},
            onMicTap: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Without Keyboard") {
    ZStack {
        Color.black.opacity(0.7)
            .ignoresSafeArea()
        
        DarkFocusModeCard(
            text: .constant("Some text here"),
            isPresented: .constant(true),
            keyboardHeight: 0,
            isSendEnabled: true,
            onSend: {},
            onMicTap: {}
        )
    }
    .preferredColorScheme(.dark)
}

