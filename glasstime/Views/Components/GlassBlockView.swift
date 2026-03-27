import SwiftUI

struct GlassBlockView: View {
    let block: GlassBlock
    let isMaterialized: Bool
    var showHighlightFlash: Bool = false
    var isBouncing: Bool = false

    private let cr: CGFloat = AppSize.blockCornerRadius

    // Directional light: top-left = brighter, bottom-right = deeper
    private var directionalLight: Double {
        let dx = block.horizontalPosition
        let dy = 1.0 - block.verticalPosition
        let distFromLight = sqrt(dx * dx + dy * dy) / sqrt(2.0)
        return 0.04 - distFromLight * 0.07
    }

    // Edge fade: top dissolves, laterals soften, circle zone clears
    private var edgeFade: Double {
        var fade = 1.0

        if block.verticalPosition > 0.60 {
            let t = (block.verticalPosition - 0.60) / 0.40
            fade *= 1.0 - t * 0.98 // stronger fade compensates for removed blur
        }

        let hDist = abs(block.horizontalPosition - 0.5) * 2
        if hDist > 0.80 {
            let t = (hDist - 0.80) / 0.20
            fade *= 1.0 - t * 0.5
        }

        let ringRadius: Double = Double(AppSize.nucleusRing) / 2
        let fadeStart = ringRadius + 40
        let fadeEnd = ringRadius - 5
        let dist = block.distanceFromCenter
        if dist < fadeStart {
            if dist < fadeEnd {
                fade *= 0.35
            } else {
                let t = (fadeStart - dist) / (fadeStart - fadeEnd)
                fade *= 1.0 - t * 0.65
            }
        }

        return fade
    }

    var body: some View {
        ZStack {
            // Layer 1: Base glass fill — opacity varies per block
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(Color.glassBlockFill.opacity(block.opacityVariation))

            // Layer 2: Top-left specular highlight
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.35), location: 0.0),
                            .init(color: Color.white.opacity(0.12), location: 0.25),
                            .init(color: .clear, location: 0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Layer 3: Bottom-right inner shadow
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.45),
                            .init(color: Color.black.opacity(0.12), location: 0.78),
                            .init(color: Color.black.opacity(0.18), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Layer 4: Top edge specular line
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.40), location: 0.0),
                            .init(color: .clear, location: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Layer 5: Bevel border
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.50), location: 0.0),
                            .init(color: Color.white.opacity(0.15), location: 0.4),
                            .init(color: Color.white.opacity(0.05), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            // Layer 6: Highlight flash on materialization
            if showHighlightFlash {
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(Color.white.opacity(0.20))
            }
        }
        .frame(width: block.size.width, height: block.size.height)
        .brightness(block.brightnessVariation + directionalLight + (isBouncing ? 0.06 : 0))
        .saturation(block.saturationVariation)
        .opacity(isMaterialized ? edgeFade : 0.0)
        .scaleEffect(isBouncing ? 0.88 : (isMaterialized ? 1.0 : 0.92))
    }
}
