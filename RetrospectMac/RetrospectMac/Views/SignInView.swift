import SwiftUI

/// Account sign-in. Primary path is Sign in with Apple (same account as iOS). A dev path
/// is provided so sync can be exercised before the SIWA capability is provisioned.
struct SignInView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var api: RetrospectAPI
    @Environment(\.dismiss) private var dismiss

    @State private var showDev = false
    @State private var devAppleId = ""
    @State private var devEmail = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.md) {
            Text("Sign in")
                .font(.journalHero)
                .foregroundColor(Ink.emphasis)
            Text("Sync this journal to your Retrospect account and feed the daily synthesis.")
                .font(.system(size: 13))
                .foregroundColor(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { auth.signInWithApple() }) {
                HStack {
                    Image(systemName: "applelogo")
                    Text("Sign in with Apple")
                    if auth.isWorking { ProgressView().scaleEffect(0.5) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Ink.emphasis))
                .foregroundColor(Ink.cream)
            }
            .buttonStyle(.plain)

            if let err = auth.lastError {
                Text(err).font(.system(size: 12)).foregroundColor(Ink.error)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DisclosureGroup(isExpanded: $showDev) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Apple user id", text: $devAppleId)
                        .textFieldStyle(.roundedBorder)
                    TextField("Email (optional)", text: $devEmail)
                        .textFieldStyle(.roundedBorder)
                    Button("Sign in (dev)") {
                        Task {
                            await auth.signInWithDevAppleId(devAppleId, email: devEmail.isEmpty ? nil : devEmail)
                            if api.isAuthenticated { dismiss() }
                        }
                    }
                    .disabled(devAppleId.isEmpty)
                }
                .padding(.top, 6)
            } label: {
                Text("Developer sign-in")
                    .font(.system(size: 12)).foregroundColor(Ink.tertiary)
            }
        }
        .padding(Metrics.lg)
        .frame(width: 320)
        .background(Ink.cream)
        .onChange(of: api.isAuthenticated) { _, signedIn in
            if signedIn { dismiss() }
        }
    }
}
