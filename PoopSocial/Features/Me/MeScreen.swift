import SwiftUI
import SwiftData

private struct BadgeItem: Identifiable {
    let emoji: String
    let title: String
    let earned: Bool
    let tint: Color
    var id: String { title }
}

@MainActor
struct MeScreen: View {

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store

    @Query(sort: \Post.createdAt, order: .reverse) private var posts: [Post]
    @Query private var profiles: [Profile]

    @AppStorage("poopSocial.tipsCollected") private var collectedRaw = ""
    @AppStorage("poopSocial.streak") private var streak = 1

    @State private var showEdit = false
    @State private var personRoute: PersonRoute?
    @State private var threadRoute: PostRoute?

    private var me: Profile? { profiles.first { $0.isMe } }

    private var myPosts: [Post] {
        guard let me else { return [] }
        return posts.filter { $0.author?.id == me.id && !$0.isReply }
    }

    private var myDrops: [Post] {
        myPosts.filter { $0.surface == .drop }
    }

    private var saved: [Post] {
        guard let me else { return [] }
        return me.bookmarks.compactMap { $0.post }.sorted { $0.createdAt > $1.createdAt }
    }

    private var collected: Set<String> {
        Set(collectedRaw.split(separator: ",").map(String.init))
    }

    private var xp: Int {
        HygieneTips.all.filter { collected.contains($0.id) }.reduce(0) { $0 + $1.xp }
    }

    private var level: Int { xp / 40 + 1 }
    private var levelProgress: Double { Double(xp % 40) / 40.0 }

