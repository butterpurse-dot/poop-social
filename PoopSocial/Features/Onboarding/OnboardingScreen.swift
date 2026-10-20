import SwiftUI

@MainActor
struct OnboardingScreen: View {

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store

    @State private var page = 0
    @State private var name = ""
    @State private var handle = ""
    @State private var avatar = "🚽"
    @State private var burstToken = 0

    private let avatars = ["🚽", "🌸", "🧢", "🪐", "🦆", "🧼", "🎧", "🍭", "🧃", "😎", "👽", "🐸", "🦄", "🤖", "🐙", "🍄"]

    private var canFinish: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !handle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            BubbleBackdrop(tint: Theme.mint, secondary: Theme.bubble)

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcome.tag(0)
                    throne.tag(1)
                    social.tag(2)
                    claim.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: page)

                bottomBar
            }
        }
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                PulseHalo(color: Theme.mint, size: 140)
                Text("🚽").font(.system(size: 96))
            }
            .padding(.bottom, 8)

            Text("Poop Social")
                .font(.display(42, weight: .black))
                .foregroundStyle(
                    LinearGradient(colors: [Theme.mint, Theme.sky, Theme.bubble],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .neon(Theme.mint, radius: 22, intensity: 0.45)

            Text("No photos. Only vibes.")
                .font(.display(19, weight: .semibold))
                .foregroundStyle(Theme.inkDim)

            Text("Find bathrooms, rate the throne, and roast the paper towel dispenser with your crew.")
                .font(.body(15))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
                .padding(.top, 2)

            Spacer()
        }
    }

    private var throne: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🗺️").font(.system(size: 66))

            Text("Find a throne, fast")
                .font(.display(30, weight: .heavy))
                .foregroundStyle(Theme.ink)

            VStack(spacing: 12) {
                featureRow("toilet.fill", Theme.mint,
                           "Live bathroom map",
                           "Cleanliness scores, amenities and wait times from people who were actually there.")
                featureRow("star.fill", Theme.tangerine,
                           "Rate the experience",
                           "Satisfying or not. One dial. No essay required.")
                featureRow("person.2.fill", Theme.bubble,
                           "Crew & acquaintances",
                           "Two tiers of friendship, because bathroom trust is not binary.")
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)

            Spacer()
        }
    }

    private var social: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🎬").font(.system(size: 66))

            Text("A whole social network\nfor bathroom discourse")
                .font(.display(28, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                featureRow("text.bubble.fill", Theme.mint, "Drops", "Short posts and threads. The timeline, but funnier.")
                featureRow("play.rectangle.fill", Theme.grape, "Reels", "Full-screen one-liners. Swipe up. No video, no photos.")
                featureRow("sparkles", Theme.bubble, "Comedy engine", "Movie-trailer energy, slang and hygiene PSAs on tap.")
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)

            Spacer()
        }
    }

    private var claim: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Claim your handle")
                    .font(.display(30, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 30)

                Text("This is how your crew finds you.")
                    .font(.body(14))
                    .foregroundStyle(Theme.inkFaint)

                Text(avatar)
                    .font(.system(size: 62))
                    .frame(width: 108, height: 108)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [Theme.slate, Theme.nightSoft],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .overlay(Circle().strokeBorder(Theme.mint.opacity(0.5), lineWidth: 2))
                    .neon(Theme.mint, radius: 20, intensity: 0.3)
                    .padding(.top, 4)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                    ForEach(avatars, id: \.self) { emoji in
                        Button {
                            Haptics.tick()
                            avatar = emoji
                        } label: {
                            Text(emoji)
                                .font(.system(size: 22))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(avatar == emoji ? Theme.mint.opacity(0.22) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .strokeBorder(avatar == emoji ? Theme.mint : .clear, lineWidth: 1.4)
                                )
                        }
                        .buttonStyle(PressableStyle(scale: 0.88))
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    field(title: "Display name", text: $name, placeholder: "e.g. Maya")
                    field(title: "Handle", text: $handle, placeholder: "mayaflush", prefix: "@")
                }
                .padding(.horizontal, 20)

                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("There is no photo upload. Not now, not ever.")
                }
                .font(.body(12, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.05)))
                .padding(.top, 2)

                Spacer(minLength: 20)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Chrome

    private var bottomBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.mint : Color.white.opacity(0.18))
                        .frame(width: i == page ? 22 : 7, height: 7)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
                }
            }

            GlowButton(
                title: page == 3 ? "Enter Poop Social" : "Next",
                icon: page == 3 ? "sparkles" : "chevron.right",
                enabled: page == 3 ? canFinish : true
            ) {
                if page < 3 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { page += 1 }
                } else {
                    finish()
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 18)
        .padding(.top, 8)
    }

    private func featureRow(_ icon: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBubble(icon: icon, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body(14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.body(12))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func field(title: String, text: Binding<String>, placeholder: String, prefix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body(11, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .textCase(.uppercase)
            HStack(spacing: 2) {
                if !prefix.isEmpty {
                    Text(prefix).foregroundStyle(Theme.mint).font(.body(15, weight: .bold))
                }
                TextField(placeholder, text: text)
                    .font(.body(15, weight: .semibold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
    }

    private func finish() {
        store.updateProfile(
            displayName: name,
            handle: handle,
            avatarEmoji: avatar,
            bio: "New here. Ready to rate.",
            city: "San Francisco"
        )
        Haptics.success()
        app.finishOnboarding()
        app.show(Toast(emoji: avatar, title: "Welcome, \(name.components(separatedBy: " ").first ?? name)",
                       detail: "Your handle is @\(handle.replacingOccurrences(of: "@", with: ""))"))
    }
}
