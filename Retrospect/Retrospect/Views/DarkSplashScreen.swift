//
//  DarkSplashScreen.swift
//  Retrospect
//
//  Dark themed splash screen with Face ID authentication
//

import SwiftUI
import LocalAuthentication
import UIKit

struct DarkSplashScreen: View {
    @Binding var isAuthenticated: Bool
    @AppStorage("faceIDEnabled") private var faceIDEnabled: Bool = true
    
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var statusOpacity: Double = 0
    @State private var authenticationError: String?
    @State private var showRetryButton = false
    @State private var isAuthenticating = false
    
    var body: some View {
        ZStack {
            // Dark background
            LinearColors.Minimal.background
                .ignoresSafeArea()
            
            // Face ID status (centered at top)
            VStack {
                VStack(spacing: 12) {
                    // Face ID status pill
                    HStack(spacing: 8) {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.Minimal.textSecondary))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: authenticationError != nil ? "exclamationmark.triangle.fill" : "faceid")
                                .font(.system(size: 16, weight: .medium))
                        }
                        
                        Text(authenticationError ?? (isAuthenticating ? "Authenticating..." : "Face ID"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(authenticationError != nil ? LinearColors.Minimal.warning : LinearColors.Minimal.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(LinearColors.Minimal.backgroundCard)
                            .overlay(
                                Capsule()
                                    .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                            )
                    )
                    .opacity(statusOpacity)
                    
                    // Retry button
                    if showRetryButton {
                        Button(action: {
                            HapticManager.shared.playMediumImpact()
                            authenticate()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Try Again")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(LinearColors.Minimal.backgroundCard)
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.top, 120)
                
                Spacer()
            }
            
            // Bottom-left branding
            VStack {
                Spacer()
                
                HStack {
                    VStack(alignment: .leading, spacing: 16) {
                        // Icon above text
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(LinearColors.Minimal.accent)
                            .opacity(logoOpacity)
                        
                        // "Retrospect" in larger EB Garamond Italic
                        Text("Retrospect")
                            .font(.custom("EBGaramond12-Italic", size: 56))
                            .foregroundColor(LinearColors.Minimal.textPrimary.opacity(0.7))
                            .opacity(titleOpacity)
                    }
                    .scaleEffect(logoScale, anchor: .bottomLeading)
                    
                    Spacer()
                }
                .padding(.leading, 28)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            animateIn()
        }
    }
    
    private func animateIn() {
        // Logo animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            logoScale = 1.0
            logoOpacity = 1
        }
        
        // Title animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            titleOpacity = 1
        }
        
        // Status animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5)) {
            statusOpacity = 1
        }
        
        // Start authentication after animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            authenticate()
        }
    }
    
    private func authenticate() {
        // Reset state
        authenticationError = nil
        showRetryButton = false
        isAuthenticating = true
        
        // If Face ID is disabled, skip authentication
        guard faceIDEnabled else {
            HapticManager.shared.playSuccessNotification()
            finishAuthentication(success: true)
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        // Check if device supports biometrics
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Device doesn't support Face ID, authenticate anyway
            HapticManager.shared.playSuccessNotification()
            finishAuthentication(success: true)
            return
        }
        
        let reason = "Authenticate to access your reflections"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                isAuthenticating = false
                
                if success {
                    HapticManager.shared.playSuccessNotification()
                    finishAuthentication(success: true)
                } else {
                    HapticManager.shared.playErrorNotification()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        authenticationError = "Authentication failed"
                        showRetryButton = true
                    }
                }
            }
        }
    }
    
    private func finishAuthentication(success: Bool) {
        guard success else { return }
        
        // Reset headline animation tracker for new session
        HeadlineAnimationTracker.shared.hasPlayedThisSession = false
        
        // Animate out
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            logoScale = 0.9
            logoOpacity = 0
            titleOpacity = 0
            statusOpacity = 0
        }
        
        // Complete authentication with haptic feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Strong success haptic as user enters the app
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
            isAuthenticated = true
        }
    }
}

#Preview {
    DarkSplashScreen(isAuthenticated: .constant(false))
}

