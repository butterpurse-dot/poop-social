import SwiftUI

// MARK: - Avatars
@MainActor
struct AvatarView: View {
    let emoji: String
    var size: CGFloat = 44
    var ring: Color = .white.opacity(0.18)
    var glow: Bool = false

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.46))
            .frame(width: size, height: size)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [Theme.slate, Theme.nightSoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(Circle().strokeBorder(ring, lineWidth: 1.6))
            .shadow(color: glow ? Theme.mint.opacity(0.45) : .clear, radius: 12)
    }
}

/// Avatar with a story-style gradient ring (used in the crew strip).
@MainActor
struct RingedAvatar: View {
    let emoji: String
    var size: CGFloat = 62
    var seen: Bool = false
    var gradient: LinearGradient = Theme.juicy

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    seen ? AnyShapeStyle(Color.white.opacity(0.12)) : AnyShapeStyle(gradient),
                    lineWidth: 2.5
                )
                .frame(width: size, height: size)
            AvatarView(emoji: emoji, size: size - 10, ring: Theme.night.opacity(0.6))
        }
    }
}

// MARK: - Chips & pills
/// A pill-shaped toggle. The closure receives the chip's own title, which makes
/// it directly usable as a trailing closure inside a `ForEach` of options.
@MainActor
struct Chip: View {
    let title: String
    var icon: String? = nil
    var selected: Bool = false
    var tint: Color = Theme.mint
    let onPick: (String) -> Void

    init(
        title: String,
        icon: String? = nil,
        selected: Bool = false,
        tint: Color = Theme.mint,
        onPick: @escaping (String) -> Void
    ) {
        self.title = title
        self.icon = icon
        self.selected = selected
        self.tint = tint
        self.onPick = onPick
    }

    var body: some View {
        Button(action: {
            Haptics.select()
            onPick(title)
        }) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 11, weight: .bold))
                }
                Text(title).font(.body(13, weight: .semibold))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? Theme.night : Theme.inkDim)
            .background(
                Capsule().fill(
                    selected
                    ? AnyShapeStyle(tint)
                    : AnyShapeStyle(Color.white.opacity(0.07))
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    selected ? .clear : Color.white.opacity(0.10),
                    lineWidth: 1
                )
            )
            .scaleEffect(selected ? 1.03 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: selected)
        }
        .buttonStyle(PressableStyle())
    }
}

@MainActor
struct StatusPill: View {
    let text: String
    var color: Color = Theme.mint
    var icon: String? = nil
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
            }
            Text(text).font(.body(11, weight: .bold))
        }
        .foregroundStyle(filled ? Theme.night : color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(filled ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.16)))
        )
    }
}

// MARK: - Buttons
@MainActor
struct GlowButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient = Theme.hero
    var fullWidth: Bool = true
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard enabled else { Haptics.warn(); return }
            Haptics.pop()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .bold))
                }
                Text(title).font(.display(16, weight: .heavy))
            }
            .foregroundStyle(Theme.night)
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                Capsule().fill(gradient)
            )
            .opacity(enabled ? 1 : 0.4)
            .neon(enabled ? Theme.mint : .clear, radius: 18, intensity: 0.35)
        }
        .buttonStyle(PressableStyle(scale: 0.965))
        .disabled(!enabled)
    }
}

@MainActor
struct GhostButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Theme.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                }
                Text(title).font(.body(14, weight: .semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Icon bubble
@MainActor
struct IconBubble: View {
    let icon: String
    var tint: Color = Theme.mint
    var size: CGFloat = 40
    var filled: Bool = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(filled ? Theme.night : tint)
            .frame(width: size, height: size)
            .background(
                Circle().fill(
                    filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14))
                )
            )
    }
}

// MARK: - Section header
@MainActor
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.display(19, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.body(12))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            Spacer()
            if let trailing, let action {
                Button(action: action) {
                    Text(trailing)
                        .font(.body(13, weight: .bold))
                        .foregroundStyle(Theme.mint)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

// MARK: - Score ring
@MainActor
struct ScoreRing: View {
    let value: Double          // 0...5
    var size: CGFloat = 64
    var lineWidth: CGFloat = 7
    var gradient: LinearGradient = Theme.hero
    var caption: String? = nil

    private var progress: Double { max(0, min(1, value / 5)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.09), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
            VStack(spacing: -1) {
                Text(value <= 0 ? "—" : String(format: "%.1f", value))
                    .font(.display(size * 0.28, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if let caption {
                    Text(caption)
                        .font(.body(8, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .textCase(.uppercase)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Stat
@MainActor
struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = Theme.mint

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.display(20, weight: .heavy))
                .foregroundStyle(tint)
            Text(label)
                .font(.body(10, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Emoji pad
@MainActor
struct EmojiPad: View {
    let selected: String?
    var columns: Int = 6
    /// Receives the chosen emoji.
    let onPick: (String) -> Void

    private let emojis = LocalModerator.approvedEmoji

    init(selected: String?, columns: Int = 6, onPick: @escaping (String) -> Void) {
        self.selected = selected
        self.columns = columns
        self.onPick = onPick
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns),
            spacing: 8
        ) {
            ForEach(emojis, id: \.self) { emoji in
                Button {
                    Haptics.tick()
                    onPick(emoji)
                } label: {
                    Text(emoji)
                        .font(.system(size: 24))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected == emoji ? Theme.mint.opacity(0.22) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    selected == emoji ? Theme.mint : .clear,
                                    lineWidth: 1.5
                                )
                        )
                        .scaleEffect(selected == emoji ? 1.08 : 1)
                        .animation(.spring(response: 0.26, dampingFraction: 0.55), value: selected)
                }
                .buttonStyle(PressableStyle(scale: 0.9))
            }
        }
    }
}

// MARK: - Empty state
@MainActor
struct EmptyPanel: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 44))
                .padding(.bottom, 2)
            Text(title)
                .font(.display(18, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.body(13))
                .foregroundStyle(Theme.inkDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                GhostButton(title: actionTitle, icon: "plus", action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 24)
    }
}

// MARK: - Toast
@MainActor
struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Text(toast.emoji).font(.system(size: 20))
            VStack(alignment: .leading, spacing: 1) {
                Text(toast.title)
                    .font(.body(13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                if let detail = toast.detail {
                    Text(detail)
                        .font(.body(11))
                        .foregroundStyle(Theme.inkDim)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.mint.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
        .padding(.horizontal, 20)
    }
}
