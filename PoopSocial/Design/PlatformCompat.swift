import SwiftUI
import CoreLocation

#if os(iOS)
import UIKit
#endif

// MARK: - Cross-platform text-input modifiers
//
// SwiftUI's text-input modifiers are not uniformly available: `keyboardType`,
// `textInputAutocapitalization` and `textInputAutocapitalization(_:)` are iOS
// (and tvOS/watchOS) only, because they describe a *software keyboard*. A Mac
// has a hardware keyboard with no autocapitalisation setting to apply.
//
// Rather than write `#if os(iOS)` at all thirteen call sites — which would make
// every form in the app harder to read and easy to get wrong when a new field
// is added — the modifiers are wrapped here so the call sites stay identical
// on both platforms and the platform difference is stated once.
//
// On macOS these are deliberate no-ops, not omissions: the behaviour they ask
// for is genuinely not applicable, so doing nothing is correct.

/// Autocapitalisation mode, named independently of SwiftUI.
///
/// SwiftUI's own `TextInputAutocapitalization` is absent from the macOS SDK, so
/// it cannot appear in a cross-platform signature. This enum is the app's own
/// vocabulary for the two modes it actually uses, and `.system` converts where
/// the platform has the type.
enum Capitalization {
    case never
    case words

    #if os(iOS)
    var system: TextInputAutocapitalization {
        switch self {
        case .never: return .never
        case .words: return .words
        }
    }
    #endif
}

extension View {

    /// Disable autocapitalisation. No-op on macOS (hardware keyboard).
    func noAutocapitalization() -> some View {
        #if os(iOS)
        return textInputAutocapitalization(.never)
        #else
        return self
        #endif
    }

    /// Capitalise each word. No-op on macOS (hardware keyboard).
    func wordsAutocapitalization() -> some View {
        #if os(iOS)
        return textInputAutocapitalization(.words)
        #else
        return self
        #endif
    }

    /// Ask for the email-address keyboard. No-op on macOS.
    func emailKeyboard() -> some View {
        #if os(iOS)
        return keyboardType(.emailAddress)
        #else
        return self
        #endif
    }

    /// Choose an autocapitalisation mode from a runtime value.
    ///
    /// A separate entry point from `noAutocapitalization()` because the profile
    /// editor picks the mode from the field content — a handle field must not
    /// capitalise, a display-name field must.
    ///
    /// Takes our own `Capitalization` rather than SwiftUI's
    /// `TextInputAutocapitalization`, because that type does not exist in the
    /// macOS SDK: naming it in a signature would fail to compile there even
    /// though the body is compiled out.
    func conditionalAutocapitalization(_ mode: Capitalization) -> some View {
        #if os(iOS)
        return textInputAutocapitalization(mode.system)
        #else
        return self
        #endif
    }

    /// Present a screen that should fill the window.
    ///
    /// `fullScreenCover` is iOS-only: macOS has no full-screen-cover concept in
    /// SwiftUI, only sheets and windows. Onboarding wants to take over the
    /// screen on iOS, so the wrapper keeps that intent there and falls back to
    /// the closest macOS equivalent — a sheet — rather than dropping the
    /// presentation entirely (which would leave onboarding unreachable).
    func fullScreenPresentation<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        return fullScreenCover(isPresented: isPresented, content: content)
        #else
        return sheet(isPresented: isPresented, content: content)
        #endif
    }

    /// Hide the navigation bar for a screen that draws its own header.
    ///
    /// iOS hides the UINavigationBar; macOS has no navigation bar to hide, so
    /// the call is dropped. The screens that use this draw their own header on
    /// both platforms, so the visible result matches.
    func hidesNavigationBar() -> some View {
        #if os(iOS)
        return toolbar(.hidden, for: .navigationBar)
        #else
        return self
        #endif
    }
}

// MARK: - Swipeable onboarding pager, stated once
//
// `TabView` with `.tabViewStyle(.page)` is iOS-only: the paging behaviour is
// built on UIPageViewController and has no macOS equivalent. Onboarding is a
// four-page swipe deck, so on macOS the pages are shown one at a time — the
// same selection, the same order and the same spring animation, just without
// the swipe gesture a Mac user would not expect anyway. The alternative (an
// `#if os(iOS)` around the whole body) would duplicate the page list and let
// the two platforms drift.
struct OnboardingPager<Content: View>: View {
    @Binding var page: Int
    let count: Int
    @ViewBuilder let content: (Int) -> Content

    var body: some View {
        #if os(iOS)
        TabView(selection: $page) {
            ForEach(0..<count, id: \.self) { i in
                content(i).tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        #else
        // macOS has no pager, so draw just the selected page. Keyed by `page`
        // so the transition animation still fires when the index changes.
        content(page)
            .id(page)
            .transition(.opacity)
        #endif
    }
}

// MARK: - Location authorisation, stated once
//
// `CLAuthorizationStatus.authorizedWhenInUse` is iOS-only: on macOS there is no
// "while using the app" distinction, an app is simply authorised or not. The
// comparison is wrapped so the location provider reads the same on both.
extension CLAuthorizationStatus {
    /// Is the app allowed to read location right now?
    var allowsLocationUse: Bool {
        switch self {
        case .authorizedAlways:
            return true
        #if os(iOS)
        case .authorizedWhenInUse:
            return true
        #endif
        default:
            return false
        }
    }
}
