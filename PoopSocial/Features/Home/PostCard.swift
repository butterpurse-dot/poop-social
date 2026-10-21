import SwiftUI

/// A single emoji plus how many people used it. A real type, so `ForEach`
/// doesn't need a tuple key path.
private struct ReactionTally: Identifiable {
    let emoji: String
    let count: Int
    var id: String { emoji }
}

@MainActor
struct PostCard: View {

    let post: Post
    let me: Profile?
    var replyCount: Int = 0
    var onOpenThread: (() -> Void)? = nil
    var onOpenAuthor: (() -> Void)? = nil
    var onOpenBathroom: (() -> Void)? = nil

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store

    @State private var showPicker = false
    @State private var burst = 0

    private let quickEmoji = ["🔥", "💯", "😭", "🚽", "✨"]

    private var author: Profile? { post.author }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header

            if !post.body.isEmpty {
                Text(post.body)
                    .font(.body(15))
                    .foregroundStyle(Theme.ink.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { react("🔥") }
            }

            if !post.joke.isEmpty {
                jokeBlock
            }

            if let bathroom = post.bathroom {
                bathroomChip(bathroom)
            }

            reactionSummary
            actions
        }
        .glassCard(padding: 14)
        .overlay(alignment: .center) {
            EmojiBurst(emojis: ["🔥", "💯", "✨", "🚽", "💖", "👏"], trigger: burst)
                .allowsHitTesting(false)
                .frame(height: 220)
        }
        .contextMenu {
            if let author {
                Button {
                    onOpenAuthor?()
                } label: {
                    Label("View @\(author.handle)", systemImage: "person.crop.circle")
                }
            }
            Button {
                toggleBookmark()
            } label: {
                Label(store.hasBookmarked(post, by: me) ? "Remove bookmark" : "Save", systemImage: "bookmark")
            }
            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            if post.author?.id == me?.id {
                Button(role: .destructive) {
                    store.delete(post)
                    app.show(Toast(emoji: "🗑️", title: "Dropped", detail: "That post is gone."))
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                onOpenAuthor?()
            } label: {
                AvatarView(emoji: author?.avatarEmoji ?? "🚽", size: 40,
                           ring: post.verdict.tint.opacity(0.55),
                           glow: post.verdict == .satisfying)
            }
            .buttonStyle(PressableStyle(scale: 0.92))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(author?.displayName ?? "Someone")
                        .font(.body(14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if post.verdict != .neutral {
                        Text(post.verdict.emoji).font(.system(size: 10))
                    }
                }
                Text("@\(author?.handle ?? "ghost") · \(Format.ago(post.createdAt))")
                    .font(.body(11, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            StatusPill(text: post.verdict.label, color: post.verdict.tint)
        }
    }

    // MARK: Joke

    private var jokeBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(post.verdict.tint)
                .frame(width: 3)

            Text(post.joke)
                .font(.body(14, weight: .semibold))
                .italic()
                .foregroundStyle(Theme.ink.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(post.verdict.tint.opacity(0.07))
        )
    }

    // MARK: Bathroom chip

    private func bathroomChip(_ bathroom: Bathroom) -> some View {
        Button {
            onOpenBathroom?()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: bathroom.kind.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.mint)
                Text(bathroom.name)
                    .font(.body(12, weight: .semibold))
                    .foregroundStyle(Theme.inkDim)
                    .lineLimit(1)
                Text("·")
                    .foregroundStyle(Theme.inkFaint)
                Text(bathroom.cleanLabel)
                    .font(.body(11, weight: .bold))
                    .foregroundStyle(Theme.mint)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    // MARK: Reactions summary

    @ViewBuilder
    private var reactionSummary: some View {
        let tallies = Dictionary(grouping: post.reactions, by: \.emoji)
            .map { ReactionTally(emoji: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        if !tallies.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(tallies.prefix(4))) { tally in
                    Button {
                        react(tally.emoji)
                    } label: {
                        HStack(spacing: 3) {
                            Text(tally.emoji).font(.system(size: 12))
                            AnimatedNumber(value: tally.count, font: .body(11, weight: .bold),
                                           color: Theme.inkDim)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(
                                store.hasReacted(tally.emoji, on: post, by: me)
                                ? Theme.mint.opacity(0.18)
                                : Color.white.opacity(0.06)
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                store.hasReacted(tally.emoji, on: post, by: me)
                                ? Theme.mint.opacity(0.5)
                                : .clear,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(PressableStyle(scale: 0.92))
                }
                Spacer(minLength: 0)
            }
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }

        if showPicker {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(quickEmoji, id: \.self) { emoji in
                        Button {
                            react(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 21))
                                .frame(minWidth: 44, minHeight: 44)
                                .background(Circle().fill(Color.white.opacity(0.07)))
                        }
                        .accessibilityLabel("React \(emoji)")
                        .buttonStyle(PressableStyle(scale: 0.85))
                    }
                }
                .padding(.vertical, 2)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: 4) {
            actionButton("bubble.left", count: replyCount, tint: Theme.sky) {
                onOpenThread?()
            }
            .accessibilityLabel("Reply to post")
            actionButton("arrow.2.squarepath", count: post.reposts.count,
                         tint: store.hasReposted(post, by: me) ? Theme.mint : Theme.inkDim) {
                let added = store.toggleRepost(post, by: me)
                if added { app.show(Toast(emoji: "🔁", title: "Reposted", detail: "Your crew will see it.")) }
            }
            .accessibilityLabel("Repost")
            actionButton(showPicker ? "face.smiling.fill" : "face.smiling",
                         count: post.totalReactions, tint: Theme.bubble) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    showPicker.toggle()
                }
            }
            .accessibilityLabel("React")
            actionButton(store.hasBookmarked(post, by: me) ? "bookmark.fill" : "bookmark",
                         count: nil,
                         tint: store.hasBookmarked(post, by: me) ? Theme.tangerine : Theme.inkDim) {
                toggleBookmark()
            }

            Spacer(minLength: 0)

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkDim)
                    .frame(width: 34, height: 30)
            }
        }
    }

    @ViewBuilder
    private func actionButton(_ icon: String, count: Int?, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                if let count, count > 0 {
                    Text(Format.compact(count))
                        .font(.body(11, weight: .bold))
                        .contentTransition(.numericText(value: Double(count)))
                }
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.white.opacity(0.04)))
        }
        .buttonStyle(PressableStyle(scale: 0.92))
    }

    // MARK: Actions

    private func react(_ emoji: String) {
        guard let me else { return }
        let added = store.toggleReaction(emoji, on: post, by: me)
        if added {
            burst += 1
            Haptics.pop()
        }
    }

    private func toggleBookmark() {
        let saved = store.toggleBookmark(post, by: me)
        app.show(Toast(emoji: saved ? "🔖" : "🗑️",
                       title: saved ? "Saved" : "Removed",
                       detail: saved ? "Find it in your saves." : nil))
    }

    private var shareText: String {
        var parts = [post.body, post.joke].filter { !$0.isEmpty }
        if let name = post.bathroom?.name { parts.append("📍 \(name)") }
        parts.append("— on Poop Social")
        return parts.joined(separator: "\n")
    }
}
