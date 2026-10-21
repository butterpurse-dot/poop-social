import Foundation
import Observation
import SwiftData

/// The one place writes happen.
///
/// Reads go through `@Query` in views (free, live, automatic). Writes funnel
/// through `Store` so behaviour stays consistent and testable. If this ever
/// grows a backend, `Store` is the seam — swap its internals for network calls.
@MainActor
@Observable
final class Store {

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Persistence

    func save() {
        do {
            try context.save()
        } catch {
            // Persistence failures here are non-fatal for UX; the in-memory graph
            // is still correct and the next save will retry. Deliberately not an
            // assertion: a failed write should never take the app down mid-tap.
            #if DEBUG
            print("Poop Social save failed:", error)
            #endif
        }
    }

    // MARK: - Lookup

    func me() -> Profile? {
        var descriptor = FetchDescriptor<Profile>(predicate: #Predicate { $0.isMe == true })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func profile(matching handle: String) -> Profile? {
        let needle = handle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "@", with: "")
        guard !needle.isEmpty else { return nil }
        return allProfiles().first {
            $0.handle.lowercased() == needle || $0.displayName.lowercased() == needle
        }
    }

    func allProfiles() -> [Profile] {
        (try? context.fetch(FetchDescriptor<Profile>())) ?? []
    }

    /// `Profile.handle` is `@Attribute(.unique)`, so two people can never share
    /// one. Rather than let a clashing edit blow up a save, nudge the new handle
    /// until it is free (`maya` → `maya2` → `maya3` …).
    func uniqueHandle(_ desired: String, excluding profile: Profile?) -> String {
        let taken = Set(
            allProfiles()
                .filter { $0.id != profile?.id }
                .map { $0.handle.lowercased() }
        )
        guard taken.contains(desired) else { return desired }

        var suffix = 2
        while taken.contains("\(desired)\(suffix)") { suffix += 1 }
        return "\(desired)\(suffix)"
    }

    func allConnections() -> [Connection] {
        (try? context.fetch(FetchDescriptor<Connection>())) ?? []
    }

    // MARK: - Posts

    @discardableResult
    func createPost(
        author: Profile?,
        body: String,
        emoji: String,
        joke: String,
        surface: PostSurface,
        bathroom: Bathroom?,
        verdict: Verdict,
        backdrop: Int = 0,
        vibe: String = "",
        parentID: UUID? = nil
    ) -> Post? {
        let cleanBody = Safety.moderator.sanitize(body)
        let cleanJoke = Safety.moderator.sanitize(joke)

        // Every post must have *some* payload. Emoji always counts.
        if cleanBody.isEmpty && cleanJoke.isEmpty && emoji.isEmpty {
            return nil
        }

        let post = Post(
            surface: surface,
            body: cleanBody,
            emoji: emoji,
            joke: cleanJoke,
            verdict: verdict,
            backdrop: backdrop,
            vibe: vibe,
            parentID: parentID
        )
        context.insert(post)
        post.author = author
        post.bathroom = bathroom
        save()
        return post
    }

    func delete(_ post: Post) {
        context.delete(post)
        save()
    }

    // MARK: - Engagement

    @discardableResult
    func toggleReaction(_ emoji: String, on post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }

        if let existing = post.reactions.first(where: {
            $0.emoji == emoji && $0.user?.id == user.id
        }) {
            context.delete(existing)
            save()
            return false
        }