    private var stats: (posts: Int, reviews: Int, crew: Int, satisfying: Int, bathrooms: Int) {
        store.myStats()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                BubbleBackdrop(tint: Theme.bubble, secondary: Theme.mint)

                ScrollView {
                    LazyVStack(spacing: 14) {
                        header
                        profileCard
                        statsRow
                        hygieneCard
                        badges
                        if !saved.isEmpty { savedSection }
                        myDropsSection
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .hidesNavigationBar()
            .sheet(isPresented: $showEdit) {
                EditProfileSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
            .sheet(item: $personRoute) { route in
                PersonSheet(profile: route.profile)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
            .sheet(item: $threadRoute) { route in
                ThreadSheet(post: route.post)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Me")
                .font(.display(28, weight: .black))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button {
                Haptics.tick()
                showEdit = true
            } label: {
                IconBubble(icon: "pencil", tint: Theme.mint, size: 38)
            }
            .buttonStyle(PressableStyle())
        }
    }

    // MARK: Profile card

    private var profileCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    PulseHalo(color: Theme.mint, size: 82)
                    AvatarView(emoji: me?.avatarEmoji ?? "🚽", size: 68,
                               ring: Theme.mint.opacity(0.5), glow: true)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(me?.displayName ?? "You")
                        .font(.display(21, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text("@\(me?.handle ?? "you")")
                        .font(.body(12, weight: .semibold))
                        .foregroundStyle(Theme.mint)
                    Text((me?.bio ?? "").isEmpty ? "No bio yet. Tap edit." : (me?.bio ?? ""))
                        .font(.body(11))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                StatusPill(text: me?.homeCity ?? "San Francisco",
                           color: Theme.sky, icon: "mappin.and.ellipse")
                StatusPill(text: "Level \(level)", color: Theme.tangerine, icon: "bolt.fill")
                StatusPill(text: "\(streak)d streak", color: Theme.bubble, icon: "flame.fill")
                Spacer()
            }
        }
        .glassCard(tint: Theme.mint, padding: 14)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 8) {
            StatTile(value: "\(stats.posts)", label: "Posts", tint: Theme.mint)
            StatTile(value: "\(stats.reviews)", label: "Reviews", tint: Theme.sky)
            StatTile(value: "\(stats.crew)", label: "Crew", tint: Theme.bubble)
            StatTile(value: "\(stats.bathrooms)", label: "Thrones", tint: Theme.tangerine)
        }
    }

    // MARK: Hygiene card

    private var hygieneCard: some View {
        Button {
            Haptics.tick()
            app.showHygiene = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        IconBubble(icon: "bubbles.and.sparkles.fill", tint: Theme.sky, size: 38, filled: true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Clean streak")
                                .font(.display(16, weight: .heavy))
                                .foregroundStyle(Theme.ink)
                            Text("\(collected.count) of \(HygieneTips.all.count) hygiene tips collected")
                                .font(.body(10))
                                .foregroundStyle(Theme.inkFaint)
                        }
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Text("\(streak)")
                            .font(.display(22, weight: .black))
                            .foregroundStyle(Theme.bubble)
                            .contentTransition(.numericText(value: Double(streak)))
                        Image(systemName: "flame.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.tangerine)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Level \(level)")
                            .font(.body(10, weight: .bold))
                            .foregroundStyle(Theme.sky)
                        Spacer()
                        Text("\(xp % 40)/40 XP")
                            .font(.body(10, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(Theme.hero)
                                .frame(width: max(6, geo.size.width * levelProgress))
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: levelProgress)
                        }
                    }
                    .frame(height: 7)
                }
            }
            .glassCard(tint: Theme.sky, padding: 13)
        }
        .buttonStyle(PressableStyle(scale: 0.985))
        .accessibilityIdentifier("hygieneCard")
        .accessibilityLabel("Clean streak hygiene tips")
    }

    // MARK: Badges

    private var badges: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Badges", subtitle: "Earned by actually using the app")

            let items: [BadgeItem] = [
                BadgeItem(emoji: "🚽", title: "First flush", earned: stats.posts >= 1, tint: Theme.mint),
                BadgeItem(emoji: "🤝", title: "Crew builder", earned: stats.crew >= 5, tint: Theme.bubble),
                BadgeItem(emoji: "🎯", title: "Critic", earned: stats.reviews >= 5, tint: Theme.sky),
                BadgeItem(emoji: "🏆", title: "Satisfaction", earned: stats.satisfying >= 3, tint: Theme.lime),
                BadgeItem(emoji: "🧼", title: "Soap scholar", earned: collected.count >= 6, tint: Theme.sky),
                BadgeItem(emoji: "🎭", title: "Emoji royal", earned: stats.bathrooms >= 4, tint: Theme.grape)
            ]

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                ForEach(items) { item in
                    VStack(spacing: 4) {
                        Text(item.emoji)
                            .font(.system(size: 24))
                            .grayscale(item.earned ? 0 : 1)
                            .opacity(item.earned ? 1 : 0.35)
                        Text(item.title)
                            .font(.body(9, weight: .bold))
                            .foregroundStyle(item.earned ? Theme.ink : Theme.inkFaint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(item.earned ? item.tint.opacity(0.12) : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(item.earned ? item.tint.opacity(0.35) : .clear, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: Saved

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Saved", subtitle: "\(saved.count) bookmarked")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(saved, id: \.id) { post in
                        Button {
                            threadRoute = PostRoute(post: post)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 5) {
                                    Text(post.author?.avatarEmoji ?? "🚽").font(.system(size: 14))
                                    Text("@\(post.author?.handle ?? "ghost")")
                                        .font(.body(9, weight: .bold))
                                        .foregroundStyle(Theme.inkFaint)
                                        .lineLimit(1)
                                }
                                Text(post.body.isEmpty ? post.joke : post.body)
                                    .font(.body(12, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .frame(width: 168, height: 92, alignment: .topLeading)
                            .glassCard(padding: 11, radius: Theme.rSmall)
                        }
                        .buttonStyle(PressableStyle(scale: 0.96))
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: My drops

    private var myDropsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Your drops", subtitle: "\(myDrops.count) posts")

            if myDrops.isEmpty {
                EmptyPanel(
                    icon: "🫧",
                    title: "You haven't posted yet",
                    message: "Say something. The timeline is 90% better with you in it.",
                    actionTitle: "Write a drop"
                ) {
                    app.compose(.drop)
                }
                .glassCard(padding: 4)
            } else {
                let shown = Array(myDrops.prefix(8))
                ForEach(shown.indices, id: \.self) { index in
                    let post = shown[index]
                    PostCard(
                        post: post,
                        me: me,
                        onOpenThread: { threadRoute = PostRoute(post: post) }
                    )
                    .popIn(min(index, 5))
                }
            }
        }
    }
}
