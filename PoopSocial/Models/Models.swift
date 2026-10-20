import Foundation
import SwiftUI
import SwiftData
import CoreLocation

// MARK: - Enums (Codable → SwiftData can persist them directly)

enum Closeness: String, Codable, CaseIterable, Identifiable, Comparable {
    case acquaintance
    case friend
    case bestie

    var id: String { rawValue }

    var label: String {
        switch self {
        case .acquaintance: return "Acquaintance"
        case .friend:       return "Friend"
        case .bestie:       return "Bestie"
        }
    }

    var blurb: String {
        switch self {
        case .acquaintance: return "Shared a restroom corridor once or twice."
        case .friend:       return "Sends the \"this place is clean\" text."
        case .bestie:       return "Knows your thresholds. Emergency contact."
        }
    }

    var emoji: String {
        switch self {
        case .acquaintance: return "👋"
        case .friend:       return "🤝"
        case .bestie:       return "💖"
        }
    }

    var tint: Color {
        switch self {
        case .acquaintance: return Theme.sky
        case .friend:       return Theme.mint
        case .bestie:       return Theme.bubble
        }
    }

    private var rank: Int { Self.allCases.firstIndex(of: self)! }
    static func < (lhs: Closeness, rhs: Closeness) -> Bool { lhs.rank < rhs.rank }
}

enum LinkState: String, Codable {
    case none
    case outgoing
    case incoming
    case linked

    var label: String {
        switch self {
        case .none:     return "Add"
        case .outgoing: return "Requested"
        case .incoming: return "Accept"
        case .linked:   return "Crew"
        }
    }
}

enum BathKind: String, Codable, CaseIterable, Identifiable {
    case publicRestroom, restaurant, mall, gasStation, park, hotel, bar, cafe, office, transit, library

    var id: String { rawValue }

    var label: String {
        switch self {
        case .publicRestroom: return "Public restroom"
        case .restaurant:     return "Restaurant"
        case .mall:           return "Mall"
        case .gasStation:     return "Gas station"
        case .park:           return "Park"
        case .hotel:          return "Hotel lobby"
        case .bar:            return "Bar"
        case .cafe:           return "Café"
        case .office:         return "Office"
        case .transit:        return "Transit"
        case .library:        return "Library"
        }
    }

    var icon: String {
        switch self {
        case .publicRestroom: return "toilet.fill"
        case .restaurant:     return "fork.knife"
        case .mall:           return "cart.fill"
        case .gasStation:     return "fuelpump.fill"
        case .park:           return "tree.fill"
        case .hotel:          return "bed.double.fill"
        case .bar:            return "wineglass.fill"
        case .cafe:           return "cup.and.saucer.fill"
        case .office:         return "building.2.fill"
        case .transit:        return "tram.fill"
        case .library:        return "books.vertical.fill"
        }
    }
}

enum Amenity: String, Codable, CaseIterable, Identifiable {
    case free, accessible, babyChanging, soap, paper, handDryer, privateStall, wellLit, staffed, open24h

    var id: String { rawValue }

    var label: String {
        switch self {
        case .free:         return "Free"
        case .accessible:   return "Accessible"
        case .babyChanging: return "Baby change"
        case .soap:         return "Soap"
        case .paper:        return "Paper"
        case .handDryer:    return "Dryer"
        case .privateStall: return "Private"
        case .wellLit:      return "Well lit"
        case .staffed:      return "Attendant"
        case .open24h:      return "24/7"
        }
    }

    var icon: String {
        switch self {
        case .free:         return "dollarsign.circle"
        case .accessible:   return "figure.roll"
        case .babyChanging: return "figure.and.child.holdinghands"
        case .soap:         return "bubbles.and.sparkles.fill"
        case .paper:        return "square.stack.3d.up.fill"
        case .handDryer:    return "wind"
        case .privateStall: return "lock.fill"
        case .wellLit:      return "lightbulb.fill"
        case .staffed:      return "person.badge.shield.checkmark.fill"
        case .open24h:      return "clock.badge.checkmark.fill"
        }
    }
}

enum Mood: Int, Codable, CaseIterable, Identifiable {
    case catastrophic = 1
    case rough = 2
    case survivable = 3
    case good = 4
    case transcendent = 5

    var id: Int { rawValue }

    var emoji: String {
        switch self {
        case .catastrophic: return "🤢"
        case .rough:        return "😬"
        case .survivable:   return "😐"
        case .good:         return "😌"
        case .transcendent: return "🤩"
        }
    }

    var label: String {
        switch self {
        case .catastrophic: return "Catastrophic"
        case .rough:        return "Rough"
        case .survivable:   return "Survivable"
        case .good:         return "Good"
        case .transcendent: return "Transcendent"
        }
    }

