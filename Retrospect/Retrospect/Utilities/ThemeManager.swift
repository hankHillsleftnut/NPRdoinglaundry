import Combine
import SwiftUI

// === THEME MANAGER - Dark Mode Control System ===
// Manages app-wide theme switching with smooth animations and persistence

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // MARK: - Published Properties

    @Published var isDarkMode: Bool {
        didSet {
            // Persist the setting
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")

            // Apply theme change with animation
            applyThemeChange()
        }
    }

    @Published var isTransitioning: Bool = false

    // MARK: - Computed Properties

    var currentColorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }

    var themeDisplayName: String {
        isDarkMode ? "Dark" : "Light"
    }

    var themeIcon: String {
        isDarkMode ? "moon.fill" : "sun.max.fill"
    }

    // MARK: - Initialization

    private init() {
        // Load persisted setting or default to system preference
        let savedDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool

        if let savedDarkMode {
            isDarkMode = savedDarkMode
        } else {
            // Default to system setting if no preference saved
            isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        }
    }

    // MARK: - Theme Control Methods

    func toggleTheme() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isDarkMode.toggle()
        }
    }

    func setTheme(_ darkMode: Bool, animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                isDarkMode = darkMode
            }
        } else {
            isDarkMode = darkMode
        }
    }

    func setLightMode(animated: Bool = true) {
        setTheme(false, animated: animated)
    }

    func setDarkMode(animated: Bool = true) {
        setTheme(true, animated: animated)
    }

    // MARK: - Private Methods

    private func applyThemeChange() {
        // Set transition state
        isTransitioning = true

        // Apply to all windows
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .forEach { window in
                    window.overrideUserInterfaceStyle = self.isDarkMode ? .dark : .light
                }
        }

        // Reset transition state after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isTransitioning = false
        }
    }

    // MARK: - System Integration

    func syncWithSystemTheme() {
        let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
        setTheme(systemIsDark, animated: true)
    }

    func resetToSystemDefault() {
        UserDefaults.standard.removeObject(forKey: "isDarkMode")
        syncWithSystemTheme()
    }
}

// MARK: - SwiftUI Environment Integration

struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - View Extensions for Theme Support

extension View {
    func withThemeManager() -> some View {
        environmentObject(ThemeManager.shared)
    }

    func preferredColorScheme(_ themeManager: ThemeManager) -> some View {
        preferredColorScheme(themeManager.currentColorScheme)
    }

    func animatedThemeTransition() -> some View {
        animation(.easeInOut(duration: 0.3), value: ThemeManager.shared.isDarkMode)
    }
}
