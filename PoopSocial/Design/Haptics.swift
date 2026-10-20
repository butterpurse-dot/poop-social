import SwiftUI
import UIKit

/// Centralized haptics. This is most of what makes a UI feel "wired".
@MainActor
enum Haptics {

    static func tick() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred(intensity: 0.7)
    }

    static func pop() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        g.impactOccurred()
    }

    static func boom() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.prepare()
        g.impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warn() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func select() {
        let g = UISelectionFeedbackGenerator()
        g.prepare()
        g.selectionChanged()
    }
}
