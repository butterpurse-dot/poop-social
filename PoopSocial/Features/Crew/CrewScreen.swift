import SwiftUI
import SwiftData

enum CrewScope: String, CaseIterable, Identifiable {
    case crew
    case discover

    var id: String { rawValue }
    var label: String {
        switch self {
        case .crew:     return "My crew"
        case .discover: return "Discover"
        }
    }
}

@MainActor
struct CrewScreen: View {

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store

    @Query private var profiles: [Profile]
    @Query private var connections: [Connection]

    @State private var scope: CrewScope = .crew
    @State private var search = ""
    @State private var personRoute: PersonRoute?
    @State private var showInvite = false
    @Namespace private var scopeNS

    private var me: Profile? { profiles.first { $0.isMe } }

    private var crew: [Profile] {
        guard let me else { return [] }
        return me.linkedPeople()
            .sorted {
                let a = me.closeness(to: $0) ?? .acquaintance
                let b = me.closeness(to: $1) ?? .acquaintance
                if a != b { return a > b }
                return $0.displayName < $1.displayName
            }
    }

    private var pending: [Connection] {
        guard let me else { return [] }
        return connections.filter {
            $0.to?.id == me.id && $0.state == .incoming
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    /// Invites sent from this device that nobody has claimed yet. Shown so an
    /// invite is not a fire-and-forget — the user can see it is still waiting,
    /// and cancel it.
    private var pendingInvites: [Invite] {
        store.pendingInvites()
    }

    private var discover: [Profile] {
        guard let me else { return profiles }
        return profiles
            .filter { $0.id != me.id }
            .filter { person in
                let state = me.state(towards: person)
                return state == .none || state == .outgoing
            }
            .sorted { $0.joinedAt > $1.joinedAt }
    }

    private var filteredCrew: [Profile] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return crew }
        return crew.filter {
            $0.displayName.lowercased().contains(needle) ||
            $0.handle.lowercased().contains(needle)
        }
    }

