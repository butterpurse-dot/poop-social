import SwiftUI
import SwiftData

@MainActor
struct PersonSheet: View {

    let profile: Profile

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [Profile]

    @State private var burst = 0

    private var me: Profile? { profiles.first { $0.isMe } }
    private var isMe: Bool { profile.isMe || profile.id == me?.id }

    private var state: LinkState {
        guard let me, !isMe else { return .none }
        return me.state(towards: profile)
    }

    private var closeness: Closeness {
        guard let me else { return .acquaintance }
        return me.closeness(to: profile) ?? .acquaintance
    }

    private var posts: [Post] {
        profile.posts
            .filter { !$0.isReply && $0.surface == .drop }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var reviews: [Review] {
        profile.reviews.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            BubbleBackdrop(tint: profile.isMe ? Theme.mint : Theme.grape,
                           secondary: Theme.bubble, count: 4)

            ScrollView {
                VStack(spacing: 14) {
                    topBar
                    identity
                    if !isMe { relationControls }
                    stats
                    if !posts.isEmpty { postsSection }
                    if !reviews.isEmpty { reviewsSection }
                    if isMe { safetyCard }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .center) {
            EmojiBurst(emojis: ["🤝", "✨", "💖", "🚽"], trigger: burst)
                .allowsHitTesting(false)
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Text(profile.isMe ? "Your profile" : "Profile")
                .font(.body(12, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.inkDim)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(PressableStyle(scale: 0.9))
        }
        .padding(.top, 14)
    }

    // MARK: Identity

    private var identity: some View {
        VStack(spacing: 10) {
            ZStack {
                PulseHalo(color: profile.isMe ? Theme.mint : Theme.grape, size: 108)
                AvatarView(
                    emoji: profile.avatarEmoji,
                    size: 92,
                    ring: (isMe ? Theme.mint : Theme.grape).opacity(0.55),
                    glow: true
                )
            }

            Text(profile.displayName)
                .font(.display(25, weight: .black))
                .foregroundStyle(Theme.ink)

            Text("@\(profile.handle)")
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Theme.mint)

            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(.body(13))
                    .foregroundStyle(Theme.inkDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 8) {
                StatusPill(text: profile.homeCity, color: Theme.sky, icon: "mappin.and.ellipse")
                if isMe {
                    StatusPill(text: "That's you", color: Theme.mint, icon: "checkmark.seal.fill", filled: true)
                } else if state == .linked {
                    StatusPill(text: closeness.label, color: closeness.tint,
                               icon: closeness.emoji, filled: true)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Relationship

    private var relationControls: some View {
        VStack(spacing: 10) {
            if state == .linked {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How close?")
                        .font(.body(11, weight: .heavy))
                        .foregroundStyle(Theme.inkFaint)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    HStack(spacing: 7) {
                        ForEach(Closeness.allCases.reversed(), id: \.self) { tier in
                            Button {
                                store.setCloseness(tier, for: profile)
                                burst += 1
                                Haptics.success()
                                app.show(Toast(emoji: tier.emoji, title: "\(profile.displayName) is now \(tier.label.lowercased())",
                                               detail: nil))
                            } label: {
                                VStack(spacing: 3) {
                                    Text(tier.emoji).font(.system(size: 17))
                                    Text(tier.label)
                                        .font(.body(10, weight: .bold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .foregroundStyle(closeness == tier ? Theme.night : Theme.inkDim)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            closeness == tier
                                            ? AnyShapeStyle(tier.tint)
                                            : AnyShapeStyle(Color.white.opacity(0.05))
                                        )
                                )
                            }
                            .buttonStyle(PressableStyle(scale: 0.93))
                        }
                    }
                }
                .glassCard(padding: 12)

                Button {
                    store.toggleConnection(with: profile)
                    Haptics.warn()
                    app.show(Toast(emoji: "👋", title: "Removed", detail: "\(profile.displayName) left your crew."))
                } label: {
                    Text("Remove from crew")
                        .font(.body(12, weight: .bold))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            Capsule().fill(Theme.danger.opacity(0.10))
                        )
                }
                .buttonStyle(PressableStyle(scale: 0.97))
            } else {
                GlowButton(
                    title: state == .outgoing ? "Request pending" : "Add to crew",
                    icon: state == .outgoing ? "clock" : "person.badge.plus",
                    gradient: Theme.juicy,
                    enabled: state != .outgoing
                ) {
                    store.toggleConnection(with: profile)
                    burst += 1
                    Haptics.success()
                    app.show(Toast(emoji: "🤝", title: "Request sent",
                                   detail: "\(profile.displayName) starts as an acquaintance."))
                }
            }
        }
    }

    // MARK: Stats

    private var stats: some View {
        HStack(spacing: 8) {
            StatTile(value: "\(posts.count)", label: "Drops", tint: Theme.mint)
            StatTile(value: "\(reviews.count)", label: "Reviews", tint: Theme.sky)
            StatTile(value: "\(profile.linkedPeople().count)", label: "Crew", tint: Theme.bubble)
            StatTile(value: "\(reviews.filter { $0.verdict == .satisfying }.count)",
                     label: "Satisfying", tint: Theme.lime)
        }
    }

    // MARK: Posts

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Recent drops", subtitle: "\(posts.count) posts")
            let shown = Array(posts.prefix(6))
            ForEach(shown.indices, id: \.self) { index in
                PostCard(post: shown[index], me: me)
                    .popIn(index)
            }
        }
    }

    // MARK: Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Recent reviews", subtitle: "\(reviews.count) thrones rated")
            let shown = Array(reviews.prefix(5))
            ForEach(shown.indices, id: \.self) { index in
                let review = shown[index]
                HStack(spacing: 10) {
                    Text(review.mood.emoji).font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.bathroom?.name ?? "A mystery bathroom")
                            .font(.body(13, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(review.note.isEmpty ? review.verdict.label : review.note)
                            .font(.body(11))
                            .foregroundStyle(Theme.inkFaint)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text("\(review.cleanliness)/5")
                        .font(.body(11, weight: .bold))
                        .foregroundStyle(Theme.mint)
                }
                .glassCard(padding: 11)
                .popIn(index)
            }
        }
    }

    // MARK: Safety

    private var safetyCard: some View {
        HStack(alignment: .top, spacing: 10) {
            IconBubble(icon: "camera.fill", tint: Theme.mint, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("Your content policy")
                    .font(.body(13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Poop Social has no photo or video upload. Everything you post here is text, emoji and one-liners.")
                    .font(.body(11))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .glassCard(padding: 12)
    }
}
