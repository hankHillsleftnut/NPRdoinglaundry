import SwiftUI

// === COSTAR-INSPIRED TEXT INPUT SYSTEM ===
// Clean white cards with subtle borders and elegant typography

struct CoStarTextInput: View {
    let placeholder: String
    @Binding var text: String
    @FocusState.Binding var isFocused: InputField?
    let field: InputField
    let isMultiline: Bool
    let minHeight: CGFloat
    
    init(
        placeholder: String,
        text: Binding<String>,
        isFocused: FocusState<InputField?>.Binding,
        field: InputField,
        isMultiline: Bool = true,
        minHeight: CGFloat = 120
    ) {
        self.placeholder = placeholder
        self._text = text
        self._isFocused = isFocused
        self.field = field
        self.isMultiline = isMultiline
        self.minHeight = minHeight
    }
    
    private var isActive: Bool {
        isFocused == field
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Background and border
                RoundedRectangle(cornerRadius: BorderRadius.input)
                    .fill(LinearColors.inputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.input)
                            .stroke(
                                isActive ? LinearColors.inputFocusBorder : LinearColors.inputBorder,
                                lineWidth: isActive ? 2 : 1
                            )
                    )
                
                // Placeholder
                if text.isEmpty {
                    Text(placeholder)
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textPlaceholder)
                        .padding(.horizontal, Spacing.cardPadding)
                        .padding(.vertical, Spacing.cardPadding)
                        .allowsHitTesting(false)
                        .opacity(isActive ? 0.6 : 1)
                        .animation(Animations.focusTransition, value: isActive)
                }
                
                // Text input
                if isMultiline {
                    TextEditor(text: $text)
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, Spacing.cardPadding)
                        .padding(.vertical, Spacing.cardPadding)
                        .focused($isFocused, equals: field)
                        .frame(minHeight: minHeight)
                        .lineSpacing(TypographySpacing.bodyLineSpacing)
                } else {
                    TextField("", text: $text)
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textPrimary)
                        .padding(.horizontal, Spacing.cardPadding)
                        .padding(.vertical, Spacing.cardPadding)
                        .focused($isFocused, equals: field)
                        .frame(height: Spacing.inputHeight)
                }
            }
            .shadow(
                color: Shadows.inputShadow.color,
                radius: Shadows.inputShadow.radius,
                x: Shadows.inputShadow.x,
                y: Shadows.inputShadow.y
            )
            .animation(Animations.focusTransition, value: isActive)
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { gesture in
                    if gesture.translation.height > 0 && gesture.translation.width < 100 {
                        isFocused = nil
                        HapticManager.shared.playLightImpact()
                    }
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    if !isActive {
                        HapticManager.shared.playLightImpact()
                    }
                }
        )
    }
}

// === SINGLE LINE TEXT INPUT ===
struct CoStarSingleLineInput: View {
    let placeholder: String
    @Binding var text: String
    @FocusState var isFocused: Bool
    let leadingIcon: String?
    let trailingIcon: String?
    let onTrailingIconTap: (() -> Void)?
    
    init(
        placeholder: String,
        text: Binding<String>,
        leadingIcon: String? = nil,
        trailingIcon: String? = nil,
        onTrailingIconTap: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.onTrailingIconTap = onTrailingIconTap
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Leading icon
            if let leadingIcon = leadingIcon {
                Image(systemName: leadingIcon)
                    .font(.serifBody)
                    .foregroundColor(LinearColors.textSecondary)
            }
            
            // Text field
            TextField(placeholder, text: $text)
                .font(.serifBody)
                .foregroundColor(LinearColors.textPrimary)
                .focused($isFocused)
            
            // Trailing icon
            if let trailingIcon = trailingIcon {
                Button(action: {
                    onTrailingIconTap?()
                    HapticManager.shared.playLightImpact()
                }) {
                    Image(systemName: trailingIcon)
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textSecondary)
                }
                .coStarMinimalButton()
            }
        }
        .padding(.horizontal, Spacing.cardPadding)
        .frame(height: Spacing.inputHeight)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.input)
                .fill(LinearColors.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.input)
                        .stroke(
                            isFocused ? LinearColors.inputFocusBorder : LinearColors.inputBorder,
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
        .shadow(
            color: Shadows.inputShadow.color,
            radius: Shadows.inputShadow.radius,
            x: Shadows.inputShadow.x,
            y: Shadows.inputShadow.y
        )
        .animation(Animations.focusTransition, value: isFocused)
    }
}

// === SEARCH INPUT (Specialized for search functionality) ===
struct CoStarSearchInput: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool
    let onSearchTap: (() -> Void)?
    let onClearTap: (() -> Void)?
    
    init(
        searchText: Binding<String>,
        onSearchTap: (() -> Void)? = nil,
        onClearTap: (() -> Void)? = nil
    ) {
        self._searchText = searchText
        self.onSearchTap = onSearchTap
        self.onClearTap = onClearTap
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.serifBody)
                .foregroundColor(LinearColors.textSecondary)
            
            // Search field
            TextField("Search...", text: $searchText)
                .font(.serifBody)
                .foregroundColor(LinearColors.textPrimary)
                .focused($isFocused)
                .onSubmit {
                    onSearchTap?()
                }
            
            // Clear button (when there's text)
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    onClearTap?()
                    HapticManager.shared.playLightImpact()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.serifBody)
                        .foregroundColor(LinearColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.cardPadding)
        .frame(height: Spacing.inputHeight)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.input)
                .fill(LinearColors.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.input)
                        .stroke(
                            isFocused ? LinearColors.inputFocusBorder : LinearColors.inputBorder,
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
        .shadow(
            color: Shadows.inputShadow.color,
            radius: Shadows.inputShadow.radius,
            x: Shadows.inputShadow.x,
            y: Shadows.inputShadow.y
        )
        .animation(Animations.focusTransition, value: isFocused)
    }
}

// === CONVENIENCE EXTENSIONS ===
extension View {
    func coStarTextInput(
        placeholder: String,
        text: Binding<String>,
        isFocused: FocusState<InputField?>.Binding,
        field: InputField,
        isMultiline: Bool = true,
        minHeight: CGFloat = 120
    ) -> some View {
        CoStarTextInput(
            placeholder: placeholder,
            text: text,
            isFocused: isFocused,
            field: field,
            isMultiline: isMultiline,
            minHeight: minHeight
        )
    }
} 