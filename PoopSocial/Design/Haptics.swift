import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Centralized haptics. This is most of what makes a UI feel "wired".
///
/// ## Why the `#if os(iOS)` split
///
/// The app builds for iOS and for macOS. Haptics are an iOS concept: a Mac has
/// no taptic engine to drive, so on macOS every one of these is a deliberate
/// no-op rather than an error. Keeping the calls in the API means the calling
/// code stays identical on both platforms — nobody has to write
/// `#if os(iOS)` around every button, which is how haptics normally become
/// inconsistent across a codebase.
///
/// The alternative — dropping haptics on macOS by *deleting* the calls at the
/// call sites — would mean the iOS build loses them too, since it is the same
/// source. Guarding the implementation instead keeps both platforms honest.
@MainActor
enum Haptics {

    static func tick() {
        #if os(iOS)
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred(intensity: 0.7)
        #endif
    }

    static func pop() {
        #if os(iOS)
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        g.impactOccurred()
        #endif
    }

    static func boom() {
        #if os(iOS)
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.prepare()
        g.impactOccurred()
        #endif
    }

    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warn() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    static func select() {
        #if os(iOS)
        let g = UISelectionFeedbackGenerator()
        g.prepare()
        g.selectionChanged()
        #endif
    }
}
