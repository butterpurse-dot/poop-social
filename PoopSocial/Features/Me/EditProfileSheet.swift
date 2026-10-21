import SwiftUI

@MainActor
struct EditProfileSheet: View {

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var handle = ""
    @State private var bio = ""
    @State private var city = "San Francisco"
    @State private var avatar = "🚽"
    @State private var loaded = false

    private let avatars = ["🚽", "🌸", "🧢", "🪐", "🦆", "🧼", "🎧", "🍭", "🧃", "😎", "👽", "🐸", "🦄", "🤖", "🐙", "🍄"]

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 38, height: 5)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Text("Edit profile")
                            .font(.display(25, weight: .black))
                            .foregroundStyle(Theme.ink)
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

                    Text(avatar)
                        .font(.system(size: 54))
                        .frame(width: 96, height: 96)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                        .overlay(Circle().strokeBorder(Theme.mint.opacity(0.5), lineWidth: 2))
                        .frame(maxWidth: .infinity)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                        ForEach(avatars, id: \.self) { option in
                            Button {
                                Haptics.tick()
                                avatar = option
                            } label: {
                                Text(option)
                                    .font(.system(size: 22))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .fill(avatar == option ? Theme.mint.opacity(0.22) : Color.white.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .strokeBorder(avatar == option ? Theme.mint : .clear, lineWidth: 1.4)
                                    )
                            }
                            .buttonStyle(PressableStyle(scale: 0.88))
                        }
                    }

                    field("Display name", text: $name, placeholder: "Your name")
                    field("Handle", text: $handle, placeholder: "handle", prefix: "@")
                    field("City", text: $city, placeholder: "San Francisco")

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Bio")
                            .font(.body(11, weight: .heavy))
                            .foregroundStyle(Theme.inkFaint)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        TextField("Say something funny", text: $bio, axis: .vertical)
                            .font(.body(14))
                            .lineLimit(3...5)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            )
                    }

                    GlowButton(title: "Save changes", icon: "checkmark") {
                        save()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
                .padding(.top, 10)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded, let me = store.me() else { return }
        loaded = true
        name = me.displayName
        handle = me.handle
        bio = me.bio
        city = me.homeCity
        avatar = me.avatarEmoji
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String, prefix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.body(11, weight: .heavy))
                .foregroundStyle(Theme.inkFaint)
                .textCase(.uppercase)
                .tracking(0.6)
            HStack(spacing: 2) {
                if !prefix.isEmpty {
                    Text(prefix)
                        .font(.body(14, weight: .bold))
                        .foregroundStyle(Theme.mint)
                }
                TextField(placeholder, text: text)
                    .font(.body(14, weight: .medium))
                    .conditionalAutocapitalization(prefix.isEmpty ? .words : .never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
    }

    private func save() {
        store.updateProfile(
            displayName: name,
            handle: handle,
            avatarEmoji: avatar,
            bio: bio,
            city: city
        )
        Haptics.success()
        app.show(Toast(emoji: avatar, title: "Profile updated", detail: "Looking good."))
        dismiss()
    }
}
