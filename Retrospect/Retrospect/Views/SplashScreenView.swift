//
//  SplashScreenView.swift
//  Retrospect fina (SwiftUI)
//
//  Created by Shaurya Narang on 5/13/25.
//

import SwiftUI
import LocalAuthentication

// Splash Screen View
struct SplashScreenView: View {
    @Binding var isPresented: Bool
    @State private var iconOffset: CGFloat = 50
    @State private var iconOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.8
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var pillOpacity: Double = 0
    @State private var pillOffset: CGFloat = -20
    @State private var authenticationError: String?
    @State private var showRetryButton = false
    @AppStorage("faceIDEnabled") private var faceIDEnabled: Bool = true
    
    var body: some View {
        ZStack {
            // Clean adaptive background
            LinearColors.background
                .ignoresSafeArea()
            
            // Clean Authentication Status
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "faceid")
                        .font(.system(size: 14, weight: .medium))
                    Text(authenticationError ?? "Authenticating")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(authenticationError != nil ? LinearColors.accent : LinearColors.textTertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(LinearColors.cardBorder, lineWidth: 1)
                        )
                )
                .opacity(pillOpacity)
                .offset(y: pillOffset)
                .padding(.top, 120)
                
                if showRetryButton {
                    Button(action: authenticate) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(LinearColors.textDisplay)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearColors.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(LinearColors.cardBorder, lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
            }
            
            // Centered Main Content
            VStack(spacing: 20) {
                SquircleLogo.large(shadowEnabled: false)
                    .overlay(
                        // Subtle glow effect
                        RoundedRectangle(cornerRadius: 40.26) // 180 * 0.2237
                            .stroke(LinearColors.accent.opacity(0.2), lineWidth: 2)
                            .blur(radius: 4)
                    )
                    .offset(y: iconOffset)
                    .opacity(iconOpacity)
                    .scaleEffect(iconScale)
                
                VStack(spacing: 8) {
                    Text("Retrospect")
                        .font(.custom("HedvigLettersSerif-24ptRegular", size: 42))
                        .kerning(-0.2)
                        .foregroundColor(LinearColors.textDisplay)
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)
                    
                    Text("Your Journey of Self-Reflection")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(LinearColors.textSecondary)
                        .offset(y: subtitleOffset)
                        .opacity(subtitleOpacity)
                }
            }
            .offset(y: -10)
        }
        .onAppear {
            // Pill animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                pillOffset = 0
                pillOpacity = 1
            }
            
            // Icon animation with spring effect
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                iconOffset = 0
                iconScale = 1.0
                iconOpacity = 1
            }
            
            // Title animation with slight delay
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                titleOffset = 0
                titleOpacity = 1
            }
            
            // Subtitle animation with further delay
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5)) {
                subtitleOffset = 0
                subtitleOpacity = 1
            }
            
            // Start authentication
            authenticate()
        }
    }
    
    private func authenticate() {
        // If Face ID is disabled, automatically authenticate
        guard faceIDEnabled else {
            finishAuthentication(success: true)
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        // Check if the device supports Face ID
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Device doesn't support Face ID, authenticate anyway
            finishAuthentication(success: true)
            return
        }
        
        let reason = "Authenticate to access your weekly reflections"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    finishAuthentication(success: true)
                } else {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        authenticationError = "Authentication failed. Please try again."
                        showRetryButton = true
                    }
                }
            }
        }
    }
    
    private func finishAuthentication(success: Bool) {
        if success {
            // Animate out with consistent spring animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                iconOffset = -30
                titleOffset = -20
                subtitleOffset = -10
                iconScale = 0.9
                pillOffset = -20
                iconOpacity = 0
                titleOpacity = 0
                subtitleOpacity = 0
                pillOpacity = 0
            }
            
            // Dismiss splash screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isPresented = false
            }
        }
    }
}
