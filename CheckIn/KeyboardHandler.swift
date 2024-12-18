import SwiftUI
import UIKit

struct KeyboardHandler: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    @State private var observers: [NSObjectProtocol] = []
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onAppear {
                setupKeyboardObservers()
            }
            .onDisappear {
                removeKeyboardObservers()
            }
    }
    
    private func setupKeyboardObservers() {
        let notificationCenter = NotificationCenter.default
        
        let willShow = notificationCenter.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
            }
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        let willHide = notificationCenter.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
        
        observers = [willShow, willHide]
    }
    
    private func removeKeyboardObservers() {
        let notificationCenter = NotificationCenter.default
        observers.forEach { observer in
            notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }
}

extension View {
    func handleKeyboard() -> some View {
        modifier(KeyboardHandler())
    }
} 