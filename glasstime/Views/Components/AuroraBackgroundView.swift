import SwiftUI

struct AuroraBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let palette = AuroraPalette.focus

    var body: some View {
        if reduceMotion {
            staticAurora
        } else {
            animatedAurora
        }
    }

    // MARK: - Animated

    private var animatedAurora: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: scenePhase != .active)) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            Canvas { canvasContext, size in
                // === Layer 1 (deepest): Base gradient ===
                // Full cycle ~10s — visible, slow drift
                let base1 = blobPosition(
                    time: time,
                    xFreq: 0.15, yFreq: 0.12,
                    xPhase: 0, yPhase: 0.8,
                    drift: 0.35,
                    size: size
                )

                // === Layer 2 (mid): Moving light — the main aurora ===
                // Full cycle ~6-8s — clearly alive, easy to notice
                let mid1 = blobPosition(
                    time: time,
                    xFreq: 0.22, yFreq: 0.18,
                    xPhase: 1.2, yPhase: 2.5,
                    drift: 0.42,
                    size: size
                )
                let mid2 = blobPosition(
                    time: time,
                    xFreq: 0.18, yFreq: 0.24,
                    xPhase: 3.8, yPhase: 0.7,
                    drift: 0.40,
                    size: size
                )

                // === Layer 3 (top): Light wash — most movement ===
                // Full cycle ~5-6s — noticeable parallax
                let top1 = blobPosition(
                    time: time,
                    xFreq: 0.28, yFreq: 0.20,
                    xPhase: 5.1, yPhase: 3.2,
                    drift: 0.38,
                    size: size
                )

                let startRadius: CGFloat = 60
                let endRadius: CGFloat = max(size.width, size.height) * 0.7

                // Color breathing — full cycle ~12s, clearly visible
                let breath = sin(time * 0.13) * 0.15

                // --- Base fill ---
                canvasContext.drawLayer { ctx in
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .color(palette.background)
                    )
                }

                // --- Layer 1: Deep base gradient ---
                canvasContext.drawLayer { ctx in
                    let gradient = Gradient(colors: [
                        palette.blob2.opacity(0.70 + breath),
                        palette.blob2.opacity(0.0)
                    ])
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .radialGradient(
                            gradient,
                            center: base1,
                            startRadius: startRadius,
                            endRadius: endRadius * 1.1
                        )
                    )
                }

                // --- Layer 2a: Mid aurora — soft blue ---
                canvasContext.drawLayer { ctx in
                    let gradient = Gradient(colors: [
                        palette.blob1.opacity(0.90),
                        palette.blob1.opacity(0.0)
                    ])
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .radialGradient(
                            gradient,
                            center: mid1,
                            startRadius: startRadius,
                            endRadius: endRadius
                        )
                    )
                }

                // --- Layer 2b: Mid aurora — green touch ---
                canvasContext.drawLayer { ctx in
                    ctx.blendMode = .softLight
                    let gradient = Gradient(colors: [
                        palette.blob3.opacity(0.80 - breath),
                        palette.blob3.opacity(0.0)
                    ])
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .radialGradient(
                            gradient,
                            center: mid2,
                            startRadius: startRadius,
                            endRadius: endRadius * 0.9
                        )
                    )
                }

                // --- Layer 3: Top light wash — most movement ---
                canvasContext.drawLayer { ctx in
                    ctx.blendMode = .softLight
                    let gradient = Gradient(colors: [
                        palette.blob1.opacity(0.50 + breath),
                        palette.blob1.opacity(0.0)
                    ])
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .radialGradient(
                            gradient,
                            center: top1,
                            startRadius: startRadius * 0.5,
                            endRadius: endRadius * 0.65
                        )
                    )
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Static (Reduce Motion)

    private var staticAurora: some View {
        ZStack {
            palette.background

            RadialGradient(
                colors: [palette.blob2.opacity(0.50), palette.blob2.opacity(0.0)],
                center: .init(x: 0.5, y: 0.4),
                startRadius: 60,
                endRadius: 350
            )

            RadialGradient(
                colors: [palette.blob1.opacity(0.75), palette.blob1.opacity(0.0)],
                center: .init(x: 0.4, y: 0.35),
                startRadius: 60,
                endRadius: 300
            )

            RadialGradient(
                colors: [palette.blob3.opacity(0.55), palette.blob3.opacity(0.0)],
                center: .init(x: 0.65, y: 0.65),
                startRadius: 60,
                endRadius: 280
            )
            .blendMode(.softLight)
        }
        .ignoresSafeArea()
    }

    // MARK: - Helpers

    private func blobPosition(
        time: TimeInterval,
        xFreq: Double, yFreq: Double,
        xPhase: Double, yPhase: Double,
        drift: Double,
        size: CGSize
    ) -> CGPoint {
        let x = (sin(time * xFreq + xPhase) * drift + 0.5) * size.width
        let y = (cos(time * yFreq + yPhase) * drift + 0.45) * size.height
        return CGPoint(x: x, y: y)
    }
}

#Preview {
    AuroraBackgroundView()
}
