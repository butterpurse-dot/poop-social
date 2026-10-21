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
        .sheet(isPresented: $app.showHygiene) {
            HygieneScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .fullScreenPresentation(isPresented: $app.showOnboarding) {
            OnboardingScreen()
        }
    }
}
