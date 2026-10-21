import SwiftUI
import SwiftData

@MainActor
struct ThreadSheet: View {

    let post: Post

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Post.createdAt, order: .forward) private var allPosts: [Post]
    @Query private var profiles: [Profile]

    @State private var replyText = ""
    @State private var burst = 0
    @State private var personRoute: PersonRoute?
    @State private var bathroomRoute: BathroomRoute?
    @State private var threadRoute: PostRoute?

    private var me: Profile? { profiles.first { $0.isMe } }

    private var replies: [Post] {
        allPosts.filter { $0.parentID == post.id }
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            BubbleBackdrop(tint: Theme.grape, secondary: Theme.mint, count: 4)

            VStack(spacing: 0) {
                header

                ScrollView {
                    LazyVStack(spacing: 10) {
                        PostCard(post: post, me: me, replyCount: replies.count,
                                onOpenThread: { threadRoute = PostRoute(post: post) },
                                onOpenAuthor: { if let a = post.author { personRoute = PersonRoute(profile: a) } },
                                onOpenBathroom: { if let b = post.bathroom { bathroomRoute = BathroomRoute(bathroom: b) } })

                        HStack(spacing: 10) {
                            Capsule().fill(Color.white.opacity(0.10))
                                .frame(width: 2)
                            Text("\(replies.count) \(replies.count == 1 ? "reply" : "replies")")
                                .font(.body(12, weight: .bold))
                                .foregroundStyle(Theme.inkFaint)
                            Spacer()
                        }
                        .padding(.leading, 6)
                        .padding(.top, 6)

                        ForEach(Array(replies.indices), id: \.self) { index in
                            let reply = replies[index]
                            PostCard(
                                post: reply,
                                me: me,
                                onOpenAuthor: { if let a = reply.author { personRoute = PersonRoute(profile: a) } }
                            )
                            .popIn(index)
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            replyBar
        }
        .sheet(item: $personRoute) { route in
            PersonSheet(profile: route.profile)
                .presentationDetents([.large])
        }
        .sheet(item: $bathroomRoute) { route in
            BathroomDetailScreen(bathroom: route.bathroom)
                .presentationDetents([.large])
        }
        .sheet(item: $threadRoute) { route in
            ThreadSheet(post: route.post)
                .presentationDetents([.large])
        }
        .overlay(alignment: .center) {
            EmojiBurst(emojis: ["🔥", "💬", "✨", "🚽"], trigger: burst)
                .allowsHitTesting(false)
        }
    }

    private var header: some View {
        HStack {
            Text("Thread")
                .font(.display(20, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.inkDim)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(PressableStyle(scale: 0.9))
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var replyBar: some View {
        HStack(spacing: 10) {
            AvatarView(emoji: me?.avatarEmoji ?? "🚽", size: 32, ring: Theme.mint.opacity(0.5))

            ZStack(alignment: .leading) {
                if replyText.isEmpty {
                    Text("Reply to \(post.author?.displayName ?? "this post")…")
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                TextField("", text: $replyText, axis: .vertical)
                    .font(.body(14))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .lineLimit(1...4)
            }
            .background(
                Capsule().fill(Color.white.opacity(0.06))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            )

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.night)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(
                            trimmed.isEmpty
                            ? LinearGradient(colors: [Color.white.opacity(0.14)], startPoint: .top, endPoint: .bottom)
                            : Theme.hero
                        )
                    )
            }
            .buttonStyle(PressableStyle(scale: 0.88))
            .disabled(trimmed.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                }
        )
    }

    private var trimmed: String {
        replyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        let verdict = Safety.moderator.validate(text: replyText)
        guard verdict.isAllowed else {
            Haptics.warn()
            app.show(Toast(emoji: verdict.reason?.emoji ?? "🧼",
                           title: verdict.reason?.title ?? "Blocked",
                           detail: verdict.reason?.detail))
            return
        }

        guard let me else { return }

        store.createPost(
            author: me,
            body: replyText,
            emoji: "💬",
            joke: "",
            surface: .drop,
            bathroom: post.bathroom,
            verdict: .neutral,
            parentID: post.id
        )

        replyText = ""
        burst += 1
        Haptics.success()
    }
}
