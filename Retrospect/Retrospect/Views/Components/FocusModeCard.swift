import SwiftUI

struct FocusModeCard: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    let keyboardHeight: CGFloat
    let isSendEnabled: Bool
    let onSend: () -> Void

    @FocusState private var isTextFieldFocused: Bool
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height

            // Card dimensions with margins
            let horizontalMargin: CGFloat = 20
            let cardWidth = screenWidth - (horizontalMargin * 2)

            // Vertical positioning - reduced margins for more height
            let topMargin: CGFloat = safeArea.top + 10
            let bottomMargin: CGFloat = keyboardHeight + 10
            let availableHeight = screenHeight - topMargin - bottomMargin

            VStack(spacing: 0) {
                // Text Field
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .font(.serifBody)
                    .foregroundColor(LinearColors.textPrimary)
                    .lineSpacing(TypographySpacing.bodyLineSpacing)
                    .padding(20)
                    .padding(.trailing, 52) // Make room for send button
                    .focused($isTextFieldFocused)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()
            }
            .background(
                ZStack(alignment: .topLeading) {
                    // Card background
                    RoundedRectangle(cornerRadius: BorderRadius.card)
                        .fill(LinearColors.cardBackground)
                        .shadow(
                            color: Shadows.cardShadow.color.opacity(0.3),
                            radius: 20,
                            x: 0,
                            y: 10
                        )

                    // Border
                    RoundedRectangle(cornerRadius: BorderRadius.card)
                        .strokeBorder(LinearColors.cardBorder, lineWidth: 1)

                    // Placeholder text
                    if text.isEmpty {
                        Text("Capture your thoughts, challenges, and experiences...")
                            .font(.serifBody)
                            .foregroundColor(LinearColors.textPlaceholder)
                            .padding(20)
                            .allowsHitTesting(false)
                    }
                }
            )
            .overlay(alignment: .bottomTrailing) {
                // Send button
                Button(action: {
                    HapticManager.shared.playMediumImpact()
                    onSend()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSendEnabled ? .white : LinearColors.textTertiary)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    isSendEnabled
                                        ? LinearGradient(
                                            gradient: Gradient(colors: [
                                                LinearColors.accent,
                                                LinearColors.accent.opacity(0.9),
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(
                                            gradient: Gradient(colors: [
                                                LinearColors.cardBackground,
                                                LinearColors.cardBackground,
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                                .shadow(
                                    color: isSendEnabled ? LinearColors.accent.opacity(0.3) : Color.black.opacity(0.05),
                                    radius: isSendEnabled ? 8 : 2,
                                    x: 0,
                                    y: isSendEnabled ? 4 : 1
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isSendEnabled ? LinearColors.accent.opacity(0.2) : LinearColors.cardBorder,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!isSendEnabled)
                .opacity(isSendEnabled ? 1.0 : 0.5)
                .scaleEffect(isSendEnabled ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSendEnabled)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
            .frame(width: cardWidth, height: availableHeight)
            .position(x: screenWidth / 2, y: topMargin + (availableHeight / 2))
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        // Only allow downward dragging
                        if value.translation.height > 0 {
                            state = value.translation.height
                        }
                    }
                    .onEnded { value in
                        // Dismiss if dragged down more than 100 points
                        if value.translation.height > 100 {
                            HapticManager.shared.playMediumImpact()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                isPresented = false
                            }
                        }
                    }
            )
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // Auto-focus when appearing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
}
