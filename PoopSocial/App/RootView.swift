import SwiftUI
import SwiftData

@MainActor
struct RootView: View {

    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app

        ZStack(alignment: .top) {
            TabView(selection: $app.tab) {
                HomeScreen()
                    .tag(RootTab.home)
                    .tabItem { Label(RootTab.home.label, systemImage: RootTab.home.icon) }

                FindScreen()
                    .tag(RootTab.find)
                    .tabItem { Label(RootTab.find.label, systemImage: RootTab.find.icon) }

                CrewScreen()
                    .tag(RootTab.crew)
                    .tabItem { Label(RootTab.crew.label, systemImage: RootTab.crew.icon) }

                MeScreen()
                    .tag(RootTab.me)
                    .tabItem { Label(RootTab.me.label, systemImage: RootTab.me.icon) }
            }

            if let toast = app.toast {
                ToastView(toast: toast)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                    .onTapGesture { app.toast = nil }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: app.toast)
        .sheet(item: $app.composer) { request in
            ComposerSheet(request: request)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .sheet(isPresented: $app.showHygiene, onDismiss: {
            // Once the hygiene PSA has actually been viewed, the Home screen
            // stops showing the tip banner. Before this, `showTip` was a
            // constant `true` that was read but never written, so the tip was
            // permanently sticky -- it could be tapped but never got out of
            // the way.
            app.hasSeenHygieneTip = true
        }) {
            HygieneScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .fullScreenPresentation(isPresented: $app.showOnboarding) {
            OnboardingScreen()
        }
        // End-to-end state probe. Only constructed when the app is launched with
        // `-e2eProbe`, so this is dead code in every real run. It exists because
        // the UI tests can drive a write but had no way to verify the write
        // *persisted* -- and a post that vanishes on relaunch is exactly the bug
        // a smoke suite cannot see. See E2EStateProbe.swift.
        //
        // Attached with `.background`, NOT `.overlay`, and placed *behind* the
        // tab content. An overlay -- even with `allowsHitTesting(false)` --
        // still sat in front of the app for accessibility purposes, and the UI
        // tests then failed with:
        //
        //   Failed to scroll to visible (by AX action) Button,
        //   identifier: 'composeButton', error: kAXErrorCannotComplete
        //
        // The element existed and was tappable by a human; XCUITest simply could
        // not reach it. Behind the content, the probe is still in the hierarchy
        // (so its text is queryable) and cannot interfere with any tap.
        .background {
            if E2EStateProbe.isEnabled {
                E2EStateProbe()
            }
        }
    }
}
