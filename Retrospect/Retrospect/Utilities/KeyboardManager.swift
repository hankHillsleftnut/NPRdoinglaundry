import Combine
import SwiftUI

/// Robust keyboard management system for the entire app
/// Provides keyboard height tracking and configurable avoidance behavior
class KeyboardManager: ObservableObject {
    static let shared = KeyboardManager()

    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupKeyboardObservers()
    }

    deinit {
        cancellables.removeAll()
    }

    private func setupKeyboardObservers() {
        // Keyboard will show
        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification -> (CGFloat, Double)? in
                guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
                      let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                    return nil
                }
                return (keyboardFrame.cgRectValue.height, duration)
            }
            .sink { [weak self] height, duration in
                withAnimation(.easeInOut(duration: duration)) {
                    self?.keyboardHeight = height
                    self?.isKeyboardVisible = true
                }
            }
            .store(in: &cancellables)

        // Keyboard will hide
        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .compactMap { notification -> Double? in
                notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            }
            .sink { [weak self] duration in
                withAnimation(.easeInOut(duration: duration)) {
                    self?.keyboardHeight = 0
                    self?.isKeyboardVisible = false
                }
            }
            .store(in: &cancellables)
    }
}

/// View modifier that handles keyboard avoidance behavior
struct KeyboardAware: ViewModifier {
    @StateObject private var keyboardManager = KeyboardManager.shared

    let behavior: KeyboardAvoidanceBehavior
    let additionalPadding: CGFloat

    init(behavior: KeyboardAvoidanceBehavior = .none, additionalPadding: CGFloat = 0) {
        self.behavior = behavior
        self.additionalPadding = additionalPadding
    }

    func body(content: Content) -> some View {
        content
            .padding(.bottom, bottomPadding)
    }

    private var bottomPadding: CGFloat {
        switch behavior {
        case .none:
            return additionalPadding
        case .avoidKeyboard:
            return keyboardManager.isKeyboardVisible ? keyboardManager.keyboardHeight + additionalPadding : additionalPadding
        case let .minimumPadding(minPadding):
            return max(minPadding, keyboardManager.isKeyboardVisible ? keyboardManager.keyboardHeight + additionalPadding : additionalPadding)
        }
    }
}

/// Keyboard avoidance behavior options
enum KeyboardAvoidanceBehavior {
    case none // Stay in place regardless of keyboard
    case avoidKeyboard // Move up when keyboard appears
    case minimumPadding(CGFloat) // Use minimum padding but move up if keyboard requires more
}

/// Convenience view extension
extension View {
    func keyboardAware(behavior: KeyboardAvoidanceBehavior = .none, additionalPadding: CGFloat = 0) -> some View {
        modifier(KeyboardAware(behavior: behavior, additionalPadding: additionalPadding))
    }
}
