//
//  MinimalJournalInput.swift
//  Retrospect
//
//  Pill-shaped input field with embedded microphone button
//  for the minimal dark home screen
//

import SwiftUI

struct MinimalJournalInput: View {
    @Binding var text: String
    @Binding var attachedImages: [UIImage]
    @FocusState private var isFocused: Bool
    let onMicTap: () -> Void
    let onPlusTap: () -> Void
    var onTap: (() -> Void)? = nil // Optional tap callback for entering focus mode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Multi-line text area - tappable to enter focus mode
            ZStack(alignment: .topLeading) {
                // Placeholder
                if text.isEmpty {
                    Text("Start Journaling...")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.placeholderText)
                        .padding(.top, 20)
                        .padding(.leading, 24)
                        .allowsHitTesting(false)
                }
                
                // Text editor - disabled for interaction, tap goes to focus mode
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .font(.minimalInput)
                    .foregroundColor(.white)
                    .focused($isFocused)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .frame(maxHeight: .infinity)
                    .disabled(onTap != nil) // Disable text editing if tap callback is set
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let onTap = onTap {
                    HapticManager.shared.playLightImpact()
                    onTap()
                }
            }
            
            // Bottom row with plus button, image chip, and mic button
            HStack(spacing: 8) {
                // Plus button for attachments
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    onPlusTap()
                }) {
                    ZStack {
                        Circle()
                            .fill(LinearColors.Minimal.micButtonBackground)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.tabText)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Image count chip
                if !attachedImages.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 12, weight: .medium))
                        
                        Text("\(attachedImages.count)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        
                        Button(action: {
                            HapticManager.shared.playLightImpact()
                            attachedImages.removeAll()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                        }
                    }
                    .foregroundColor(LinearColors.Minimal.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(LinearColors.Minimal.accentSubtle)
                    )
                }
                
                Spacer()
                
                // Microphone button
                Button(action: {
                    HapticManager.shared.playMediumImpact()
                    onMicTap()
                }) {
                    ZStack {
                        Circle()
                            .fill(LinearColors.Minimal.micButtonBackground)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.tabText)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(height: 120)
        .background(
            ZStack {
                // 1. Base fill
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearColors.Minimal.inputBackground)
                
                // 2. Inner stroke (4pt) - thick stroke
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(
                        Color.white.opacity(0.10),
                        lineWidth: 4
                    )
                    .padding(1)
                
                // 3. Outer stroke (1pt) - gradient frame using strokeBorder for full visibility
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55), // Lighter at top
                                Color.white.opacity(0.35)  // Current gray at bottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
        )
    }
}

#Preview {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()
        
        MinimalJournalInput(
            text: .constant(""),
            attachedImages: .constant([]),
            onMicTap: { print("Mic tapped") },
            onPlusTap: { print("Plus tapped") }
        )
        .padding(.horizontal, 24)
    }
}

