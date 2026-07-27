import SwiftUI
import QuestlyKit

// MARK: - Confettis

struct ConfettiPiece: Identifiable {
    let id: Int
    let hue: Color
    let startX: Double
    let drift: Double
    let delay: Double
    let spin: Double
    let size: Double
    let isCircle: Bool
}

/// Confettis dessinés dans un `Canvas` unique : quelques centaines de formes
/// sans créer une seule vue SwiftUI, donc sans à-coup sur l'animation.
struct ConfettiView: View {
    var pieceCount: Int = 90
    var duration: Double = 2.6
    var colors: [Color] = [
        Color(hex: "FF375F"), Color(hex: "FF9F0A"), Color(hex: "FFD60A"),
        Color(hex: "30D158"), Color(hex: "64D2FF"), Color(hex: "BF5AF2")
    ]
    var onFinished: (() -> Void)?

    @State private var startDate = Date()
    @State private var pieces: [ConfettiPiece] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                for piece in pieces {
                    let local = elapsed - piece.delay
                    guard local > 0 else { continue }
                    let progress = local / duration
                    guard progress < 1 else { continue }

                    // Chute avec accélération douce et dérive latérale.
                    let y = -40 + (size.height + 80) * pow(progress, 1.35)
                    let x = piece.startX * size.width
                        + sin(progress * 6 + piece.spin) * piece.drift
                    let opacity = progress > 0.75 ? (1 - progress) * 4 : 1
                    let rotation = Angle.degrees(progress * 720 * (piece.spin > 3 ? -1 : 1))

                    var layer = context
                    layer.opacity = opacity
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: rotation)

                    let rect = CGRect(
                        x: -piece.size / 2,
                        y: -piece.size / 2,
                        width: piece.size,
                        height: piece.size * (piece.isCircle ? 1 : 0.55)
                    )
                    let path = piece.isCircle
                        ? Path(ellipseIn: rect)
                        : Path(roundedRect: rect, cornerRadius: 1.5)
                    layer.fill(path, with: .color(piece.hue))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            pieces = Self.makePieces(count: pieceCount, colors: colors)
            startDate = Date()
            if let onFinished {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.6, execute: onFinished)
            }
        }
    }

    static func makePieces(count: Int, colors: [Color]) -> [ConfettiPiece] {
        var rng = SeededRandom(seed: UInt64(count) &* 7919 &+ 13)
        return (0..<count).map { index in
            ConfettiPiece(
                id: index,
                hue: colors[Int(rng.next(upperBound: UInt64(colors.count)))],
                startX: rng.nextDouble(),
                drift: 20 + rng.nextDouble() * 70,
                delay: rng.nextDouble() * 0.5,
                spin: rng.nextDouble() * 6.28,
                size: 6 + rng.nextDouble() * 8,
                isCircle: rng.nextDouble() > 0.6
            )
        }
    }
}

// MARK: - Éclat de validation

/// Petite explosion radiale jouée à l'endroit exact où l'on coche une quête.
struct CompletionBurst: View {
    var color: Color
    var particleCount: Int = 14
    var radius: Double = 34
    var duration: Double = 0.6

    @State private var progress: Double = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for index in 0..<particleCount {
                let angle = (Double(index) / Double(particleCount)) * 2 * .pi
                let distance = radius * progress
                let point = CGPoint(
                    x: center.x + cos(angle) * distance,
                    y: center.y + sin(angle) * distance
                )
                let scale = max(0, 1 - progress)
                let dotSize = 5.0 * scale
                var layer = context
                layer.opacity = scale
                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: point.x - dotSize / 2,
                        y: point.y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )),
                    with: .color(color)
                )
            }

            // Onde de choc.
            let ringRadius = radius * progress * 1.1
            var ringLayer = context
            ringLayer.opacity = max(0, 0.5 - progress * 0.5)
            ringLayer.stroke(
                Path(ellipseIn: CGRect(
                    x: center.x - ringRadius,
                    y: center.y - ringRadius,
                    width: ringRadius * 2,
                    height: ringRadius * 2
                )),
                with: .color(color),
                lineWidth: 2
            )
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: duration)) { progress = 1 }
        }
    }
}

// MARK: - Texte flottant

/// « +42 XP » qui s'envole depuis la ligne validée.
struct FloatingXPText: View {
    let amount: Int
    var color: Color = Color(hex: "FFD60A")

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Text("+\(amount) XP")
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .glow(color, radius: 8, opacity: 0.7)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    offset = -44
                    opacity = 0
                }
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Halo pulsant

/// Attire l'œil sur un élément sans l'agiter — utilisé pour la quête du jour.
struct PulsingHalo: View {
    var color: Color
    var size: CGFloat = 60

    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.5), lineWidth: 2)
                .scaleEffect(animate ? 1.35 : 1)
                .opacity(animate ? 0 : 0.8)
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 1.5)
                .scaleEffect(animate ? 1.6 : 1)
                .opacity(animate ? 0 : 0.5)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.9).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Effet de rayons

/// Rayons de lumière derrière une montée de niveau.
struct RadiantBurst: View {
    var color: Color
    var rayCount: Int = 16

    @State private var rotation: Double = 0
    @State private var scale: Double = 0.6

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) * 0.75 * scale
            for index in 0..<rayCount {
                let angle = (Double(index) / Double(rayCount)) * 2 * .pi + rotation
                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(
                    x: center.x + cos(angle - 0.04) * maxRadius,
                    y: center.y + sin(angle - 0.04) * maxRadius
                ))
                path.addLine(to: CGPoint(
                    x: center.x + cos(angle + 0.04) * maxRadius,
                    y: center.y + sin(angle + 0.04) * maxRadius
                ))
                path.closeSubpath()
                context.fill(path, with: .color(color.opacity(0.28)))
            }
        }
        .blur(radius: 6)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                rotation = .pi * 2
            }
            withAnimation(.easeOut(duration: 0.8)) { scale = 1 }
        }
    }
}