    private var filteredDiscover: [Profile] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return discover }
        return discover.filter {
            $0.displayName.lowercased().contains(needle) ||
            $0.handle.lowercased().contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                BubbleBackdrop(tint: Theme.bubble, secondary: Theme.grape)

                ScrollView {
                    LazyVStack(spacing: 14) {
                        header
                        searchBar
                        scopePicker
                        if scope == .crew && !pending.isEmpty { requestsSection }
                        if scope == .discover && !pendingInvites.isEmpty { invitesSection }
                        mainSection
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $personRoute) { route in
                PersonSheet(profile: route.profile)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
            .sheet(isPresented: $showInvite) {
                InviteSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Crew")
                    .font(.display(28, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Two tiers of trust: friends and acquaintances.")
                    .font(.body(11))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            Button {
                Haptics.tick()
                showInvite = true
            } label: {
                IconBubble(icon: "person.badge.plus", tint: Theme.mint, size: 38, filled: true)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Add a friend by number or email")
        }
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            TextField("Search by name or @handle", text: $search)
                .font(.body(14, weight: .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    // MARK: Scope

    private var scopePicker: some View {
        HStack(spacing: 0) {
            ForEach(CrewScope.allCases) { option in
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { scope = option }
                } label: {
                    HStack(spacing: 5) {
                        Text(option.label).font(.body(13, weight: .bold))
                        if option == .crew {
                            Text("\(crew.count)")
                                .font(.body(10, weight: .heavy))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(
                                        scope == .crew ? Theme.night.opacity(0.18) : Color.white.opacity(0.10)
                                    )
                                )
                        }
                    }
                    .foregroundStyle(scope == option ? Theme.night : Theme.inkDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if scope == option {
                            Capsule()
                                .fill(Theme.mint)
                                .matchedGeometryEffect(id: "crewScope", in: scopeNS)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    // MARK: Requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text("Requests")
                    .font(.display(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("\(pending.count)")
                    .font(.body(10, weight: .heavy))
                    .foregroundStyle(Theme.night)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.bubble))
                Spacer()
            }

            ForEach(pending, id: \.id) { request in
                if let person = request.from {
                    HStack(spacing: 10) {
                        AvatarView(emoji: person.avatarEmoji, size: 42, ring: Theme.bubble.opacity(0.5))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(person.displayName)
                                .font(.body(13, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text("@\(person.handle)")
                                .font(.body(10))
                                .foregroundStyle(Theme.inkFaint)
                        }

                        Spacer()

                        Button {
                            store.accept(request)
                            app.show(Toast(emoji: "🤝", title: "\(person.displayName) added",
                                           detail: "You're now acquaintances."))
                        } label: {
                            Text("Accept")
                                .font(.body(11, weight: .bold))
                                .foregroundStyle(Theme.night)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Theme.mint))
                        }
                        .buttonStyle(PressableStyle(scale: 0.92))

                        Button {
                            store.decline(request)
                            Haptics.warn()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.inkFaint)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.white.opacity(0.07)))
                        }
                        .buttonStyle(PressableStyle(scale: 0.9))
                    }
                    .glassCard(tint: Theme.bubble, padding: 11)
                }
            }
        }
    }

    // MARK: Invites sent

    /// Deliberately shows the *kind* and a truncated hash — never the contact
    /// itself, because the app genuinely does not have it.
    private var invitesSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text("Waiting on")
                    .font(.display(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("\(pendingInvites.count)")
                    .font(.body(10, weight: .heavy))
                    .foregroundStyle(Theme.night)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.sky))
                Spacer()
            }

            ForEach(pendingInvites, id: \.id) { invite in
                HStack(spacing: 10) {
                    IconBubble(icon: invite.kind.icon, tint: Theme.sky, size: 38, filled: true)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Invited by \(invite.kind.label)")
                            .font(.body(13, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(String(invite.contactHash.prefix(16)) + "…")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.inkFaint)
                    }

                    Spacer()

                    Button {
                        store.cancel(invite)
                        Haptics.warn()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.inkFaint)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                    }
                    .buttonStyle(PressableStyle(scale: 0.9))
                }
                .glassCard(tint: Theme.sky, padding: 11)
            }
        }
    }

    // MARK: Main

    @ViewBuilder
    private var mainSection: some View {
        if scope == .crew {
            if filteredCrew.isEmpty {
                EmptyPanel(
                    icon: "👋",
                    title: "No crew yet",
                    message: "Find people in Discover. Start them as acquaintances — promote the good ones.",
                    actionTitle: "Discover people"
                ) {
                    scope = .discover
                }
                .glassCard(padding: 4)
            } else {
                ForEach(Closeness.allCases.reversed(), id: \.self) { tier in
                    let people = filteredCrew.filter {
                        (me?.closeness(to: $0) ?? .acquaintance) == tier
                    }
                    if !people.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text(tier.emoji).font(.system(size: 13))
                                Text(tier.label)
                                    .font(.display(15, weight: .heavy))
                                    .foregroundStyle(Theme.ink)
                                Text("\(people.count)")
                                    .font(.body(10, weight: .heavy))
                                    .foregroundStyle(tier.tint)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(tier.tint.opacity(0.14)))
                                Spacer()
                            }
                            .padding(.top, 4)

                            ForEach(people, id: \.id) { person in
                                personRow(person, tier: tier)
                            }
                        }
                    }
                }
            }
        } else {
            if filteredDiscover.isEmpty {
                EmptyPanel(
                    icon: "🫧",
                    title: "You've found everyone",
                    message: "That's the whole neighbourhood. Invite a friend by number or email.",
                    actionTitle: "Invite a friend"
                ) {
                    showInvite = true
                }
                .glassCard(padding: 4)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("People nearby")
                        .font(.display(15, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 4)

                    ForEach(filteredDiscover, id: \.id) { person in
                        personRow(person, tier: nil)
                    }

                    Button {
                        Haptics.tick()
                        showInvite = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("Invite by number or email")
                                .font(.body(13, weight: .bold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.inkFaint)
                        }
                        .foregroundStyle(Theme.mint)
                        .padding(13)
                        .glassCard(tint: Theme.mint, padding: 0)
                    }
                    .buttonStyle(PressableStyle(scale: 0.99))
                    .padding(.top, 6)
                }
            }
        }
    }

    private func personRow(_ person: Profile, tier: Closeness?) -> some View {
        HStack(spacing: 11) {
            AvatarView(
                emoji: person.avatarEmoji,
                size: 44,
                ring: (tier?.tint ?? Theme.sky).opacity(0.45)
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(person.displayName)
                        .font(.body(14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if person.isMe {
                        Text("YOU")
                            .font(.body(8, weight: .heavy))
                            .foregroundStyle(Theme.night)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.mint))
                    }
                }
                Text("@\(person.handle)")
                    .font(.body(10, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                if let tier {
                    Text(tier.blurb)
                        .font(.body(10))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if let me {
                let state = me.state(towards: person)
                if state == .linked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.mint.opacity(0.85))
                        .contentShape(Rectangle())
                        .onTapGesture { openPerson(person) }
                } else {
                    Button {
                        store.toggleConnection(with: person)
                        Haptics.pop()
                    } label: {
                        Text(state == .outgoing ? "Requested" : "Add")
                            .font(.body(11, weight: .bold))
                            .foregroundStyle(state == .outgoing ? Theme.inkFaint : Theme.night)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(
                                    state == .outgoing
                                    ? AnyShapeStyle(Color.white.opacity(0.07))
                                    : AnyShapeStyle(Theme.mint)
                                )
                            )
                    }
                    .buttonStyle(PressableStyle(scale: 0.9))
                }
            }
        }
        .glassCard(padding: 11)
        .contentShape(Rectangle())
        .onTapGesture { openPerson(person) }
    }

    private func openPerson(_ person: Profile) {
        Haptics.tick()
        personRoute = PersonRoute(profile: person)
    }
}
