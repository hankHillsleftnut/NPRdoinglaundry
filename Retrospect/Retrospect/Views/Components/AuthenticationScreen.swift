import SwiftUI
import AuthenticationServices

// === AUTHENTICATION SCREEN ===
// Apple Sign-In + skip option for onboarding

struct AuthenticationScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onExit: (() -> Void)?
    
    @State private var email = ""
    @State private var password = ""
    @State private var phoneNumber = ""
    @State private var bodyTextAnimating = false
    @State private var dragOffset: CGFloat = 0
    @State private var selectedMethod: AuthMethod? = nil
    @State private var isSigningIn = false
    @State private var signInError: String?
    @FocusState private var focusedField: Field?
    @ObservedObject private var apiClient = RetrospectAPIClient.shared
    
    enum AuthMethod {
        case email, phone, google, apple
    }
    
    enum Field {
        case email, password, phone
    }
    
    init(currentStep: Int, totalSteps: Int, onNext: @escaping () -> Void, onExit: (() -> Void)? = nil) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onNext = onNext
        self.onExit = onExit
    }
    
    var body: some View {
        ZStack {
            // App's background
            LinearColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section with draggable bar and dots
                topSection
                
                // Main content area
                ScrollView {
                    mainContent
                        .padding(.bottom, 40)
                }
                
                // Bottom button area
                bottomSection
            }
            .offset(y: dragOffset)
            .opacity(1.0 - (dragOffset / 500))
        }
        .onAppear {
            bodyTextAnimating = true
        }
    }
    
    // MARK: - Top Section
    private var topSection: some View {
        VStack(spacing: 24) {
            // Draggable bar (if onExit provided)
            if onExit != nil {
                draggableBar
            }
            
            // Progress bar
            progressIndicator
        }
        .padding(.horizontal, 40)
        .padding(.top, 12)
    }
    
    // MARK: - Draggable Dismiss Bar
    private var draggableBar: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(LinearColors.textTertiary.opacity(0.3))
            .frame(width: 36, height: 5)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            onExit?()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
    }
    
    // MARK: - Progress Indicator (Bar with front-loaded progress)
    private var progressIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.textTertiary.opacity(0.2))
                    .frame(height: 3)
                
                // Progress fill with front-loaded calculation
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearColors.accent)
                    .frame(width: geometry.size.width * calculateFrontLoadedProgress(), height: 3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 40)
    }
    
    // Calculate front-loaded progress (fast at start, slow at end)
    private func calculateFrontLoadedProgress() -> CGFloat {
        let progress = CGFloat(currentStep) / CGFloat(totalSteps)
        
        // Front-loaded curve: fast progress early, slow at end
        // Using exponential easing for front-loading
        let frontLoaded = 1 - pow(1 - progress, 2.5)
        
        return min(frontLoaded, 1.0)
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Auth icon and heading
            authHeader
            
            // Main title
            mainTitle
            
            // Body text
            bodyText
            
            if selectedMethod == nil {
                // Step 1: Show method selection buttons
                methodSelectionButtons
                    .padding(.top, 32)
            } else if selectedMethod == .email {
                // Step 2: Show email input
                emailInputSection
                    .padding(.top, 16)
            } else if selectedMethod == .phone {
                // Step 2: Show phone input
                phoneInputSection
                    .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 40)
    }
    
    private var authHeader: some View {
        HStack(spacing: 6) {
            // Lock icon
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(LinearColors.textTertiary)
            
            // Sign Up label
            Text("Sign Up")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(LinearColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var mainTitle: some View {
        Text("Create Your Account")
            .font(.custom("EBGaramond12-Regular", size: 32))
            .foregroundColor(LinearColors.textDisplay)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var bodyText: some View {
        Group {
            if selectedMethod == nil {
                Text("Choose your preferred sign-up method to get started.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            } else if selectedMethod == .email {
                Text("Enter your email and create a password.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            } else if selectedMethod == .phone {
                Text("Enter your phone number to get started.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
        }
        .offset(y: bodyTextAnimating ? 0 : 20)
        .blur(radius: bodyTextAnimating ? 0 : 8)
        .opacity(bodyTextAnimating ? 1.0 : 0.3)
        .animation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.2), value: bodyTextAnimating)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Method Selection Buttons
    private var methodSelectionButtons: some View {
        VStack(spacing: 16) {
            // Apple Sign In (primary)
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                handleAppleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 56)
            .cornerRadius(16)
            
            if isSigningIn {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: LinearColors.accent))
                        .scaleEffect(0.8)
                    Text("Connecting...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.textSecondary)
                }
                .padding(.top, 4)
            }
            
            if let error = signInError {
                Text(error)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            
            // Email button (secondary)
            Button(action: {
                playButtonTapHaptic()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedMethod = .email
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(LinearColors.accent)
                    
                    Text("Sign Up with Email")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(LinearColors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(LinearColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearColors.inputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearColors.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Apple Sign In Handler
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInError = "Invalid credential type"
                return
            }
            
            let appleUserId = credential.user
            let email = credential.email
            let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
            
            isSigningIn = true
            signInError = nil
            
            Task {
                do {
                    let _ = try await apiClient.signIn(
                        appleUserId: appleUserId,
                        email: email,
                        identityToken: identityToken
                    )
                    
                    await MainActor.run {
                        isSigningIn = false
                        playButtonTapHaptic()
                        onNext()
                    }
                } catch {
                    await MainActor.run {
                        isSigningIn = false
                        signInError = error.localizedDescription
                    }
                }
            }
            
        case .failure(let error):
            // ASAuthorizationError.canceled is normal (user dismissed the sheet)
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            signInError = error.localizedDescription
        }
    }
    
    // MARK: - Email Input Section
    private var emailInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Back button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedMethod = nil
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                }
                .foregroundColor(LinearColors.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 12) {
                // Email field
                TextField("Enter your email", text: $email)
                    .focused($focusedField, equals: .email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearColors.inputBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .email ? LinearColors.accent : LinearColors.cardBorder, lineWidth: 1)
                    )
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.textPrimary)
                
                // Password field
                SecureField("Create a password", text: $password)
                    .focused($focusedField, equals: .password)
                    .textContentType(.newPassword)
                    .padding()
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearColors.inputBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .password ? LinearColors.accent : LinearColors.cardBorder, lineWidth: 1)
                    )
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.textPrimary)
                
                // Sign up button
                Button(action: {
                    // Placeholder: proceed to next step
                    playButtonTapHaptic()
                    onNext()
                }) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearColors.accent)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Phone Input Section
    private var phoneInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Back button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedMethod = nil
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                }
                .foregroundColor(LinearColors.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 12) {
                // Phone field
                TextField("Enter your phone number", text: $phoneNumber)
                    .focused($focusedField, equals: .phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .padding()
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearColors.inputBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .phone ? LinearColors.accent : LinearColors.cardBorder, lineWidth: 1)
                    )
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.textPrimary)
                
                // Sign up button
                Button(action: {
                    // Placeholder: proceed to next step
                    playButtonTapHaptic()
                    onNext()
                }) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearColors.accent)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
            }
        }
    }
    
    
    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: 16) {
            // Skip button for testing
            skipButton
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }
    
    private var skipButton: some View {
        Button(action: {
            onNext()
        }) {
            Text("Skip for now")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(LinearColors.textSecondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Haptic Functions
    private func playButtonTapHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred(intensity: 0.8)
    }
}

// MARK: - Preview
#Preview {
    AuthenticationScreen(
        currentStep: 11,
        totalSteps: 12,
        onNext: {
            print("Next tapped")
        },
        onExit: {
            print("Exit tapped")
        }
    )
}


