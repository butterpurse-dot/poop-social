import SwiftUI
import SwiftData

@MainActor
struct BathroomDetailScreen: View {

    let bathroom: Bathroom

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [Profile]

    @State private var composerRequest: ComposerRequest?
    @State private var burst = 0

    private var me: Profile? { profiles.first { $0.isMe } }
    private var crew: [Profile] { me?.linkedPeople() ?? [] }

    private var reviews: [Review] {
        bathroom.reviews.sorted { $0.createdAt > $1.createdAt }
    }

    private var crewVisits: [Profile] {
        let crewIDs = Set(crew.map(\.id))
        let authors = reviews.compactMap { $0.author }.filter { crewIDs.contains($0.id) }
        var seen = Set<UUID>()
        return authors.filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            BubbleBackdrop(tint: Theme.mint, secondary: Theme.sky, count: 4)

            ScrollView {
                VStack(spacing: 14) {
                    hero
                    scoreRow
                    amenities
                    crewRow
                    actions
                    reviewSection
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.ultraThickMaterial))
                    }
                    .buttonStyle(PressableStyle(scale: 0.9))
                }
                Spacer()
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 10)
        }
        .overlay(alignment: .center) {
            EmojiBurst(emojis: ["✨", "🚽", "💯", "🫧"], trigger: burst)
                .allowsHitTesting(false)
        }
        .sheet(item: $composerRequest) { request in
            ComposerSheet(request: request)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: bathroom.kind.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(bathroom.kind.label)
                        .font(.body(11, weight: .bold))
                }
                .foregroundStyle(Theme.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.mint.opacity(0.14)))

                Spacer()

                Text(bathroom.cleanLabel)
                    .font(.body(10, weight: .heavy))
                    .foregroundStyle(Theme.night)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.mint))
            }

            Text(bathroom.name)
                .font(.display(28, weight: .black))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 10, weight: .bold))
                Text(bathroom.address)
                    .font(.body(12))
                    .lineLimit(2)
            }
            .foregroundStyle(Theme.inkFaint)

            HStack(spacing: 6) {
                Text("Added by \(bathroom.addedByName)")
                    .font(.body(10, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                Text("·")
                    .foregroundStyle(Theme.inkFaint)
                Text("\(bathroom.reviewCount) reviews")
                    .font(.body(10, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .glassCard(tint: Theme.mint, padding: 16)
    }

    // MARK: Scores

    private var scoreRow: some View {
        HStack(spacing: 12) {
            ScoreRing(
                value: bathroom.experienceScore,
                size: 78,
                lineWidth: 8,
                gradient: Theme.hero,
                caption: "vibe"
            )

            VStack(spacing: 8) {
                scoreBar("Cleanliness", bathroom.cleanlinessScore / 5, Theme.mint)
                scoreBar("Satisfying", satisfactionRatio, Theme.bubble)
                scoreBar("Wait", waitScore, Theme.tangerine)
            }
            .frame(maxWidth: .infinity)
        }
        .glassCard(padding: 14)
    }

    private var satisfactionRatio: Double {
        guard bathroom.reviewCount > 0 else { return 0 }
        return Double(bathroom.satisfyingCount) / Double(bathroom.reviewCount)
    }

    private var waitScore: Double {
        let waits = bathroom.reviews.map { Double($0.waitMinutes) }
        guard !waits.isEmpty else { return 0 }
        let avg = waits.reduce(0, +) / Double(waits.count)
        return max(0, min(1, 1 - avg / 20))
    }

    private func scoreBar(_ label: String, _ value: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.body(10, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.body(10, weight: .bold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(value: value))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(4, geo.size.width * value))
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: Amenities

    private var amenities: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("What's inside")
                .font(.display(16, weight: .heavy))
                .foregroundStyle(Theme.ink)

            if bathroom.amenities.isEmpty {
                Text("Nobody has reported amenities yet.")
                    .font(.body(12))
                    .foregroundStyle(Theme.inkFaint)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 108), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(bathroom.amenities.sorted { $0.rawValue < $1.rawValue }) { amenity in
                        HStack(spacing: 6) {
                            Image(systemName: amenity.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.mint)
                            Text(amenity.label)
                                .font(.body(11, weight: .semibold))
                                .foregroundStyle(Theme.inkDim)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
            }
        }
        .glassCard(padding: 14)
    }

    // MARK: Crew

    @ViewBuilder
    private var crewRow: some View {
        if !crewVisits.isEmpty {
            HStack(spacing: 10) {
                HStack(spacing: -8) {
                    ForEach(crewVisits.prefix(4), id: \.id) { person in
                        AvatarView(emoji: person.avatarEmoji, size: 30, ring: Theme.night)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(crewVisits.count) of your crew have been here")
                        .font(.body(12, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(crewVisits.prefix(3).map(\.displayName).joined(separator: ", "))
                        .font(.body(10))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
                Spacer()
            }
            .glassCard(padding: 12)
        }
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: 10) {
            GlowButton(title: "Rate this throne", icon: "star.fill") {
                burst += 1
                composerRequest = ComposerRequest(mode: .review, bathroom: bathroom)
            }

            Button {
                Haptics.tick()
                composerRequest = ComposerRequest(mode: .drop, bathroom: bathroom)
            } label: {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.mint)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Theme.mint.opacity(0.14)))
                    .overlay(Circle().strokeBorder(Theme.mint.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(PressableStyle(scale: 0.9))
        }
    }

    // MARK: Reviews

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("The verdict")
                    .font(.display(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(reviews.count)")
                    .font(.body(12, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }

            if reviews.isEmpty {
                EmptyPanel(
                    icon: "🫧",
                    title: "No reviews yet",
                    message: "Be the first to report on this throne. Your crew is counting on you.",
                    actionTitle: "Write the first review"
                ) {
                    composerRequest = ComposerRequest(mode: .review, bathroom: bathroom)
                }
                .glassCard(padding: 4)
            } else {
                ForEach(reviews, id: \.id) { review in
                    ReviewRow(review: review)
                }
            }
        }
    }
}

// MARK: - Review row

@MainActor
private struct ReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                AvatarView(emoji: review.author?.avatarEmoji ?? "🚽", size: 34,
                           ring: review.verdict.tint.opacity(0.5))
                VStack(alignment: .leading, spacing: 1) {
                    Text(review.author?.displayName ?? "Someone")
                        .font(.body(13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("@\(review.author?.handle ?? "ghost") · \(Format.ago(review.createdAt))")
                        .font(.body(10))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                Text(review.mood.emoji)
                    .font(.system(size: 22))
                Text(review.verdict.label)
                    .font(.body(9, weight: .heavy))
                    .foregroundStyle(review.verdict.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(review.verdict.tint.opacity(0.15)))
            }

            if !review.note.isEmpty {
                Text(review.note)
                    .font(.body(13))
                    .foregroundStyle(Theme.ink.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !review.joke.isEmpty {
                Text("“\(review.joke)”")
                    .font(.body(12, weight: .semibold))
                    .italic()
                    .foregroundStyle(Theme.grape)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                metric("sparkles", "\(review.cleanliness)/5 clean", Theme.mint)
                metric("clock", Format.wait(review.waitMinutes), Theme.tangerine)
                Spacer()
                if !review.emoji.isEmpty {
                    Text(review.emoji).font(.system(size: 15))
                }
            }
        }
        .glassCard(padding: 13)
    }

    private func metric(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.body(10, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
    }
}
