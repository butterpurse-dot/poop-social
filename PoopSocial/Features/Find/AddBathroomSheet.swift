import SwiftUI
import CoreLocation

@MainActor
struct AddBathroomSheet: View {

    var defaultCoordinate: CLLocationCoordinate2D? = nil

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var kind: BathKind = .publicRestroom
    @State private var amenities: Set<Amenity> = [.soap, .paper]
    @State private var burst = 0

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 38, height: 5)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add a throne")
                            .font(.display(25, weight: .black))
                            .foregroundStyle(Theme.ink)
                        Text("Pin it for the people who need it most.")
                            .font(.body(12))
                            .foregroundStyle(Theme.inkFaint)
                    }

                    field("Name", text: $name, placeholder: "e.g. The Mint Throne")
                    field("Address", text: $address, placeholder: "Street and neighbourhood")

                    VStack(alignment: .leading, spacing: 8) {
                        label("Type")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(BathKind.allCases) { option in
                                    Chip(title: option.label, icon: option.icon, selected: kind == option) { _ in
                                        kind = option
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollClipDisabled()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("Amenities")
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 108), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(Amenity.allCases) { amenity in
                                Button {
                                    Haptics.select()
                                    if amenities.contains(amenity) {
                                        amenities.remove(amenity)
                                    } else {
                                        amenities.insert(amenity)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: amenity.icon)
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(amenity.label)
                                            .font(.body(11, weight: .semibold))
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .foregroundStyle(amenities.contains(amenity) ? Theme.night : Theme.inkDim)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                amenities.contains(amenity)
                                                ? AnyShapeStyle(Theme.mint)
                                                : AnyShapeStyle(Color.white.opacity(0.05))
                                            )
                                    )
                                }
                                .buttonStyle(PressableStyle(scale: 0.95))
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.mint)
                        Text(defaultCoordinate == nil
                             ? "Pinned to Central San Francisco"
                             : "Pinned to your current location")
                            .font(.body(11, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )

                    GlowButton(title: "Pin this throne", icon: "mappin.and.ellipse", enabled: canSave) {
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
        .overlay(alignment: .center) {
            EmojiBurst(emojis: ["📍", "🚽", "✨", "🧻"], trigger: burst)
                .allowsHitTesting(false)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.body(11, weight: .heavy))
            .foregroundStyle(Theme.inkFaint)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            label(title)
            TextField(placeholder, text: text)
                .font(.body(14, weight: .medium))
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
        guard canSave else { return }
        let coordinate = defaultCoordinate
            ?? CLLocationCoordinate2D(latitude: 37.7860, longitude: -122.4070)

        let bathroom = store.addBathroom(
            name: name,
            address: address,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            kind: kind,
            amenities: amenities,
            addedBy: store.me()
        )

        burst += 1
        Haptics.success()
        app.show(Toast(emoji: "📍", title: "Throne pinned", detail: bathroom.name))
        dismiss()
    }
}
