import SwiftUI

struct RetrospectLoadingScreen: View {
    let status: String?
    let errorMessage: String?
    private let opticalCenterYOffset: CGFloat = -22

    init(status: String? = nil, errorMessage: String? = nil) {
        self.status = status
        self.errorMessage = errorMessage
    }

    var body: some View {
        ZStack {
            OnboardingStyle.background
                .ignoresSafeArea()

            Image("retrospect-loading-mark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 87, height: 66)
                .opacity(0.28)
                .offset(y: opticalCenterYOffset)
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    RetrospectLoadingScreen()
}
