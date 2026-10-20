import SwiftUI
import SwiftData
import UIKit

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
    }

    private static func styleBars() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Theme.nightSoft)
        tab.shadowColor = UIColor.white.withAlphaComponent(0.08)

        // Item colours must be set explicitly. Left to the system, unselected
        // items render as neutral grey (#656667), which measured 3.35:1 against
        // the navy bar — below the 4.5:1 WCAG AA floor for small text. Pinning
        // them also keeps the bar on-palette if the system appearance changes.
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
}
