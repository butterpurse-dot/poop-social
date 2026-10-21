import SwiftUI
import SwiftData

enum FeedScope: String, CaseIterable, Identifiable {
    case forYou
    case following

    var id: String { rawValue }
    var label: String {
        switch self {
        case .forYou:   return "For You"
        case .following: return "Following"
        }
    }
}

@MainActor
struct HomeScreen: View {

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store

    @Query(sort: \Post.createdAt, order: .reverse) private var posts: [Post]
    @Query private var profiles: [Profile]
    @Query(sort: \Bathroom.createdAt, order: .reverse) private var bathrooms: [Bathroom]

    @State private var scope: FeedScope = .forYou
    @State private var personRoute: PersonRoute?
    @State private var bathroomRoute: BathroomRoute?
    @State private var threadRoute: PostRoute?

    @Namespace private var scopeNS

    private var me: Profile? { profiles.first { $0.isMe } }
    private var crew: [Profile] { me?.linkedPeople() ?? [] }

    private var replyCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for post in posts {
            if let parent = post.parentID { counts[parent, default: 0] += 1 }
        }
        return counts
    }

    private var feedPosts: [Post] {
        let base = posts.filter { $0.surface == .drop && !$0.isReply }
        switch scope {
        case .forYou:
            return base
        case .following:
            let ids = Set(crew.map(\.id))
            return base.filter { post in
                guard let author = post.author else { return false }
                return author.isMe || ids.contains(author.id)
            }
        }
    }

    private var trending: [Bathroom] {
        bathrooms
            .filter { $0.reviewCount > 0 }
            .sorted { $0.experienceScore > $1.experienceScore }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                BubbleBackdrop(tint: Theme.mint, secondary: Theme.grape)

                ScrollView {
                    LazyVStack(spacing: 14) {
                        header
                        crewStrip
                        scopePicker
                        if !app.hasSeenHygieneTip { dailyTip }
                        trendingRail
                        feed
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    Haptics.success()
                    app.show(Toast(emoji: "✅", title: "All caught up",
                                   detail: "The timeline is fresh."))
                }
            }
            .hidesNavigationBar()
            .sheet(item: $personRoute) { route in
                PersonSheet(profile: route.profile)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
            .sheet(item: $bathroomRoute) { route in
                BathroomDetailScreen(bathroom: route.bathroom)
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
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Poop Social")
                    .font(.display(27, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.mint, Theme.sky, Theme.bubble],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .neon(Theme.mint, radius: 14, intensity: 0.3)

                HStack(spacing: 6) {
                    LiveDot(color: Theme.mint)
                    Text("\(crew.count) in your crew")
                        .font(.body(11, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                    Text("·")
                        .foregroundStyle(Theme.inkFaint)
                    Text("0 photos, ever")
                        .font(.body(11, weight: .semibold))
                        .foregroundStyle(Theme.mint.opacity(0.85))
                }
            }

            Spacer()

            Button { Haptics.tick(); app.showHygiene = true } label: {
                IconBubble(icon: "sparkles", tint: Theme.tangerine, size: 38)
            }
            .buttonStyle(PressableStyle())

            Button { Haptics.pop(); app.compose(.drop) } label: {
                IconBubble(icon: "plus", tint: Theme.mint, size: 38, filled: true)
            }
            .buttonStyle(PressableStyle())
            .neon(Theme.mint, radius: 14, intensity: 0.45)
            .accessibilityIdentifier("composeButton")
            .accessibilityLabel("Write a drop")
        }
    }

    // MARK: Crew strip

    private var crewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 13) {
                Button {
                    Haptics.pop()
                    app.compose(.drop)
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .strokeBorder(Theme.mint.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                                .frame(width: 62, height: 62)
                            Image(systemName: "plus")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(Theme.mint)
                        }
                        Text("Post")
                            .font(.body(10, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                .buttonStyle(PressableStyle(scale: 0.9))

                ForEach(crew, id: \.id) { person in
                    Button {
                        Haptics.tick()
                        personRoute = PersonRoute(profile: person)
                    } label: {
                        VStack(spacing: 5) {
                            RingedAvatar(
                                emoji: person.avatarEmoji,
                                seen: false,
                                gradient: LinearGradient(
                                    colors: [Theme.mint, Theme.sky],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            Text(person.displayName.components(separatedBy: " ").first ?? person.displayName)
                                .font(.body(10, weight: .semibold))
                                .foregroundStyle(Theme.inkDim)
                                .lineLimit(1)
                                .frame(width: 66)
                        }
                    }
                    .buttonStyle(PressableStyle(scale: 0.92))
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    // MARK: Scope picker

    private var scopePicker: some View {
        HStack(spacing: 0) {
            ForEach(FeedScope.allCases) { option in
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                        scope = option
                    }
                } label: {
                    Text(option.label)
                        .font(.body(13, weight: .bold))
                        .foregroundStyle(scope == option ? Theme.night : Theme.inkDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if scope == option {
                                Capsule()
                                    .fill(Theme.mint)
                                    .matchedGeometryEffect(id: "scopePill", in: scopeNS)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: Daily tip

    private var dailyTip: some View {
        let tip = HygieneTips.tipOfTheDay()
        return Button {
            Haptics.tick()
            app.showHygiene = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.sky.opacity(0.16))
                        .frame(width: 48, height: 48)
                    Image(systemName: tip.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.sky)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY'S HYGIENE PSA")
                        .font(.body(9, weight: .heavy))
                        .foregroundStyle(Theme.sky)
                        .tracking(0.8)
                    Text(tip.title)
                        .font(.body(14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(tip.blurb)
                        .font(.body(11))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .glassCard(tint: Theme.sky, padding: 12)
        }
        .buttonStyle(PressableStyle(scale: 0.985))
    }

    // MARK: Trending

    @ViewBuilder
    private var trendingRail: some View {
        if !trending.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Trending thrones")
                        .font(.display(16, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button {
                        Haptics.tick()
                        app.tab = .find
                    } label: {
                        Text("Map")
                            .font(.body(12, weight: .bold))
                            .foregroundStyle(Theme.mint)
                    }
                    .buttonStyle(PressableStyle())
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(trending, id: \.id) { bathroom in
                            Button {
                                Haptics.tick()
                                bathroomRoute = BathroomRoute(bathroom: bathroom)
                            } label: {
                                trendingCard(bathroom)
                            }
                            .buttonStyle(PressableStyle(scale: 0.96))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            }
        }
    }

    private func trendingCard(_ bathroom: Bathroom) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: bathroom.kind.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.mint)
                Spacer()
                Text(bathroom.cleanLabel)
                    .font(.body(9, weight: .heavy))
                    .foregroundStyle(Theme.night)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.mint))
            }

            Text(bathroom.name)
                .font(.body(13, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .frame(height: 32, alignment: .topLeading)

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.tangerine)
                Text(bathroom.experienceScore > 0 ? String(format: "%.1f", bathroom.experienceScore) : "—")
                    .font(.body(11, weight: .bold))
                    .foregroundStyle(Theme.inkDim)
                Text("· \(bathroom.reviewCount) reviews")
                    .font(.body(10))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(width: 158, alignment: .leading)
        .glassCard(padding: 12, radius: Theme.rSmall)
    }

    // MARK: Feed

    @ViewBuilder
    private var feed: some View {
        if feedPosts.isEmpty {
            EmptyPanel(
                icon: "🫧",
                title: "Nothing here yet",
                message: "Follow some crew or drop the first post. The timeline is yours.",
                actionTitle: "Write a drop"
            ) {
                app.compose(.drop)
            }
        } else {
            let shown = feedPosts
            ForEach(shown.indices, id: \.self) { index in
                let post = shown[index]
                PostCard(
                    post: post,
                    me: me,
                    replyCount: replyCounts[post.id] ?? 0,
                    onOpenThread: { threadRoute = PostRoute(post: post) },
                    onOpenAuthor: {
                        if let author = post.author {
                            personRoute = PersonRoute(profile: author)
                        }
                    },
                    onOpenBathroom: {
                        if let bathroom = post.bathroom {
                            bathroomRoute = BathroomRoute(bathroom: bathroom)
                        }
                    }
                )
                .popIn(min(index, 6))
            }
        }
    }
}
