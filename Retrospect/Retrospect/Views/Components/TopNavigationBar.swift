import SwiftUI

// MARK: - Top Navigation State Management
class TopNavigationState: ObservableObject {
    @Published var isShowingSettings = false
    @Published var isEditingName = false
    @Published var userName = ""
    
    // Animation states
    @Published var isAppearing = true
    @Published var headerOffset: CGFloat = 50
    
    func startEditingName(currentName: String) {
        userName = currentName
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isEditingName = true
        }
    }
}

// MARK: - Top Navigation Bar Component
struct TopNavigationBar: View {
    @StateObject private var navState = TopNavigationState()
    @AppStorage("userName") private var storedUserName: String = ""
    
    // Computed property for first name (cached to avoid repeated string operations)
    private var firstName: String {
        storedUserName.components(separatedBy: " ").first ?? storedUserName
    }
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Hello message and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(storedUserName.isEmpty ? "Retrospect" : "Hello, \(firstName)")
                    .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                    .foregroundColor(LinearColors.textPrimary)
                    .onTapGesture {
                        navState.startEditingName(currentName: storedUserName)
                    }
                
                Text("Your Weekly Life Insights")
                    .font(.serifSubheadline)
                    .foregroundColor(LinearColors.textSecondary)
            }
            
            Spacer()
            
            // Settings Button
            Button(action: {
                navState.isShowingSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.geistBody).kerning(TypographyKerning.bodyKerning)
                    .foregroundColor(LinearColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.button)
                            .fill(LinearColors.cardBackground)
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.button)
                            .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .offset(y: navState.isAppearing ? navState.headerOffset : 0)
        .opacity(navState.isAppearing ? 0 : 1)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                navState.isAppearing = false
            }
        }
        .sheet(isPresented: $navState.isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $navState.isEditingName) {
            EditNameView(
                userName: $navState.userName,
                storedUserName: $storedUserName,
                isPresented: $navState.isEditingName
            )
        }
    }
}

// MARK: - Edit Name View Component
struct EditNameView: View {
    @Binding var userName: String
    @Binding var storedUserName: String
    @Binding var isPresented: Bool
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.serifLabel).fontWeight(.semibold)
                        .foregroundColor(LinearColors.textPrimary)
                    
                    TextField("Enter your name", text: $userName)
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: BorderRadius.input)
                                .fill(LinearColors.inputBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: BorderRadius.input)
                                        .stroke(
                                            isNameFieldFocused ? LinearColors.focusRing : LinearColors.inputBorder,
                                            lineWidth: isNameFieldFocused ? 2 : 1
                                        )
                                )
                        )
                        .focused($isNameFieldFocused)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(LinearColors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        storedUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
                        isPresented = false
                    }
                    .foregroundColor(LinearColors.accent)
                    .fontWeight(.semibold)
                    .disabled(userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            isNameFieldFocused = true
        }
    }
}