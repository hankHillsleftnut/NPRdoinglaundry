import GoogleSignIn
import SwiftUI

struct GoogleDocsIntegrationView: View {
    @Binding var isPresented: Bool
    @StateObject private var googleDocsService = GoogleDocsService()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Google Docs Integration")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top, 40)

                Text("Connect your Google account to automatically include your recent Google Docs in your weekly reflections.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .foregroundColor(.secondary)

                if !googleDocsService.isConnected {
                    Button(action: {
                        Task {
                            do {
                                try await googleDocsService.authenticate()
                            } catch {
                                showError = true
                                errorMessage = "Failed to connect to Google account"
                            }
                        }
                    }) {
                        Text("Connect Google Account")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearColors.Minimal.accent)
                            .foregroundColor(LinearColors.Minimal.textPrimary)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 30)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 50))

                        Text("Connected to Google")
                            .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)

                        Toggle("Include Google Docs Data", isOn: Binding(
                            get: { googleDocsService.isGoogleDocsEnabled },
                            set: { googleDocsService.toggleGoogleDocsIntegration($0) }
                        ))
                        .padding(.horizontal, 30)
                    }
                }

                Spacer()

                Button(action: {
                    isPresented = false
                }) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearColors.Minimal.accent)
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            .navigationTitle("Google Docs Setup")
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
}

#Preview {
    GoogleDocsIntegrationView(isPresented: .constant(true))
}
