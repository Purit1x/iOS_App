import SwiftUI
import Combine

struct KeyboardAdaptive: ViewModifier {
    @State private var bottomPadding: CGFloat = 0
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .padding(.bottom, bottomPadding)
                .onAppear {
                    NotificationCenter.default.addObserver(
                        forName: UIResponder.keyboardWillShowNotification,
                        object: nil,
                        queue: .main
                    ) { notification in
                        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                            return
                        }
                        
                        let keyboardHeight = keyboardFrame.height
                        let bottomInset = geometry.safeAreaInsets.bottom
                        
                        withAnimation(.easeOut(duration: 0.25)) {
                            bottomPadding = keyboardHeight - bottomInset
                        }
                    }
                    
                    NotificationCenter.default.addObserver(
                        forName: UIResponder.keyboardWillHideNotification,
                        object: nil,
                        queue: .main
                    ) { _ in
                        withAnimation(.easeOut(duration: 0.25)) {
                            bottomPadding = 0
                        }
                    }
                }
        }
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptive())
    }
} 