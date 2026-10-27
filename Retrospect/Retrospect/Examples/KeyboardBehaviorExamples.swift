import SwiftUI

/// Example usage of the robust KeyboardManager system
/// This file demonstrates different keyboard avoidance behaviors
struct KeyboardBehaviorExamples: View {
    @State private var inputText = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                
                // Example 1: Fixed positioning (current app behavior)
                VStack(spacing: 16) {
                    Text("Fixed Position Button")
                        .font(.headline)
                    Text("This button stays in place when keyboard appears")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Generate Podcast") {
                        // Action
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .keyboardAware(behavior: .none, additionalPadding: 20)
                }
                
                // Example 2: Keyboard avoiding (for input-heavy screens)
                VStack(spacing: 16) {
                    Text("Keyboard Avoiding Button")
                        .font(.headline)
                    Text("This button moves up when keyboard appears")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Type here to show keyboard", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Submit") {
                        // Action
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .keyboardAware(behavior: .avoidKeyboard, additionalPadding: 20)
                }
                
                // Example 3: Minimum padding (hybrid approach)
                VStack(spacing: 16) {
                    Text("Minimum Padding Button")
                        .font(.headline)
                    Text("This button uses minimum 100pt padding, but moves up if keyboard needs more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Flexible Button") {
                        // Action
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .keyboardAware(behavior: .minimumPadding(100), additionalPadding: 20)
                }
                
                Spacer(minLength: 200)
            }
            .padding()
        }
        .navigationTitle("Keyboard Behaviors")
    }
}

#Preview {
    NavigationView {
        KeyboardBehaviorExamples()
    }
}

