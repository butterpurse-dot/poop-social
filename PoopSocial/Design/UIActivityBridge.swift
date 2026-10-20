import Foundation
import UIKit

/// Thin wrapper around the share sheet so views don't need to import UIKit directly.
@MainActor
enum UIActivityBridge {

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

    static func share(_ text: String) {
        guard let presenter = topPresenter else { return }
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        presenter.present(activity, animated: true)
    }
}
