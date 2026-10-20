import SwiftUI

// MARK: - Poop Social design system
//
// Dark, neon, glossy. Deep navy canvas with mint + bubblegum highlights.
// Everything is rounded, everything springs, nothing is a photo.

enum Theme {

    // MARK: Ink & canvas
    static let night     = Color(hex: 0x060912)
    static let nightSoft = Color(hex: 0x0C1220)
    static let slate     = Color(hex: 0x161E31)
    static let line      = Color.white.opacity(0.10)

    /// Translucent card base. Deliberately navy-tinted: the system's
    /// `.ultraThinMaterial` reads as neutral grey, which desaturates the
    /// palette. This keeps frosted cards inside the navy family.
    static let glass     = Color(hex: 0x1B2438).opacity(0.82)

    // MARK: Accents
    static let mint      = Color(hex: 0x3DE8C8)
    static let teal      = Color(hex: 0x10B5A3)
    static let grape     = Color(hex: 0x8B5CF6)
    static let bubble    = Color(hex: 0xFF6FB5)
    static let tangerine = Color(hex: 0xFFB020)
    static let lime      = Color(hex: 0xB6F24B)
    static let sky       = Color(hex: 0x59C8FA)
    static let danger    = Color(hex: 0xFF5C6C)

    // MARK: Text
    static let ink      = Color.white
    static let inkDim   = Color.white.opacity(0.64)
    static let inkFaint = Color.white.opacity(0.36)

    // MARK: Gradients
    static var hero: LinearGradient {
        LinearGradient(colors: [teal, mint, sky],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var juicy: LinearGradient {
        LinearGradient(colors: [bubble, grape, sky],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var sunset: LinearGradient {
        LinearGradient(colors: [tangerine, bubble, grape],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var canvas: LinearGradient {
        LinearGradient(colors: [night, nightSoft, Color(hex: 0x130E26)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// Five bespoke reel backdrops — chosen by index so reels look distinct.
    static let reelBackdrops: [LinearGradient] = [
        LinearGradient(colors: [Color(hex: 0x0B3B4A), Color(hex: 0x123A6B), Color(hex: 0x2B1247)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(hex: 0x3A0B2E), Color(hex: 0x6B1240), Color(hex: 0x2B1247)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(hex: 0x08301F), Color(hex: 0x0E4A3A), Color(hex: 0x0B2540)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(hex: 0x2A1A05), Color(hex: 0x4A2A08), Color(hex: 0x3A0B2E)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(hex: 0x101033), Color(hex: 0x1E1050), Color(hex: 0x3A0B2E)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    ]

    static func moodGradient(_ score: Int) -> LinearGradient {
        switch score {
        case 5:  return LinearGradient(colors: [lime, mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 4:  return LinearGradient(colors: [mint, sky], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 3:  return LinearGradient(colors: [sky, grape], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2:  return LinearGradient(colors: [tangerine, danger], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [danger, grape], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: Geometry
    static let rSmall: CGFloat = 12
    static let rMedium: CGFloat = 20
    static let rLarge: CGFloat = 28
    static let rPill: CGFloat = 999
    static let gutter: CGFloat = 16
}

// MARK: - Hex
extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue:  Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Typography
extension Font {
    static func display(_ size: CGFloat, weight: Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Card surface
@MainActor
struct GlassSurface: View {
    var tint: Color = .white
    var radius: CGFloat = Theme.rMedium
    var strokeOpacity: Double = 0.22

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            // A *navy-tinted* translucent base rather than the system's
            // `.ultraThinMaterial`. The material renders as neutral grey, which
            // measured out at ~70% of the Home screen's pixels and fought the
            // deep-navy palette; tinting keeps the frosted look on-brand.
            .fill(Theme.glass)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(strokeOpacity), .white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func glassCard(tint: Color = .white,
                   padding: CGFloat = 16,
                   radius: CGFloat = Theme.rMedium) -> some View {
        self
            .padding(padding)
            .background(GlassSurface(tint: tint, radius: radius))
            .shadow(color: .black.opacity(0.32), radius: 16, x: 0, y: 8)
    }

    func neon(_ color: Color, radius: CGFloat = 16, intensity: Double = 0.5) -> some View {
        self.shadow(color: color.opacity(intensity), radius: radius, x: 0, y: radius / 3)
    }

    /// Staggered entrance for lists and grids.
    func popIn(_ index: Int, enabled: Bool = true) -> some View {
        modifier(PopIn(index: index, enabled: enabled))
    }
}

@MainActor
struct PopIn: ViewModifier {
    let index: Int
    let enabled: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || !enabled ? 1 : 0)
            .scaleEffect(shown || !enabled ? 1 : 0.94)
            .offset(y: shown || !enabled ? 0 : 16)
            .animation(
                .spring(response: 0.42, dampingFraction: 0.74)
                    .delay(enabled ? min(Double(index) * 0.05, 0.4) : 0),
                value: shown
            )
            .onAppear { shown = true }
    }
}
