import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Thin wrapper around the platform share sheet so views don't need to import
/// UIKit or AppKit directly.
///
/// The two platforms have genuinely different presentation models, so this is
/// not a one-line alias:
///
///   * **iOS** presents a `UIActivityViewController` from the top-most view
///     controller, which means walking the window scene for the key window.
///   * **macOS** has no view-controller hierarchy to walk — the idiomatic
///     equivalent is `NSSharingServicePicker`, which needs an anchor rect to
///     hang the popover from.
///
/// Both are wrapped so the calling SwiftUI code is identical on either platform.
@MainActor
enum UIActivityBridge {

    #if os(iOS)
    private static var topPresenter: UIViewController? {
        let key = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        var top = key?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
    #endif

    static func share(_ text: String) {
        #if os(iOS)
        guard let presenter = topPresenter else { return }
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        presenter.present(activity, animated: true)

        #elseif os(macOS)
        // Anchor from the key window's content view. A zero-size rect at the
        // origin is acceptable to AppKit: it falls back to centring the popover
        // rather than refusing to show, so there is no need to plumb a real
        // source view down from SwiftUI for this.
        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first,
              let view = window.contentView else { return }
        let picker = NSSharingServicePicker(items: [text])
        picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        #endif
    }
}