    var headline: String {
        switch self {
        case .catastrophic: return "I have made a huge mistake."
        case .rough:        return "We do not speak of this."
        case .survivable:   return "It was a bathroom. It did the job."
        case .good:         return "Solid. Would plot again."
        case .transcendent: return "I saw through time."
        }
    }
}

enum Verdict: String, Codable, CaseIterable, Identifiable {
    case satisfying
    case unsatisfying
    case neutral

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .satisfying:   return "✨"
        case .unsatisfying: return "💀"
        case .neutral:      return "🫥"
        }
    }

    var label: String {
        switch self {
        case .satisfying:   return "Satisfying"
        case .unsatisfying: return "Not satisfying"
        case .neutral:      return "Meh"
        }
    }

    var tint: Color {
        switch self {
        case .satisfying:   return Theme.mint
        case .unsatisfying: return Theme.danger
        case .neutral:      return Theme.sky
        }
    }
}

/// Which surface a post lives on. One model, two presentations.
enum PostSurface: String, Codable {
    case drop   // timeline / threads
    case reel   // full-screen vertical feed
}

// MARK: - Profile

@Model
final class Profile {
    @Attribute(.unique) var id: UUID
    var displayName: String
    @Attribute(.unique) var handle: String
    var avatarEmoji: String
    var bio: String
    var homeCity: String
    var joinedAt: Date
    var isMe: Bool

    @Relationship(deleteRule: .nullify, inverse: \Post.author)
    var posts: [Post]

    @Relationship(deleteRule: .nullify, inverse: \Review.author)
    var reviews: [Review]

    @Relationship(deleteRule: .nullify, inverse: \Reaction.user)
    var reactions: [Reaction]

    @Relationship(deleteRule: .nullify, inverse: \Repost.user)
    var reposts: [Repost]

    @Relationship(deleteRule: .nullify, inverse: \Bookmark.user)
    var bookmarks: [Bookmark]

    @Relationship(deleteRule: .nullify, inverse: \Connection.from)
    var outgoingLinks: [Connection]

    @Relationship(deleteRule: .nullify, inverse: \Connection.to)
    var incomingLinks: [Connection]

    init(
        id: UUID = UUID(),
        displayName: String,
        handle: String,
        avatarEmoji: String = "🚽",
        bio: String = "",
        homeCity: String = "San Francisco",
        joinedAt: Date = .now,
        isMe: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.avatarEmoji = avatarEmoji
        self.bio = bio
        self.homeCity = homeCity
        self.joinedAt = joinedAt
        self.isMe = isMe
        self.posts = []
        self.reviews = []
        self.reactions = []
        self.reposts = []
        self.bookmarks = []
        self.outgoingLinks = []
        self.incomingLinks = []
    }
}

// MARK: - Bathroom

@Model
final class Bathroom {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var kind: BathKind
    var amenities: [Amenity]
    var addedByName: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Review.bathroom)
    var reviews: [Review]

    @Relationship(deleteRule: .cascade, inverse: \Post.bathroom)
    var posts: [Post]

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        kind: BathKind = .publicRestroom,
        amenities: [Amenity] = [],
        addedByName: String = "A stranger",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.kind = kind
        self.amenities = amenities
        self.addedByName = addedByName
        self.createdAt = createdAt
        self.reviews = []
        self.posts = []
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var cleanlinessScore: Double {
        let scores = reviews.map { Double($0.cleanliness) }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    var experienceScore: Double {
        let scores = reviews.map { Double($0.rating) }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    var reviewCount: Int { reviews.count }

    var satisfyingCount: Int {
        reviews.filter { $0.verdict == .satisfying }.count
    }

    var cleanLabel: String {
        let s = cleanlinessScore
        if s == 0          { return "Untested" }
        if s >= 4.5        { return "Surgical" }
        if s >= 3.5        { return "Fresh" }
        if s >= 2.5        { return "Passable" }
        if s >= 1.5        { return "Rough" }
        return "Biohazard"
    }
}

// MARK: - Review

@Model
final class Review {
    @Attribute(.unique) var id: UUID
    var bathroom: Bathroom?
    var author: Profile?
    var rating: Int
    var cleanliness: Int
    var waitMinutes: Int
    var verdict: Verdict
    var note: String
    var joke: String
    var emoji: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        bathroom: Bathroom? = nil,
        author: Profile? = nil,
        rating: Int = 3,
        cleanliness: Int = 3,
        waitMinutes: Int = 0,
        verdict: Verdict = .neutral,
        note: String = "",
        joke: String = "",
        emoji: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.bathroom = bathroom
        self.author = author
        self.rating = rating
        self.cleanliness = cleanliness
        self.waitMinutes = waitMinutes
        self.verdict = verdict
        self.note = note
        self.joke = joke
        self.emoji = emoji
        self.createdAt = createdAt
    }

    var mood: Mood { Mood(rawValue: rating) ?? .survivable }
}

