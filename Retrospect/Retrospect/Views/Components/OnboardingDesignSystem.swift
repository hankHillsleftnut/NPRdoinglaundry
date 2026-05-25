import SwiftUI

enum OnboardingStyle {
    static let background = Color(red: 0.894, green: 0.894, blue: 0.886)
    static let control = Color(red: 0.969, green: 0.953, blue: 0.933)
    static let controlPressed = Color(red: 0.929, green: 0.914, blue: 0.895)
    static let primaryText = Color(red: 0.071, green: 0.071, blue: 0.071)
    static let secondaryText = Color(red: 0.486, green: 0.475, blue: 0.459)
    static let tertiaryText = Color(red: 0.620, green: 0.620, blue: 0.620)
    static let hairline = Color.white.opacity(0.88)
    static let warmOutline = Color(red: 0.565, green: 0.384, blue: 0.133).opacity(0.15)
    static let danger = Color(red: 0.650, green: 0.090, blue: 0.070)
    static let success = Color(red: 0.275, green: 0.455, blue: 0.245)
    static let accent = Color(red: 0.160, green: 0.155, blue: 0.145)

    static func titleFont(size: CGFloat) -> Font {
        .custom("HedvigLettersSerif-24ptRegular", size: size)
    }

    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

struct OnboardingScaffold<Content: View, Bottom: View>: View {
    let iconName: String?
    let title: String
    let subtitle: String?
    let topSpacing: CGFloat
    var content: Content
    var bottom: Bottom

    init(
        iconName: String? = nil,
        title: String,
        subtitle: String? = nil,
        topSpacing: CGFloat = 82,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.iconName = iconName
        self.title = title
        self.subtitle = subtitle
        self.topSpacing = topSpacing
        self.content = content()
        self.bottom = bottom()
    }

    var body: some View {
        ZStack {
            OnboardingStyle.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer()
                            .frame(height: topSpacing)

                        if let iconName {
                            Image(systemName: iconName)
                                .font(OnboardingStyle.bodyFont(size: 18, weight: .medium))
                                .foregroundColor(OnboardingStyle.tertiaryText)
                                .frame(width: 24, height: 24, alignment: .leading)
                                .padding(.bottom, 16)
                        }

                        Text(title)
                            .font(OnboardingStyle.titleFont(size: 32))
                            .foregroundColor(OnboardingStyle.primaryText)
                            .tracking(-0.8)
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(OnboardingStyle.bodyFont(size: 16))
                                .foregroundColor(OnboardingStyle.secondaryText)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 20)
                        }

                        content
                            .padding(.top, 32)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
                }

                VStack(spacing: 12) {
                    bottom
                }
                .padding(.horizontal, 40)
                .padding(.top, 14)
                .padding(.bottom, 34)
                .background(
                    LinearGradient(
                        colors: [
                            OnboardingStyle.background.opacity(0),
                            OnboardingStyle.background.opacity(0.98),
                            OnboardingStyle.background
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .preferredColorScheme(.light)
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: OnboardingStyle.secondaryText))
                        .scaleEffect(0.82)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(OnboardingStyle.bodyFont(size: 18, weight: .medium))
                }

                Text(title)
                    .font(OnboardingStyle.bodyFont(size: 18, weight: .medium))
            }
            .foregroundColor(isDisabled ? OnboardingStyle.tertiaryText.opacity(0.55) : OnboardingStyle.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isDisabled ? OnboardingStyle.control.opacity(0.55) : OnboardingStyle.control)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(OnboardingStyle.hairline, lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(OnboardingStyle.warmOutline, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(isDisabled ? 0.04 : 0.18), radius: 2, x: 0, y: 1)
                    .shadow(color: .black.opacity(isDisabled ? 0.03 : 0.10), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled || isLoading)
    }
}

struct OnboardingOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var status: String? = nil
    var isSelected: Bool = false
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(OnboardingStyle.bodyFont(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? OnboardingStyle.primaryText : OnboardingStyle.secondaryText)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(OnboardingStyle.bodyFont(size: 16, weight: .medium))
                        .foregroundColor(OnboardingStyle.primaryText)

                    Text(subtitle)
                        .font(OnboardingStyle.bodyFont(size: 13))
                        .foregroundColor(OnboardingStyle.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: OnboardingStyle.tertiaryText))
                        .scaleEffect(0.8)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(OnboardingStyle.bodyFont(size: 20, weight: .medium))
                        .foregroundColor(OnboardingStyle.success)
                } else if let status {
                    Text(status)
                        .font(OnboardingStyle.bodyFont(size: 12, weight: .medium))
                        .foregroundColor(OnboardingStyle.tertiaryText)
                } else {
                    Image(systemName: "plus")
                        .font(OnboardingStyle.bodyFont(size: 16, weight: .medium))
                        .foregroundColor(OnboardingStyle.tertiaryText)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(OnboardingStyle.control.opacity(isDisabled ? 0.55 : 0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(isSelected ? OnboardingStyle.primaryText.opacity(0.16) : OnboardingStyle.hairline, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(isSelected ? 0.10 : 0.06), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled || isLoading)
    }
}

struct OnboardingTextInput: View {
    @Binding var text: String
    let placeholder: String
    var minHeight: CGFloat = 148

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(OnboardingStyle.bodyFont(size: 16))
                    .foregroundColor(OnboardingStyle.tertiaryText)
                    .lineSpacing(5)
                    .padding(.top, 18)
                    .padding(.horizontal, 18)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(OnboardingStyle.bodyFont(size: 17))
                .foregroundColor(OnboardingStyle.primaryText)
                .lineSpacing(5)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(minHeight: minHeight)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(OnboardingStyle.control.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(OnboardingStyle.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
}

struct OnboardingStatusPill: View {
    let text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(OnboardingStyle.bodyFont(size: 12, weight: .medium))
            }

            Text(text)
                .font(OnboardingStyle.bodyFont(size: 13, weight: .medium))
        }
        .foregroundColor(OnboardingStyle.tertiaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(OnboardingStyle.control.opacity(0.58))
        )
    }
}
