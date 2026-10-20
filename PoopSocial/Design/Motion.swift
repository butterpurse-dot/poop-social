import SwiftUI

// MARK: - Motion primitives
// Small, dependency-free animation building blocks. Everything here is
// Core Animation or Canvas work — no timers driving the view tree on idle.

/// Springy press feedback used by every tappable surface in the app.
///
/// `ButtonStyle.makeBody` is a *nonisolated* protocol requirement, so the type
/// must not be actor-isolated. The only main-actor work here is the haptic,
/// which is dispatched explicitly.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    var haptic: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.62), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                guard pressed, haptic else { return }
                Task { @MainActor in Haptics.tick() }
            }
    }
}

/// Soft floating bubbles behind a screen. Pure gradients (no blur) so it stays cheap.
@MainActor
struct BubbleBackdrop: View {
    var tint: Color = Theme.mint
    var secondary: Color = Theme.grape
    var count: Int = 6

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    Bubble(index: i, bounds: geo.size, tint: i.isMultiple(of: 2) ? tint : secondary)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

@MainActor
private struct Bubble: View {
    let index: Int
    let bounds: CGSize
    let tint: Color

    @State private var drift = false

    private var diameter: CGFloat { 150 + CGFloat((index * 67) % 190) }
    private var x: CGFloat { frac(index, 1) * bounds.width }
    private var y: CGFloat { frac(index, 2) * bounds.height }
    private var rise: CGFloat { 26 + frac(index, 3) * 44 }
    private var duration: Double { 7 + Double(index % 5) }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [tint.opacity(0.30), tint.opacity(0.06), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
            .position(x: x, y: y)
            .offset(y: drift ? -rise : rise * 0.35)
            .animation(
                .easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: drift
            )
            .onAppear { drift = true }
    }

    private func frac(_ a: Int, _ b: Int) -> CGFloat {
        let v = Double((a &* 7919 &+ b &* 104729) % 997) / 997.0
        return CGFloat(v)
    }
}

/// Emoji confetti. Fires only on `trigger` change and stops itself, so it costs nothing at rest.
@MainActor
struct EmojiBurst: View {
    let emojis: [String]
    let trigger: Int
    var origin: UnitPoint = .center

    @State private var start: Date?
    @State private var active = false

    var body: some View {
        GeometryReader { _ in
            if active, let start {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { ctx, size in
                        let elapsed = timeline.date.timeIntervalSince(start)
                        let life: Double = 1.15
                        guard elapsed < life else { return }
                        let p = elapsed / life
                        let eased = 1 - pow(1 - p, 3)

                        for (i, emoji) in emojis.enumerated() {
                            let angle = (Double(i) / Double(max(emojis.count, 1))) * .pi * 2 + 0.35
                            let spread = 100.0 + Double((i * 41) % 90)
                            let dx = cos(angle) * spread * eased
                            let dy = sin(angle) * spread * eased - 44 * p
                            let scale = 0.65 + 0.75 * (1 - p)

                            ctx.opacity = max(0, 1 - p * p)
                            let text = ctx.resolve(
                                Text(emoji).font(.system(size: 27 * scale))
                            )
                            let point = CGPoint(
                                x: size.width * origin.x + dx,
                                y: size.height * origin.y + dy
                            )
                            ctx.draw(text, at: point, anchor: .center)
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in fire() }
    }

    private func fire() {
        start = Date()
        active = true
        Task {
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            active = false
        }
    }
}

/// Number that rolls when it changes.
@MainActor
struct AnimatedNumber: View {
    let value: Int
    var font: Font = .display(17, weight: .heavy)
    var color: Color = Theme.ink

    var body: some View {
        Text("\(value)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(value)))
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: value)
    }
}

/// Gentle breathing halo — used behind the active tab and live indicators.
@MainActor
struct PulseHalo: View {
    var color: Color = Theme.mint
    var size: CGFloat = 42
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.28))
            .frame(width: size, height: size)
            .scaleEffect(pulse ? 1.18 : 0.86)
            .opacity(pulse ? 0.15 : 0.6)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

/// A tiny live-dot used in headers ("3 crew online").
@MainActor
struct LiveDot: View {
    var color: Color = Theme.mint
    @State private var on = false
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 3).scaleEffect(on ? 2.2 : 1).opacity(on ? 0 : 1))
            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: on)
            .onAppear { on = true }
    }
}
