import SwiftUI

struct SupportAndDataView: View {
    @AppStorage("devMode") private var devMode: Bool = false
    @State private var showResetAlert = false

    @ObservedObject private var goalsManager = GoalsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            LinearColors.backgroundGrey
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                VStack(spacing: 16) {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                .foregroundColor(LinearColors.textPrimary)
                        }
                        
                        Text("Support & Data")
                            .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                            .foregroundColor(LinearColors.textPrimary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Help & Support Section
                        SettingsSection(
                            title: "Help & Support",
                            subtitle: "Get help and tutorials",
                            icon: "questionmark.circle.fill"
                        ) {
                            VStack(spacing: 12) {

                                
                                Button(action: {
                                    VideoJournalManager.shared.debugPrintEntries()
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "ladybug.fill")
                                            .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                            .foregroundColor(LinearColors.accent)
                                        Text("Debug Video Journals")
                                            .font(.serifBody)
                                            .foregroundColor(LinearColors.textPrimary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(LinearColors.textSecondary)
                                            .font(.serifLabel)
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
                        
                        // Developer Settings Section
                        SettingsSection(
                            title: "Developer",
                            subtitle: "Debug features and testing tools",
                            icon: "hammer.fill"
                        ) {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "hammer.fill")
                                        .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                        .foregroundColor(LinearColors.accent)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Development Mode")
                                            .font(.serifBody)
                                            .foregroundColor(LinearColors.textPrimary)
                                        
                                        Text("Enable debug features and testing tools")
                                            .font(.serifLabel)
                                            .foregroundColor(LinearColors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $devMode)
                                        .toggleStyle(DevelopmentModeToggle())
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
                        
                        // Data Management Section
                        SettingsSection(
                            title: "Data Management",
                            subtitle: "Export, import, and manage your data",
                            icon: "externaldrive.fill"
                        ) {
                            DataManagementSection(
                                onResetAllData: {
                                    showResetAlert = true
                                },
                                goalsManager: goalsManager
                            )
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)

        .alert("Reset All Data", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                // Handle reset logic here
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            }
        } message: {
            Text("This will permanently delete all your data including reflections, goals, and settings. This action cannot be undone.")
        }
    }
}

// Development Mode Toggle Style
struct DevelopmentModeToggle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "hammer.fill")
                    .font(.serifCaption)
                    .fontWeight(.bold)
                Text("Dev")
                    .font(.serifCaption)
                    .fontWeight(.bold)
            }
            .foregroundColor(configuration.isOn ? .white : LinearColors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(configuration.isOn ? LinearColors.accent : LinearColors.inputBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}



struct SupportAndDataView_Previews: PreviewProvider {
    static var previews: some View {
        SupportAndDataView()
    }
} 