// MARK: - Post (Drop & Reel)

@Model
final class Post {
    @Attribute(.unique) var id: UUID
    var author: Profile?
    var bathroom: Bathroom?
    var surface: PostSurface
    var body: String
    var emoji: String
    var joke: String
    var verdict: Verdict
    var backdrop: Int
    var vibe: String
    /// nil for top-level posts; set to the parent's id for replies.
    /// Deliberately a plain UUID instead of a self-referential relationship —
    /// simpler, faster to query, and avoids SwiftData self-inverse edge cases.
    var parentID: UUID?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Reaction.post)
    var reactions: [Reaction]

    @Relationship(deleteRule: .cascade, inverse: \Repost.post)
    var reposts: [Repost]

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.post)
    var bookmarks: [Bookmark]

    init(
        id: UUID = UUID(),
        author: Profile? = nil,
        bathroom: Bathroom? = nil,
        surface: PostSurface = .drop,
        body: String = "",
        emoji: String = "🚽",
        joke: String = "",
        verdict: Verdict = .neutral,
        backdrop: Int = 0,
        vibe: String = "clean-core",
        parentID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.author = author
        self.bathroom = bathroom
        self.surface = surface
        self.body = body
        self.emoji = emoji
        self.joke = joke
        self.verdict = verdict
        self.backdrop = backdrop
        self.vibe = vibe
        self.parentID = parentID
        self.createdAt = createdAt
        self.reactions = []
        self.reposts = []
        self.bookmarks = []
    }

    var isReply: Bool { parentID != nil }

    func reactionCount(_ emoji: String) -> Int {
        reactions.filter { $0.emoji == emoji }.count
    }

    var totalReactions: Int { reactions.count }
}

// MARK: - Small join models

@Model
final class Reaction {
    @Attribute(.unique) var id: UUID
    var post: Post?
    var user: Profile?
    var emoji: String
    var createdAt: Date

    init(id: UUID = UUID(), post: Post? = nil, user: Profile? = nil, emoji: String = "🔥", createdAt: Date = .now) {
        self.id = id
        self.post = post
        self.user = user
        self.emoji = emoji
        self.createdAt = createdAt
    }
}

@Model
final class Repost {
    @Attribute(.unique) var id: UUID
    var post: Post?
    var user: Profile?
    var createdAt: Date

    init(id: UUID = UUID(), post: Post? = nil, user: Profile? = nil, createdAt: Date = .now) {
        self.id = id
        self.post = post
        self.user = user
        self.createdAt = createdAt
    }
}

@Model
final class Bookmark {
    @Attribute(.unique) var id: UUID
    var post: Post?
    var user: Profile?
    var createdAt: Date

    init(id: UUID = UUID(), post: Post? = nil, user: Profile? = nil, createdAt: Date = .now) {
        self.id = id
        self.post = post
        self.user = user
        self.createdAt = createdAt
    }
}

@Model
final class Connection {
    @Attribute(.unique) var id: UUID
    var from: Profile?
    var to: Profile?
    var stateRaw: String
    var closeness: Closeness
    var createdAt: Date

    init(
        id: UUID = UUID(),
        from: Profile? = nil,
        to: Profile? = nil,
        state: LinkState = .outgoing,
        closeness: Closeness = .acquaintance,
        createdAt: Date = .now
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.stateRaw = state.rawValue
        self.closeness = closeness
        self.createdAt = createdAt
    }

    var state: LinkState {
        get { LinkState(rawValue: stateRaw) ?? .none }
        set { stateRaw = newValue.rawValue }
    }

    func other(than me: Profile?) -> Profile? {
        guard let me else { return from ?? to }
        return from?.id == me.id ? to : from
    }
}

// MARK: - Graph helpers

extension Profile {
    func linkedPeople() -> [Profile] {
        (outgoingLinks + incomingLinks)
            .filter { $0.state == .linked }
            .compactMap { $0.other(than: self) }
    }

    func closeness(to other: Profile) -> Closeness? {
        (outgoingLinks + incomingLinks)
            .first { $0.state == .linked && $0.other(than: self)?.id == other.id }?
            .closeness
    }

    func state(towards other: Profile) -> LinkState {
        guard let link = (outgoingLinks + incomingLinks)
            .first(where: { $0.other(than: self)?.id == other.id }) else { return .none }
        if link.state == .linked { return .linked }
        return link.from?.id == self.id ? .outgoing : .incoming
    }
}
