import SwiftUI
import SwiftData
import MapKit

enum BathFilter: String, CaseIterable, Identifiable {
    case all
    case free
    case open24h
    case accessible
    case topRated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:        return "All"
        case .free:       return "Free"
        case .open24h:    return "24/7"
        case .accessible: return "Accessible"
        case .topRated:   return "Top rated"
        }
    }

    var icon: String? {
        switch self {
        case .all:        return nil
        case .free:       return "dollarsign.circle"
        case .open24h:    return "clock.fill"
        case .accessible: return "figure.roll"
        case .topRated:   return "star.fill"
        }
    }
}

@MainActor
struct FindScreen: View {

    @Environment(AppModel.self) private var app

    @Query(sort: \Bathroom.createdAt, order: .reverse) private var bathrooms: [Bathroom]

    @StateObject private var location = LocationProvider()

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7860, longitude: -122.4070),
            span: MKCoordinateSpan(latitudeDelta: 0.055, longitudeDelta: 0.055)
        )
    )

    @State private var search = ""
    @State private var filter: BathFilter = .all
    @State private var detailRoute: BathroomRoute?
    @State private var showAdd = false
    @State private var cardSelection: UUID?
    @State private var didCenter = false

    private var filtered: [Bathroom] {
        var result = bathrooms

        switch filter {
        case .all:
            break
        case .free:
            result = result.filter { $0.amenities.contains(.free) }
        case .open24h:
            result = result.filter { $0.amenities.contains(.open24h) }
        case .accessible:
            result = result.filter { $0.amenities.contains(.accessible) }
        case .topRated:
            result = result.filter { $0.experienceScore >= 4 }
        }

        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !needle.isEmpty {
            result = result.filter {
                $0.name.lowercased().contains(needle) ||
                $0.address.lowercased().contains(needle) ||
                $0.kind.label.lowercased().contains(needle)
            }
        }

        return result.sorted {
            if $0.reviewCount == 0 && $1.reviewCount > 0 { return false }
            if $1.reviewCount == 0 && $0.reviewCount > 0 { return true }
            return $0.experienceScore > $1.experienceScore
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                map

                VStack(spacing: 10) {
                    searchBar
                    filterRow
                    Spacer()
                    carousel
                }
                .padding(.top, 6)
            }
            .hidesNavigationBar()
            .ignoresSafeArea(edges: .bottom)
            .sheet(item: $detailRoute) { route in
                BathroomDetailScreen(bathroom: route.bathroom)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
            .sheet(isPresented: $showAdd) {
                AddBathroomSheet(defaultCoordinate: location.coordinate)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
            .onAppear {
                location.request()
                if location.coordinate != nil { centerOnUser() }
            }
            .onChange(of: location.coordinate?.latitude) { _, _ in
                if !didCenter { centerOnUser() }
            }
        }
    }

    // MARK: Map

    private var map: some View {
        Map(position: $position) {
            UserAnnotation()

            ForEach(filtered, id: \.id) { bathroom in
                Annotation(bathroom.name, coordinate: bathroom.coordinate, anchor: .center) {
                    Button {
                        Haptics.pop()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            cardSelection = bathroom.id
                        }
                        withAnimation(.easeInOut(duration: 0.45)) {
                            position = .region(
                                MKCoordinateRegion(
                                    center: bathroom.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                                )
                            )
                        }
                    } label: {
                        PottyPin(
                            bathroom: bathroom,
                            selected: cardSelection == bathroom.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .ignoresSafeArea()
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)

            TextField("Search bathrooms or areas", text: $search)
                .font(.body(14, weight: .medium))
                .noAutocapitalization()
                .autocorrectionDisabled()

            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
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
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
        .padding(.horizontal, Theme.gutter)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(BathFilter.allCases) { option in
                    Chip(title: option.label, icon: option.icon, selected: filter == option) { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            filter = option
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
        .scrollClipDisabled()
    }

    // MARK: Carousel

    @ViewBuilder
    private var carousel: some View {
        if filtered.isEmpty {
            HStack(spacing: 10) {
                Text("🫥").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 1) {
                    Text("No thrones match that")
                        .font(.body(13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Try a different filter, or add the one you're thinking of.")
                        .font(.body(11))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.night)
                        .padding(9)
                        .background(Circle().fill(Theme.mint))
                }
            }
            .padding(14)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 8)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 11) {
                    ForEach(filtered, id: \.id) { bathroom in
                        Button {
                            Haptics.tick()
                            detailRoute = BathroomRoute(bathroom: bathroom)
                        } label: {
                            BathCard(bathroom: bathroom, selected: cardSelection == bathroom.id)
                        }
                        .buttonStyle(PressableStyle(scale: 0.97))
                        .accessibilityIdentifier("bathCard")
                        .accessibilityLabel(bathroom.name)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollClipDisabled()
            .padding(.bottom, 8)
        }
    }

    // MARK: Actions

    private func centerOnUser() {
        guard let coordinate = location.coordinate else { return }
        didCenter = true
        withAnimation(.easeInOut(duration: 0.6)) {
            position = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
        }
    }
}

// MARK: - Pin

@MainActor
private struct PottyPin: View {
    let bathroom: Bathroom
    let selected: Bool

    private var tint: Color {
        bathroom.experienceScore >= 4 ? Theme.mint
        : bathroom.experienceScore >= 2.5 ? Theme.sky
        : bathroom.reviewCount == 0 ? Theme.inkDim
        : Theme.danger
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(selected ? AnyShapeStyle(tint) : AnyShapeStyle(.ultraThinMaterial))
                    .frame(width: selected ? 42 : 32, height: selected ? 42 : 32)
                    .overlay(
                        Circle().strokeBorder(
                            selected ? Color.white : tint.opacity(0.8),
                            lineWidth: 1.6
                        )
                    )
                    .shadow(color: tint.opacity(selected ? 0.6 : 0.3), radius: selected ? 12 : 5)

                Image(systemName: bathroom.kind.icon)
                    .font(.system(size: selected ? 16 : 12, weight: .bold))
                    .foregroundStyle(selected ? Theme.night : tint)
            }

            Triangle()
                .fill(selected ? tint : tint.opacity(0.8))
                .frame(width: 8, height: 5)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: selected)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Card

@MainActor
private struct BathCard: View {
    let bathroom: Bathroom
    var selected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: bathroom.kind.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.mint)
                Text(bathroom.kind.label)
                    .font(.body(10, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                Spacer()
                if bathroom.amenities.contains(.free) {
                    StatusPill(text: "FREE", color: Theme.lime)
                }
            }

            Text(bathroom.name)
                .font(.display(16, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)

            Text(bathroom.address)
                .font(.body(11))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)

            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.tangerine)
                    Text(bathroom.experienceScore > 0
                         ? String(format: "%.1f", bathroom.experienceScore)
                         : "—")
                        .font(.body(11, weight: .bold))
                        .foregroundStyle(Theme.inkDim)
                }

                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.mint)
                    Text(bathroom.cleanLabel)
                        .font(.body(11, weight: .bold))
                        .foregroundStyle(Theme.mint)
                }

                Spacer()

                Text("\(bathroom.reviewCount) rev")
                    .font(.body(10, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(width: 268, alignment: .leading)
        .glassCard(padding: 13, radius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? Theme.mint : .clear, lineWidth: 1.5)
        )
    }
}
