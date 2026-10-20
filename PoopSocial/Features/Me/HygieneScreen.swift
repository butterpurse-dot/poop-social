import SwiftUI

@MainActor
struct HygieneScreen: View {

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @AppStorage("poopSocial.tipsCollected") private var collectedRaw = ""
    @AppStorage("poopSocial.streak") private var streak = 1
    @AppStorage("poopSocial.lastOpen") private var lastOpenStamp = 0.0

    @State private var expandedID: String?
    @State private var burst = 0
    @State private var didRegister = false

    private var collected: Set<String> {
        Set(collectedRaw.split(separator: ",").map(String.init))
    }

    private var xp: Int {
        HygieneTips.all.filter { collected.contains($0.id) }.reduce(0) { $0 + $1.xp }
    }

    private var level: Int { xp / 40 + 1 }
    private var levelProgress: Double { Double(xp % 40) / 40.0 }

    private var today: HygieneTip { HygieneTips.tipOfTheDay() }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            BubbleBackdrop(tint: Theme.sky, secondary: Theme.mint, count: 5)

            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    header
                    hero
                    progressCard
                    tipsList
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 34)
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .center) {
            EmojiBurst(emojis: ["🧼", "🫧", "✨", "💯", "🚿"], trigger: burst)
                .allowsHitTesting(false)
        }
        .onAppear(perform: registerDay)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hygiene, but fun")
                    .font(.display(24, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Real habits. Ridiculous delivery.")
                    .font(.body(11))
                    .foregroundStyle(Theme.inkFaint)
            }
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
        .padding(.top, 10)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("TODAY'S PSA")
                        .font(.body(9, weight: .heavy))
                        .tracking(0.9)
                }
                .foregroundStyle(Theme.sky)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                    Text("\(streak) day streak")
                        .font(.body(10, weight: .bold))
                }
                .foregroundStyle(Theme.tangerine)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.tangerine.opacity(0.14)))
            }

            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.sky.opacity(0.16))
                        .frame(width: 62, height: 62)
                    Image(systemName: today.icon)
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(Theme.sky)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(today.title)
                        .font(.display(19, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(today.blurb)
                        .font(.body(12))
                        .foregroundStyle(Theme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 7) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tangerine)
                Text(today.funFact)
                    .font(.body(11, weight: .medium))
                    .foregroundStyle(Theme.inkDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.tangerine.opacity(0.08))
            )

            HStack(spacing: 10) {
                GlowButton(title: collected.contains(today.id) ? "Collected" : "Collect +\(today.xp) XP",
                           icon: collected.contains(today.id) ? "checkmark" : "plus",
                           gradient: Theme.hero) {
                    collect(today)
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        expandedID = today.id
                    }
                } label: {
                    Text("Read steps")
                        .font(.body(12, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(PressableStyle(scale: 0.95))
            }
        }
        .glassCard(tint: Theme.sky, padding: 15)
    }

    // MARK: Progress

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Level \(level)")
                    .font(.display(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(collected.count)/\(HygieneTips.all.count) tips · \(xp) XP")
                    .font(.body(10, weight: .bold))
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
            .frame(height: 8)

            Text(levelProgress >= 0.99 ? "Next level unlocked. Go wash your hands." : "Collect tips to level up.")
                .font(.body(10))
                .foregroundStyle(Theme.inkFaint)
        }
        .glassCard(padding: 13)
    }

    // MARK: Tips

    private var tipsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "The full playbook", subtitle: "\(HygieneTips.all.count) habits, zero lectures")

            ForEach(HygieneTips.all) { tip in
                tipCard(tip)
            }
        }
    }

    private func tipCard(_ tip: HygieneTip) -> some View {
        let isOpen = expandedID == tip.id
        let isCollected = collected.contains(tip.id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.tick()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    expandedID = isOpen ? nil : tip.id
                }
            } label: {
                HStack(spacing: 11) {
                    ZStack {
                        Circle()
                            .fill(Theme.mint.opacity(0.14))
                            .frame(width: 38, height: 38)
                        Image(systemName: tip.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.mint)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(tip.title)
                                .font(.body(13, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            if isCollected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.mint)
                            }
                        }
                        Text(tip.blurb)
                            .font(.body(11))
                            .foregroundStyle(Theme.inkFaint)
                            .lineLimit(isOpen ? nil : 1)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.99, haptic: false))

            if isOpen {
                VStack(alignment: .leading, spacing: 9) {
                    Divider().overlay(Color.white.opacity(0.08))

                    ForEach(tip.steps.indices, id: \.self) { index in
                        let step = tip.steps[index]
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.body(9, weight: .heavy))
                                .foregroundStyle(Theme.night)
                                .frame(width: 17, height: 17)
                                .background(Circle().fill(Theme.mint))
                            Text(step)
                                .font(.body(12))
                                .foregroundStyle(Theme.inkDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(alignment: .top, spacing: 7) {
                        Text("💡").font(.system(size: 12))
                        Text(tip.funFact)
                            .font(.body(11))
                            .foregroundStyle(Theme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )

                    Button {
                        collect(tip)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isCollected ? "checkmark" : "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text(isCollected ? "Collected" : "Collect +\(tip.xp) XP")
                                .font(.body(11, weight: .bold))
                        }
                        .foregroundStyle(isCollected ? Theme.mint : Theme.night)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(isCollected ? Theme.mint.opacity(0.14) : Theme.mint)
                        )
                    }
                    .buttonStyle(PressableStyle(scale: 0.97))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(GlassSurface(tint: isOpen ? Theme.mint : .white, radius: Theme.rMedium))
    }

    // MARK: Actions

    private func collect(_ tip: HygieneTip) {
        var set = collected
        if set.contains(tip.id) {
            set.remove(tip.id)
            Haptics.tick()
        } else {
            set.insert(tip.id)
            burst += 1
            Haptics.success()
            app.show(Toast(emoji: "🧼", title: "+\(tip.xp) XP",
                           detail: "\(tip.title) collected."))
        }
        collectedRaw = set.sorted().joined(separator: ",")
    }

    private func registerDay() {
        guard !didRegister else { return }
        didRegister = true

        let calendar = Calendar.current
        let last = Date(timeIntervalSince1970: lastOpenStamp)

        if lastOpenStamp == 0 {
            streak = 1
        } else if calendar.isDateInToday(last) {
            streak = max(streak, 1)
        } else if calendar.isDateInYesterday(last) {
            streak += 1
        } else {
            streak = 1
        }

        lastOpenStamp = Date().timeIntervalSince1970
    }
}
