import SwiftUI

struct NucleusRingView: View {
    let timeDisplay: String
    let label: String
    let headerText: String
    let timerState: TimerState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pausePulse = false
    @State private var completionPulse = false
    @State private var startBreathe = false
    @State private var tapBounce = false
    @State private var tapHaptic = 0
    @State private var minutePulse = false

    private let ringSize = AppSize.nucleusRing

    // Adaptive glass tint — deep teal, premium weight
    private let glassTint = Color(
        light: Color(red: 0.32, green: 0.52, blue: 0.62),
        dark: Color(red: 0.50, green: 0.72, blue: 0.82)
    )

    var body: some View {
        ZStack {
            // Layer 0: Outer glow — pulses briefly on completion
            Circle()
                .fill(glassTint.opacity(completionPulse ? 0.30 : (timerState == .completed ? 0.20 : 0.14)))
                .frame(width: ringSize + (completionPulse ? 70 : 60), height: ringSize + (completionPulse ? 70 : 60))
                .blur(radius: completionPulse ? 45 : 40)

            // Layer 0b: Dark halo — stronger separation from blocks
            Circle()
                .fill(Color.black.opacity(0.14))
                .frame(width: ringSize + 30, height: ringSize + 30)
                .blur(radius: 20)

            // Layer 0c: Lens refraction — real magnification distortion
            // A scaled-up tinted circle clipped to the ring creates the illusion
            // of content being "bent" through curved glass
            ZStack {
                // Magnified background layer — scaled 1.06x = lens magnification
                Circle()
                    .fill(glassTint.opacity(0.10))
                    .frame(width: ringSize, height: ringSize)
                    .scaleEffect(1.06)

                // Chromatic offset — slight color split like real lens edges
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color.blue.opacity(0.04), location: 0.6),
                                .init(color: Color.cyan.opacity(0.06), location: 0.85),
                                .init(color: .clear, location: 1.0)
                            ],
                            center: .center,
                            startRadius: ringSize * 0.3,
                            endRadius: ringSize * 0.5
                        )
                    )
                    .frame(width: ringSize, height: ringSize)

                // Offset refraction rings — simulate light bending at edges
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: ringSize - 6, height: ringSize - 6)
                    .offset(x: -3, y: -4)
                    .blur(radius: 4)

                Circle()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: ringSize * 0.5, height: ringSize * 0.5)
                    .offset(x: 2, y: 3)
                    .blur(radius: 6)
            }
            .clipShape(Circle())
            .frame(width: ringSize, height: ringSize)

            // Caustic highlight: concentrated light spot from refraction
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.10), .clear],
                        center: .init(x: 0.38, y: 0.33),
                        startRadius: 0,
                        endRadius: ringSize * 0.35
                    )
                )
                .frame(width: ringSize, height: ringSize)

            // Layer 1: Frosted glass base — strong enough to support white text
            Circle()
                .fill(glassTint.opacity(timerState == .completed ? 0.30 : 0.26))
                .frame(width: ringSize, height: ringSize)
                .blur(radius: timerState == .completed ? 5 : 3)

            // Layer 1b: White overlay — glass brightness
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: ringSize, height: ringSize)

            // Layer 2: Top-to-bottom gradient — glass volume
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.14), location: 0.0),
                            .init(color: Color.white.opacity(0.04), location: 0.45),
                            .init(color: Color.black.opacity(0.06), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: ringSize, height: ringSize)

            // Layer 3: Highlight (top-left light source)
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.22), location: 0.0),
                            .init(color: Color.white.opacity(0.06), location: 0.4),
                            .init(color: .clear, location: 0.8)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: ringSize * 0.8
                    )
                )
                .frame(width: ringSize, height: ringSize)

            // Layer 4: Inner shadow (curvature)
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: .clear, location: 0.5),
                            .init(color: Color.black.opacity(0.05), location: 0.8),
                            .init(color: Color.black.opacity(0.10), location: 1.0)
                        ],
                        center: .topLeading,
                        startRadius: ringSize * 0.3,
                        endRadius: ringSize * 0.5
                    )
                )
                .frame(width: ringSize, height: ringSize)

            // Layer 5: Lens border — angular light distribution like real glass
            Circle()
                .stroke(
                    AngularGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.40), location: 0.0),   // top
                            .init(color: Color.white.opacity(0.50), location: 0.12),  // top-right highlight
                            .init(color: Color.white.opacity(0.15), location: 0.30),  // right
                            .init(color: Color.white.opacity(0.04), location: 0.50),  // bottom
                            .init(color: Color.white.opacity(0.03), location: 0.70),  // left-bottom
                            .init(color: Color.white.opacity(0.20), location: 0.88),  // left
                            .init(color: Color.white.opacity(0.40), location: 1.0)    // back to top
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    lineWidth: 0.75
                )
                .frame(width: ringSize, height: ringSize)

            // Content — adaptive contrast: dark text on light glass, white on dark
            VStack(spacing: Spacing.xs) {
                // STAY FOCUSED — whisper
                Text(headerText)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.onGlassTertiary)
                    .textCase(.uppercase)
                    .tracking(3.5)

                if timerState == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color.onGlassPrimary)
                        .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating)
                } else {
                    // TIME — the protagonist, always legible
                    Text(timeDisplay)
                        .font(AppFont.timerDisplay)
                        .foregroundStyle(Color.onGlassPrimary)
                        .contentTransition(.numericText())
                        .scaleEffect(minutePulse ? 1.05 : 1.0)
                }

                // FOCUS / START — secondary
                Text(label)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.onGlassSecondary)
                    .textCase(.uppercase)
                    .tracking(2.0)
            }
            .opacity(timerState == .paused ? (pausePulse ? 0.6 : 1.0) : 1.0)
        }
        // Press-in effect: compress on touch down, spring back on release
        .scaleEffect(tapBounce ? 0.93 : (startBreathe ? 1.03 : 1.0))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !tapBounce, !reduceMotion else { return }
                    tapHaptic += 1
                    withAnimation(.spring(.snappy(duration: 0.15))) {
                        tapBounce = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(.bouncy(duration: 0.4, extraBounce: 0.15))) {
                        tapBounce = false
                    }
                }
        )
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.7), trigger: tapHaptic)
        .shadow(
            color: Color.black.opacity(timerState == .completed ? 0.18 : 0.12),
            radius: timerState == .completed ? 30 : 20,
            x: 0,
            y: timerState == .completed ? 10 : 8
        )
        // Heartbeat: micro pulse every minute boundary
        .onChange(of: timeDisplay) { _, newDisplay in
            guard timerState == .running, !reduceMotion else { return }
            if newDisplay.hasSuffix(":00") {
                Task { @MainActor in
                    withAnimation(.spring(.bouncy(duration: 0.2))) {
                        minutePulse = true
                    }
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation(.spring(.smooth(duration: 0.6))) {
                        minutePulse = false
                    }
                }
            }
        }
        .onChange(of: timerState) { _, newState in
            if newState == .paused && !reduceMotion {
                withAnimation(.spring(.smooth(duration: 2.0)).repeatForever(autoreverses: true)) {
                    pausePulse = true
                }
            } else {
                // Kill the .repeatForever() transaction before re-animating
                withAnimation(nil) { pausePulse = false }
            }

            // Completion: brief glow pulse then settle
            if newState == .completed {
                Task { @MainActor in
                    withAnimation(.spring(.smooth(duration: 0.6))) {
                        completionPulse = true
                    }
                    try? await Task.sleep(for: .seconds(1))
                    withAnimation(.spring(.smooth(duration: 1.2))) {
                        completionPulse = false
                    }
                }
            }

            // Idle → Running: breathe — a moment of intentionality
            if newState == .running && !reduceMotion {
                Task { @MainActor in
                    withAnimation(.spring(.smooth(duration: 0.3))) {
                        startBreathe = true
                    }
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(.spring(.smooth(duration: 0.5))) {
                        startBreathe = false
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        AuroraBackgroundView()
        NucleusRingView(
            timeDisplay: "25:00",
            label: String(localized: "timer.start"),
            headerText: String(localized: "stay.focused"),
            timerState: .idle
        )
    }
}
