import Foundation

// Wrappers that make model objects safe to use with `.sheet(item:)`.
// Using an explicit route avoids any ambiguity around model identity.

struct PersonRoute: Identifiable {
    let id = UUID()
    let profile: Profile
}

struct BathroomRoute: Identifiable {
    let id = UUID()
    let bathroom: Bathroom
}

struct PostRoute: Identifiable {
    let id = UUID()
    let post: Post
}
