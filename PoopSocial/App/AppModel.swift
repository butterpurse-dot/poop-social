import SwiftUI

// MARK: - Navigation

enum RootTab: String, CaseIterable, Identifiable {
    case home
    case find
    case crew
    case me

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home:  return "Home"
        case .find:  return "Find"
        case .crew:  return "Crew"
        case .me:    return "Me"
        }
    }

    var icon: String {
        switch self {
        case .home:  return "house.fill"
        case .find:  return "mappin.and.ellipse"
        case .crew:  return "person.2.fill"
        case .me:    return "person.crop.circle.fill"
        }
    }
}

// MARK: - Composer

enum ComposerMode: String, CaseIterable, Identifiable {
    case drop
    case review

    var id: String { rawValue }

    var label: String {
        switch self {
        case .drop:   return "Drop"
        case .review: return "Review"
        }
    }

    var icon: String {
        switch self {
        case .drop:   return "text.bubble.fill"
        case .review: return "star.fill"
        }
    }
}

struct ComposerRequest: Identifiable {
    let id = UUID()
    var mode: ComposerMode
    var bathroom: Bathroom? = nil
}

// MARK: - Toast

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var emoji: String
    var title: String
    var detail: String? = nil
}

// MARK: - App model

/// Ephemeral, cross-screen UI state. Persistent data lives in SwiftData.
@MainActor
@Observable
final class AppModel {

    var tab: RootTab = .home
    var toast: Toast?
    var composer: ComposerRequest?
    var showOnboarding: Bool
    var showHygiene: Bool = false

    /// Set once the hygiene PSA has been opened. The Home screen uses it to
    /// stop showing the tip banner, which was previously a constant `true`
    /// that was read but never written.
    var hasSeenHygieneTip: Bool = false
    var openedProfileID: UUID?
    var openedPostID: UUID?

    /// Deep link to a bathroom's detail sheet, set from a launch argument.
    ///
    /// Why this exists: the Find screen is dominated by a MapKit map, and
    /// MapKit exposes a very large accessibility subtree. Any XCUITest query
    /// rooted at the app must snapshot that whole tree, so even a simple
    /// "tap the first bathroom card" query times out in the simulator --
    /// a tooling artifact, not a product defect. Opening the destination
    /// directly gives end-to-end tests a deterministic, fast path to the
    /// bathroom detail screen without weakening the app for real users.
    ///
    /// `-openBathroom <uuid>` opens a specific bathroom; `-openFirstBathroom`
    /// opens the newest one in the store.
    var deepLinkBathroomID: UUID?

    private var toastTask: Task<Void, Never>?

    init() {
        showOnboarding = !UserDefaults.standard.bool(forKey: "poopSocial.onboarded")

        // UI tests start on a known screen; onboarding is covered separately.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiTestingSkipOnboarding") {
            showOnboarding = false
        }

        // `-startTab <home|find|crew|me>` opens straight onto a tab.
        // Used by the screenshot walker, and handy for anyone poking at a
        // single surface without tapping through the app first.
        if let i = args.firstIndex(of: "-startTab"), i + 1 < args.count,
           let requested = RootTab(rawValue: args[i + 1].lowercased()) {
            tab = requested
        }

        // End-to-end deterministic deep-link to a bathroom detail (off by default).
        if args.contains("-openFirstBathroom") {
            deepLinkBathroomID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        } else if let i = args.firstIndex(of: "-openBathroom"), i + 1 < args.count {
            deepLinkBathroomID = UUID(uuidString: args[i + 1])
        }
        // The deep-link is handled by FindScreen, which only exists once the
        // Find tab is selected. Without this the app would open on Home and
        // the deep link would silently never fire.
        if deepLinkBathroomID != nil {
            tab = .find
        }
    }
    func show(_ toast: Toast) {
        self.toast = toast
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func compose(_ mode: ComposerMode, bathroom: Bathroom? = nil) {
        composer = ComposerRequest(mode: mode, bathroom: bathroom)
    }

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "poopSocial.onboarded")
        showOnboarding = false
    }
}
