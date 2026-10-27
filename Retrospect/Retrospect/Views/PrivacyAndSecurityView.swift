import AVFoundation
import LocalAuthentication
import Speech
import SwiftUI

struct PrivacyAndSecurityView: View {
    @AppStorage("faceIDEnabled") private var faceIDEnabled: Bool = true
    @State private var showBiometricUnavailableAlert = false
    @State private var showPermissionsAlert = false
    @State private var permissionsAlertMessage = ""
    @Environment(\.dismiss) private var dismiss

    // Permission states
    @State private var cameraPermissionGranted = false
    @State private var microphonePermissionGranted = false
    @State private var speechPermissionGranted = false

    var body: some View {
        ZStack {
            // Background
            RadialGradient(
                gradient: Gradient(colors: [
                    LinearColors.backgroundLight,
                    LinearColors.background,
                ]),
                center: .topLeading,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.width * 1.5
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 20) {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                .foregroundColor(LinearColors.textPrimary)
                        }

                        Spacer()

                        Text("Privacy & Security")
                            .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                            .foregroundColor(LinearColors.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
                .background(LinearColors.background)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)

                ScrollView {
                    VStack(spacing: 24) {
                        // Device Security Section
                        SettingsGroup(title: "Device Security") {
                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    title: "Face ID",
                                    subtitle: "Secure app access with biometric authentication",
                                    icon: "faceid",
                                    isOn: $faceIDEnabled
                                )
                                .onChange(of: faceIDEnabled) { _, newValue in
                                    if newValue {
                                        checkBiometricAvailability()
                                    }
                                }

                                if faceIDEnabled {
                                    Divider()
                                        .background(LinearColors.cardBorder)
                                        .padding(.horizontal, Spacing.cardPadding)

                                    HStack {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 14))
                                            .foregroundColor(LinearColors.textTertiary)

                                        Text("Face ID will be required to access the app")
                                            .font(.serifCaption)
                                            .foregroundColor(LinearColors.textSecondary)

                                        Spacer()
                                    }
                                    .padding(.horizontal, Spacing.cardPadding)
                                    .padding(.vertical, 8)
                                }
                            }
                        }

                        // App Permissions Section
                        SettingsGroup(title: "App Permissions") {
                            PermissionRow(
                                icon: "camera.fill",
                                title: "Camera",
                                description: "Required for video reflections",
                                isGranted: cameraPermissionGranted
                            ) {
                                requestCameraPermission()
                            }

                            Divider()
                                .background(LinearColors.cardBorder)
                                .padding(.horizontal, Spacing.cardPadding)

                            PermissionRow(
                                icon: "mic.fill",
                                title: "Microphone",
                                description: "Required for audio recording",
                                isGranted: microphonePermissionGranted
                            ) {
                                requestMicrophonePermission()
                            }

                            Divider()
                                .background(LinearColors.cardBorder)
                                .padding(.horizontal, Spacing.cardPadding)

                            PermissionRow(
                                icon: "waveform",
                                title: "Speech Recognition",
                                description: "Required for voice transcription",
                                isGranted: speechPermissionGranted
                            ) {
                                requestSpeechPermission()
                            }
                        }

                        // Privacy Information Section
                        SettingsSection(
                            title: "Privacy Information",
                            subtitle: "How your data is handled",
                            icon: "shield.fill"
                        ) {
                            VStack(spacing: 16) {
                                InfoCard(
                                    icon: "icloud.fill",
                                    title: "Local Storage",
                                    description: "Your reflections and personal data are stored locally on your device and never uploaded to external servers without your explicit permission."
                                )

                                InfoCard(
                                    icon: "key.fill",
                                    title: "Data Encryption",
                                    description: "All sensitive data is encrypted using industry-standard encryption methods to protect your privacy."
                                )

                                InfoCard(
                                    icon: "person.badge.shield.checkmark.fill",
                                    title: "No Data Sharing",
                                    description: "We never share your personal reflections or data with third parties. Your privacy is our priority."
                                )
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            checkPermissions()
        }
        .alert("Biometric Authentication Unavailable", isPresented: $showBiometricUnavailableAlert) {
            Button("OK", role: .cancel) {
                faceIDEnabled = false
            }
        } message: {
            Text("Face ID is not available on this device or is not configured. Please set up Face ID in Settings.")
        }
        .alert("Permission Required", isPresented: $showPermissionsAlert) {
            Button("Open Settings", role: .none) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(permissionsAlertMessage)
        }
    }

    // MARK: - Permission Methods

    private func checkPermissions() {
        // Check camera permission
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermissionGranted = cameraStatus == .authorized

        // Check microphone permission
        let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        microphonePermissionGranted = microphoneStatus == .granted

        // Check speech recognition permission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        speechPermissionGranted = speechStatus == .authorized
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    cameraPermissionGranted = true
                } else {
                    showPermissionsAlert = true
                    permissionsAlertMessage = "Please enable camera access in Settings to use video journaling."
                }
            }
        }
    }

    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    microphonePermissionGranted = true
                } else {
                    showPermissionsAlert = true
                    permissionsAlertMessage = "Please enable microphone access in Settings to use video journaling."
                }
            }
        }
    }

    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    speechPermissionGranted = true
                } else {
                    showPermissionsAlert = true
                    permissionsAlertMessage = "Please enable speech recognition in Settings to use live transcription."
                }
            }
        }
    }

    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?

        if !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            showBiometricUnavailableAlert = true
            faceIDEnabled = false
        } else {
            // Verify the biometric type
            switch context.biometryType {
            case .faceID:
                // Face ID is available, keep the setting enabled
                break
            case .touchID, .none:
                // Not Face ID, show alert and disable
                showBiometricUnavailableAlert = true
                faceIDEnabled = false
            @unknown default:
                // Handle future biometric types
                break
            }
        }
    }
}

/// Permission Toggle Component
struct PermissionToggle: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                    .foregroundColor(LinearColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textPrimary)

                    Text(description)
                        .font(.serifLabel)
                        .foregroundColor(LinearColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isGranted ? LinearColors.successGreen : LinearColors.warningRed)
                    .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.card)
                    .fill(LinearColors.inputBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Info Card Component
struct InfoCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                .foregroundColor(LinearColors.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.serifBody)
                    .foregroundColor(LinearColors.textPrimary)

                Text(description)
                    .font(.serifLabel)
                    .foregroundColor(LinearColors.textSecondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.inputBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Permission Row Component

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(LinearColors.accent)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.geistBody).kerning(TypographyKerning.bodyKerning)
                        .foregroundColor(LinearColors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(description)
                        .font(.serifCaption)
                        .foregroundColor(LinearColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isGranted ? .green : .orange)
            }
            .padding(.horizontal, Spacing.cardPadding)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PrivacyAndSecurityView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyAndSecurityView()
    }
}
