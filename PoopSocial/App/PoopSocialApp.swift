import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#endif

@main
@MainActor
struct PoopSocialApp: App {

    private let container: ModelContainer
    private let store: Store
    @State private var app = AppModel()

    init() {
        let schema = Schema([
            Profile.self,
            Bathroom.self,
            Review.self,
            Post.self,
            Reaction.self,
            Repost.self,
            Bookmark.self,
            Connection.self,
            Invite.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A corrupt store shouldn't brick the app — fall back to a fresh
            // in-memory graph so the user still gets a working session.
            container = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }

        store = Store(context: container.mainContext)
        SeedData.seedIfNeeded(context: container.mainContext)
        // App Intents run outside the view hierarchy, so they cannot use
        // `@Environment`. Hand them the same container and store the UI uses —
        // otherwise an intent's writes would land in a second, unseen store.
        AppGraph.shared.adopt(container: container, store: store)
        Self.styleBars()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(store)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .tint(Theme.mint)
        }
        #if os(macOS)
        // A phone-shaped window by default: the layout is designed for a
        // compact width, and letting it open at full screen width would stretch
        // the feed into an unreadable band. Resizable above this floor.
        .defaultSize(width: 430, height: 932)
        #endif
    }

    #if os(iOS)
    /// Style the UIKit bars to match the palette.
    ///
    /// iOS-only because these are UIKit appearance proxies: `UITabBar` and
    /// `UINavigationBar` do not exist on macOS, where SwiftUI renders the
    /// window chrome and sidebar itself. There is no macOS equivalent to write,
    /// so the call above is compiled out rather than adapted.
    ///
    /// The item colours are set explicitly for a measured reason: left to the
    /// system, unselected items render as neutral grey (#656667), which
    /// measured 3.35:1 against the navy bar — below the 4.5:1 WCAG AA floor for
    /// small text. Pinning them also keeps the bar on-palette if the system
    /// appearance changes.
    private static func styleBars() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Theme.nightSoft)
        tab.shadowColor = UIColor.white.withAlphaComponent(0.08)

        let selected = UIColor(Theme.mint)
        let normal = UIColor(Theme.inkDim)

        for layout in [tab.stackedLayoutAppearance,
                       tab.inlineLayoutAppearance,
                       tab.compactInlineLayoutAppearance] {
            layout.normal.iconColor = normal
            layout.normal.titleTextAttributes = [.foregroundColor: normal]
            layout.selected.iconColor = selected
            layout.selected.titleTextAttributes = [.foregroundColor: selected]
            // Unselected tint should not fade the icon further — inkDim is
            // already tuned for contrast on this bar.
            layout.normal.titlePositionAdjustment = .zero
        }

        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }
    #else
    /// No-op on macOS: SwiftUI owns the window chrome there, so there is
    /// nothing to override. Kept so the call site in `init` stays unconditional.
    private static func styleBars() {}
    #endif
}
