import SwiftUI
import SwiftData

/// TikTok / Shorts energy, but every "clip" is an animated one-liner.
/// Deliberately photo- and video-free — that's the whole point of Poop Social.
@MainActor
struct ReelsScreen: View {

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store

    @Query(sort: \Post.createdAt, order: .reverse) private var posts: [Post]
    @Query private var profiles: [Profile]

    @State private var currentID: UUID?
    @State private var personRoute: PersonRoute?

    private var me: Profile? { profiles.first { $0.isMe } }

    private var reels: [Post] {
        posts.filter { $0.surface == .reel }
    }

    private var currentIndex: Int {
        reels.firstIndex { $0.id == currentID } ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if reels.isEmpty {
                    emptyState
                } else {
                    pager
                }

                overlays
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $personRoute) { route in
                PersonSheet(profile: route.profile)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
        }
    }

    // MARK: Pager

    private var pager: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(reels, id: \.id) { post in
                    ReelCard(
                        post: post,
                        me: me,
                        onOpenAuthor: {
                            if let author = post.author {
                                personRoute = PersonRoute(profile: author)
                            }
                        }
                    )
                    .containerRelativeFrame(.vertical)
                    .id(post.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $currentID)
        .ignoresSafeArea()
    }

    // MARK: Overlays

    @ViewBuilder
    private var overlays: some View {
        if !reels.isEmpty {
            VStack {
                HStack(alignment: .center) {
                    HStack(spacing: 7) {
                        Text("🧻").font(.system(size: 18))
                        Text("Reels")
                            .font(.display(19, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .black.opacity(0.4), radius: 8)

                    Spacer()

                    Button {
                        Haptics.tick()
                        app.compose(.reel)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(9)
                            .background(Circle().fill(Color.white.opacity(0.18)))
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                HStack(spacing: 6) {
                    ForEach(reels.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentIndex ? .white : Color.white.opacity(0.35))
                            .frame(width: index == currentIndex ? 18 : 6, height: 4)
                            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: currentIndex)
                    }
                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("0 photos · 100% vibes")
                            .font(.body(10, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .allowsHitTesting(true)
            .zIndex(2)
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("🎬").font(.system(size: 52))
            Text("No reels yet")
                .font(.display(20, weight: .heavy))
                .foregroundStyle(.white)
            Text("Reels are full-screen one-liners. No video, no photos — just the line and the vibe.")
                .font(.body(13))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 34)

            GlowButton(title: "Make the first reel", icon: "play.fill", gradient: Theme.juicy, fullWidth: false) {
                app.compose(.reel)
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - Reel card

@MainActor
private struct ReelCard: View {

    let post: Post
    let me: Profile?
    var onOpenAuthor: (() -> Void)? = nil

    @Environment(Store.self) private var store
    @Environment(AppModel.self) private var app

    @State private var appeared = false
    @State private var burst = 0

    private var backdrop: LinearGradient {
        Theme.reelBackdrops[post.backdrop % Theme.reelBackdrops.count]
    }

    private var headline: String {
        let source = post.joke.isEmpty ? post.body : post.joke
        return source.isEmpty ? post.emoji : source
    }

    var body: some View {
        ZStack {
            backdrop

            // Ambient bubbles, cheap and deterministic
            BubbleBackdrop(tint: .white, secondary: Theme.mint, count: 4)
                .opacity(0.18)

            // Floating emoji layer
            let glyphs = post.emoji.map { String($0) }
            ZStack {
                ForEach(glyphs.indices, id: \.self) { index in
                    Text(glyphs[index])
                        .font(.system(size: 26 + Double(index) * 6))
                        .position(
                            x: 40 + CGFloat((index * 137) % 320),
                            y: 150 + CGFloat((index * 211) % 420)
                        )
                        .opacity(appeared ? 0.20 : 0)
                }
            }
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 14) {
                Spacer()

                Text(headline)
                    .font(.display(31, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .opacity(appeared ? 1 : 0)

                if !post.body.isEmpty && post.joke != post.body && !post.joke.isEmpty {
                    Text(post.body)
                        .font(.body(15))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 22)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                }

                Spacer()
                Spacer()

                authorRow
                    .padding(.horizontal, 18)
                    .padding(.bottom, 26)
            }

            rightRail
                .frame(maxHeight: .infinity, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 10)

            EmojiBurst(emojis: ["🔥", "💯", "✨", "💖", "🫧"], trigger: burst)
                .allowsHitTesting(false)
        }
        .clipShape(Rectangle())
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { react() }
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.78)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }

    // MARK: Author

    private var authorRow: some View {
        HStack(spacing: 10) {
            Button { onOpenAuthor?() } label: {
                HStack(spacing: 8) {
                    AvatarView(emoji: post.author?.avatarEmoji ?? "🚽", size: 34, ring: .white.opacity(0.4))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.author?.displayName ?? "Someone")
                            .font(.body(13, weight: .bold))
                            .foregroundStyle(.white)
                        Text("@\(post.author?.handle ?? "ghost") · \(Format.ago(post.createdAt))")
                            .font(.body(10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.66))
                    }
                }
            }
            .buttonStyle(PressableStyle(scale: 0.94))

            Spacer()

            if !post.vibe.isEmpty {
                Text(post.vibe)
                    .font(.body(10, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
            }
        }
    }

    // MARK: Right rail

    private var rightRail: some View {
        VStack(spacing: 20) {
            railButton(
                icon: store.hasReacted("🔥", on: post, by: me) ? "heart.fill" : "heart",
                count: post.totalReactions,
                tint: store.hasReacted("🔥", on: post, by: me) ? Theme.bubble : .white
            ) { react() }

            railButton(
                icon: "bubble.left",
                count: 0,
                tint: .white
            ) {
                app.show(Toast(emoji: "💬", title: "Threads live in Home",
                               detail: "Open the drop to reply."))
            }

            railButton(
                icon: "arrow.2.squarepath",
                count: post.reposts.count,
                tint: store.hasReposted(post, by: me) ? Theme.mint : .white
            ) {
                let added = store.toggleRepost(post, by: me)
                Haptics.pop()
                app.show(Toast(emoji: "🔁", title: added ? "Reposted" : "Un-reposted",
                               detail: added ? "Sent to your crew." : nil))
            }

            railButton(icon: "arrowshape.turn.up.right", count: nil, tint: .white) {
                UIActivityBridge.share(shareText)
            }

            railButton(
                icon: store.hasBookmarked(post, by: me) ? "bookmark.fill" : "bookmark",
                count: nil,
                tint: store.hasBookmarked(post, by: me) ? Theme.tangerine : .white
            ) {
                let saved = store.toggleBookmark(post, by: me)
                Haptics.tick()
                app.show(Toast(emoji: "🔖", title: saved ? "Saved" : "Removed", detail: nil))
            }
        }
        .padding(.bottom, 24)
    }

    private func railButton(icon: String, count: Int?, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
                    .shadow(color: .black.opacity(0.35), radius: 6)
                if let count, count > 0 {
                    Text(Format.compact(count))
                        .font(.body(11, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                }
            }
        }
        .buttonStyle(PressableStyle(scale: 0.86))
    }

    private func react() {
        guard let me else { return }
        let added = store.toggleReaction("🔥", on: post, by: me)
        if added {
            burst += 1
            Haptics.pop()
        }
    }

    private var shareText: String {
        var parts = [headline]
        if let name = post.author?.displayName { parts.append("— \(name)") }
        parts.append("via Poop Social")
        return parts.joined(separator: "\n")
    }
}
