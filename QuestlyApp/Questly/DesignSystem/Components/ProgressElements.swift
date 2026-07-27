import SwiftUI
import QuestlyKit

// MARK: - Barre d'XP

/// Barre d'expérience avec reflet et remplissage animé.
struct XPBar: View {
    let progress: LevelProgress
    var height: CGFloat = 12
    var showsLabels: Bool = true

    @Environment(\.questlyTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))

                    Capsule()
                        .fill(theme.gradient)
                        .frame(width: max(height, geo.size.width * progress.fraction))
                        .overlay(alignment: .trailing) {
                            Circle()
                                .fill(.white.opacity(0.85))
                                .frame(width: height * 0.5, height: height * 0.5)
                                .padding(.trailing, height * 0.25)
                                .blur(radius: 0.5)
                        }
                        .glow(theme.accent, radius: 8, opacity: 0.55)
                }
            }
            .frame(height: height)
            .animation(Motion.gentle, value: progress.fraction)

            if showsLabels {
                HStack {
                    Text("Niv. \(progress.level)")
                        .font(.questCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(progress.xpIntoLevel) / \(progress.xpRequiredForLevel) XP")
                        .font(.questCaption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Anneau de niveau

/// L'avatar du héros dans un anneau de progression : c'est la pièce
/// d'identité de l'app, présente sur presque tous les écrans.
struct LevelRing: View {
    let progress: LevelProgress
    var size: CGFloat = 74
    var lineWidth: CGFloat = 6
    var emoji: String = "🧭"
    var showsLevelBadge: Bool = true

    @Environment(\.questlyTheme) private var theme

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.001, progress.fraction))
                .stroke(
                    theme.ringGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .glow(theme.accent, radius: 6, opacity: 0.5)
                .animation(Motion.gentle, value: progress.fraction)

            Circle()
                .fill(.ultraThinMaterial)
                .padding(lineWidth + 3)

            Text(emoji)
                .font(.system(size: size * 0.42))
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottom) {
            if showsLevelBadge {
                Text("\(progress.level)")
                    .font(.questMicro)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background {
                        Capsule().fill(theme.gradient)
                    }
                    .overlay {
                        Capsule().strokeBorder(Color(.systemBackground), lineWidth: 1.5)
                    }
                    .offset(y: 6)
            }
        }
    }
}

// MARK: - Anneau générique

struct ProgressRing: View {
    let fraction: Double
    var size: CGFloat = 44
    var lineWidth: CGFloat = 5
    var color: Color = .accentColor
    var trackOpacity: Double = 0.12
    var content: AnyView?

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.gentle, value: fraction)
            if let content {
                content
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Flamme de série

/// La flamme grossit et change de teinte avec la série. En danger, elle pulse.
struct StreakFlame: View {
    let days: Int
    var isAtRisk: Bool = false
    var size: CGFloat = 22

    @State private var pulse = false

    private var tint: Color {
        switch days {
        case 0: return .gray
        case 1...6: return Color(hex: "FFB020")
        case 7...29: return Color(hex: "FF7A00")
        case 30...99: return Color(hex: "FF3B30")
        default: return Color(hex: "BF5AF2")
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: days > 0 ? "flame.fill" : "flame")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.6)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .glow(tint, radius: days > 0 ? 8 : 0, opacity: 0.7)
                .scaleEffect(pulse ? 1.12 : 1)
                .animation(
                    isAtRisk
                        ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                        : Motion.snappy,
                    value: pulse
                )

            Text("\(days)")
                .font(.questNumber(size * 0.8))
                .foregroundStyle(tint)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .onAppear { pulse = isAtRisk }
        .onChange(of: isAtRisk) { _, newValue in pulse = newValue }
        .accessibilityLabel("Série de \(days) jours")
    }
}

// MARK: - Courbe compacte

/// Mini-courbe sans axes, pour glisser une tendance dans une carte.
struct Sparkline: View {
    let values: [Double]
    var color: Color = .accentColor
    var fills: Bool = true

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            ZStack {
                if fills, points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        for point in points { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.35), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let maxValue = values.max() ?? 1
        let minValue = values.min() ?? 0
        let range = max(0.0001, maxValue - minValue)
        let stepX = size.width / CGFloat(values.count - 1)

        return values.enumerated().map { index, value in
            let ratio = (value - minValue) / range
            return CGPoint(
                x: CGFloat(index) * stepX,
                y: size.height - CGFloat(ratio) * size.height
            )
        }
    }
}

// MARK: - Barre de vie du boss

/// Barre de PV segmentée, façon jeu de rôle.
struct BossHealthBar: View {
    let fraction: Double
    let remainingMinutes: Int
    var height: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(Color.black.opacity(0.25))

                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: fraction > 0.35
                                    ? [Color(hex: "FF453A"), Color(hex: "FF9F0A")]
                                    : [Color(hex: "FF453A"), Color(hex: "FF2D55")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * fraction))
                        .animation(Motion.gentle, value: fraction)

                    // Encoches tous les 10 %.
                    HStack(spacing: 0) {
                        ForEach(0..<10, id: \.self) { index in
                            Rectangle()
                                .fill(Color.black.opacity(index == 9 ? 0 : 0.25))
                                .frame(width: 1)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }
            .frame(height: height)

            Text(remainingMinutes > 0 ? "\(remainingMinutes) PV restants" : "Boss vaincu")
                .font(.questMicro)
                .foregroundStyle(.secondary)
        }
    }
}