        let reaction = Reaction(emoji: emoji)
        context.insert(reaction)
        reaction.post = post
        reaction.user = user
        save()
        return true
    }

    func hasReacted(_ emoji: String, on post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }
        return post.reactions.contains { $0.emoji == emoji && $0.user?.id == user.id }
    }

    @discardableResult
    func toggleRepost(_ post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }

        if let existing = post.reposts.first(where: { $0.user?.id == user.id }) {
            context.delete(existing)
            save()
            return false
        }

        let repost = Repost()
        context.insert(repost)
        repost.post = post
        repost.user = user
        save()
        return true
    }

    func hasReposted(_ post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }
        return post.reposts.contains { $0.user?.id == user.id }
    }

    @discardableResult
    func toggleBookmark(_ post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }

        if let existing = post.bookmarks.first(where: { $0.user?.id == user.id }) {
            context.delete(existing)
            save()
            return false
        }

        let bookmark = Bookmark()
        context.insert(bookmark)
        bookmark.post = post
        bookmark.user = user
        save()
        return true
    }

    func hasBookmarked(_ post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }
        return post.bookmarks.contains { $0.user?.id == user.id }
    }

    // MARK: - Connections

    /// Add, request, accept, or remove — one tap, one truth.
    func toggleConnection(with other: Profile) {
        guard let me = me(), other.id != me.id else { return }

        if let link = link(with: other) {
            switch link.state {
            case .incoming:
                link.state = .linked
                // Accepting an incoming request must produce the same tier as
                // `accept(_:)` -- otherwise the same action yields "acquaintance"
                // via the profile sheet and "friend" via the requests list.
                if link.closeness < .friend { link.closeness = .friend }
                Haptics.success()
            case .linked, .outgoing:
                context.delete(link)
            case .none:
                link.state = .outgoing
            }
        } else {
            let link = Connection()
            context.insert(link)
            link.from = me
            link.to = other
            link.state = .outgoing
            link.closeness = .acquaintance
        }
        save()
    }

    func link(with other: Profile) -> Connection? {
        guard let me = me() else { return nil }
        return allConnections().first {
            ($0.from?.id == me.id && $0.to?.id == other.id) ||
            ($0.from?.id == other.id && $0.to?.id == me.id)
        }
    }

    func pendingRequests() -> [Connection] {
        guard let me = me() else { return [] }
        return allConnections().filter { $0.to?.id == me.id && $0.state != .linked }
    }

    func accept(_ connection: Connection) {
        connection.state = .linked
        if connection.closeness < .friend { connection.closeness = .friend }
        Haptics.success()
        save()
    }

    func decline(_ connection: Connection) {
        context.delete(connection)
        save()
    }

    func setCloseness(_ closeness: Closeness, for other: Profile) {
        guard let link = link(with: other) else { return }
        link.state = .linked
        link.closeness = closeness
        Haptics.select()
        save()
    }

    func closeness(to other: Profile) -> Closeness {
        link(with: other)?.closeness ?? .acquaintance
    }

    // MARK: - Invites (add friends by number / email)

    /// Create an invite from a **raw** phone number or email address.
    ///
    /// The raw value is hashed here and then goes out of scope — it is never
    /// written to the graph. This is the intended entry point for the UI, so
    /// that the only type-aware call site is this one method rather than every
    /// view being trusted to hash correctly.
    ///
    /// Returns `nil` if the input is not a plausible number or address, or if an
    /// invite for that contact already exists.
    @discardableResult
    func invite(raw contact: String) -> Invite? {
        guard let (kind, hash) = ContactHasher.hash(raw: contact, salt: ContactHasher.salt()) else {
            return nil
        }
        return invite(hash: hash, kind: kind)
    }

    /// Create an invite from an already-computed hash. Exposed separately so
    /// callers that hold hashes (e.g. a future contacts-import that hashes a
    /// whole address book in one pass) do not have to route raw values through.
    @discardableResult
    func invite(hash: String, kind: ContactKind) -> Invite? {
        guard !hash.isEmpty else { return nil }
        guard !allInvites().contains(where: { $0.contactHash == hash }) else { return nil }

        let invite = Invite(contactHash: hash, kind: kind)
        context.insert(invite)
        save()
        return invite
    }

    func allInvites() -> [Invite] {
        (try? context.fetch(FetchDescriptor<Invite>())) ?? []
    }

    /// Pending invites, newest first — what the UI shows under "Waiting on".
    func pendingInvites() -> [Invite] {
        allInvites()
            .filter { $0.state == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Is this raw contact already invited? Hashes internally, so the caller
    /// never has to hold a hash to ask.
    func hasInvited(raw contact: String) -> Bool {
        guard let (_, hash) = ContactHasher.hash(raw: contact, salt: ContactHasher.salt()) else {
            return false
        }
        return allInvites().contains { $0.contactHash == hash }
    }

    func cancel(_ invite: Invite) {
        context.delete(invite)
        save()
    }

    /// Claim a pending invite for `profile` and make the two of them linked.
    ///
    /// This is the "someone signed up with an address you invited" path. It
    /// marks the invite claimed and creates the connection in one step so the
    /// invite cannot end up claimed-but-unlinked.
    func claim(_ invite: Invite, by profile: Profile) {
        guard invite.state == .pending, let me = me(), profile.id != me.id else { return }
        invite.claimedBy = profile
        invite.state = .claimed

        if let link = link(with: profile) {
            link.state = .linked
        } else {
            let connection = Connection(from: me, to: profile, state: .linked, closeness: .friend)
            context.insert(connection)
        }
        Haptics.success()
        save()
    }

    // MARK: - Bathrooms

    @discardableResult
    func addBathroom(
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        kind: BathKind,
        amenities: Set<Amenity>,
        addedBy: Profile?
    ) -> Bathroom {
        let bathroom = Bathroom(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: latitude,
            longitude: longitude,
            kind: kind,
            amenities: Array(amenities),
            addedByName: addedBy?.displayName ?? "A stranger"
        )
        context.insert(bathroom)
        save()
        return bathroom
    }

    @discardableResult
    func submitReview(
        bathroom: Bathroom,
        author: Profile?,
        mood: Mood,
        cleanliness: Int,
        waitMinutes: Int,
        verdict: Verdict,
        note: String,
        joke: String,
        emoji: String,
        shareToFeed: Bool
    ) -> Review {
        let review = Review(
            rating: mood.rawValue,
            cleanliness: max(1, min(5, cleanliness)),
            waitMinutes: max(0, waitMinutes),
            verdict: verdict,
            note: Safety.moderator.sanitize(note),
            joke: Safety.moderator.sanitize(joke),
            emoji: emoji
        )
        context.insert(review)
        review.bathroom = bathroom
        review.author = author

        if shareToFeed {
            let post = Post(
                surface: .drop,
                body: review.note,
                emoji: emoji.isEmpty ? mood.emoji : emoji,
                joke: review.joke,
                verdict: verdict,
                vibe: mood.label
            )
            context.insert(post)
            post.author = author
            post.bathroom = bathroom
        }

        save()
        return review
    }

    // MARK: - Profile

    func updateProfile(displayName: String, handle: String, avatarEmoji: String, bio: String, city: String) {
        guard let me = me() else { return }
        let cleanHandle = handle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
        me.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanHandle.isEmpty { me.handle = uniqueHandle(cleanHandle, excluding: me) }
        me.avatarEmoji = avatarEmoji
        me.bio = Safety.moderator.sanitize(bio)
        me.homeCity = city
        save()
    }

    // MARK: - Stats

    func myStats() -> (posts: Int, reviews: Int, crew: Int, satisfying: Int, bathrooms: Int) {
        guard let me = me() else { return (0, 0, 0, 0, 0) }
        let crew = me.linkedPeople().count
        let satisfying = me.reviews.filter { $0.verdict == .satisfying }.count
        let bathrooms = Set(me.reviews.compactMap { $0.bathroom?.id }).count
        return (me.posts.filter { !$0.isReply }.count, me.reviews.count, crew, satisfying, bathrooms)
    }
}
