import SwiftUI

struct FocusSessionView: View {
    @State private var viewModel: TimerViewModel
    @State private var circleVisible = false
    @State private var controlsVisible = false
    @Environment(\.scenePhase) private var scenePhase

    init(services: AppServices) {
        let vm = TimerViewModel(services: services)
        _viewModel = State(initialValue: vm)
        TimerIntentHandler.shared.viewModel = vm
    }

    var body: some View {
        GeometryReader { geo in
            // Block area = FULL SCREEN — blocks fill the entire surface
            let blockArea = CGRect(
                x: 0,
                y: 0,
                width: geo.size.width,
                height: geo.size.height
            )

            ZStack {
                // Layer 1: Aurora background (deepest — always visible through glass)
                AuroraBackgroundView()

                // Layer 2: Glass blocks (full screen grid)
                if viewModel.timerState != .idle {
                    GlassBlocksView(
                        blocks: viewModel.blocks,
                        progress: viewModel.progress,
                        isComplete: viewModel.timerState == .completed,
                        isDismissing: viewModel.timerState == .dismissing,
                        screenCenter: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    )
                    .transition(.opacity.animation(.spring(.smooth(duration: 0.8))))
                    .onAppear {
                        if geo.size != .zero {
                            viewModel.generateBlocks(for: geo.size, blockArea: blockArea)
                        }
                    }
                    .onChange(of: geo.size) { _, newSize in
                        if newSize != .zero {
                            viewModel.generateBlocks(for: newSize, blockArea: blockArea)
                        }
                    }
                }

                // Layer 3: Circle — dead center, cascading entrance
                NucleusRingView(
                    timeDisplay: viewModel.ringTimeDisplay,
                    label: viewModel.ringLabel,
                    headerText: String(localized: "stay.focused"),
                    timerState: viewModel.timerState
                )
                .opacity(circleVisible ? 1 : 0)
                .scaleEffect(circleVisible ? 1.0 : 0.92)

                // Layer 4: Controls pinned to bottom, cascading entrance
                VStack {
                    Spacer()
                    BottomControlsView(
                        timerState: viewModel.timerState,
                        selectedMinutes: viewModel.selectedDurationMinutes,
                        onSelectDuration: { viewModel.selectDuration($0) },
                        onPrimaryAction: { viewModel.primaryAction() },
                        onEnd: { viewModel.endSession() }
                    )
                    .padding(.bottom, Spacing.xxl)
                }
                .opacity(controlsVisible ? 1 : 0)
                .offset(y: controlsVisible ? 0 : 20)

                // Layer 4: Very subtle grain texture (anti-flat)
                GrainOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .animation(.spring(.smooth(duration: 0.8)), value: viewModel.timerState)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            viewModel.trackAppOpened()

            // Staggered entrance cascade
            withAnimation(.spring(.smooth(duration: 0.7))) {
                circleVisible = true
            }
            withAnimation(.spring(.smooth(duration: 0.6)).delay(0.15)) {
                controlsVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .timerCompletedFromNotification)) { _ in
            // User tapped the completion notification — ensure session is completed
            if viewModel.timerState == .running || viewModel.timerState == .paused {
                viewModel.handleReturnToForeground()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            print("🔄 ScenePhase: \(oldPhase) → \(newPhase), timerState=\(viewModel.timerState), elapsed=\(viewModel.elapsedSeconds)")
            switch newPhase {
            case .background:
                viewModel.handleEnteredBackground()
                viewModel.trackAppBackgrounded()
            case .active:
                viewModel.handleReturnToForeground()
                print("🔄 After foreground: timerState=\(viewModel.timerState), elapsed=\(viewModel.elapsedSeconds), remaining=\(viewModel.remainingSeconds)")
            case .inactive:
                print("🔄 Inactive — no action taken")
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Grain Overlay (rendered once, not per-frame)

struct GrainOverlay: View {
    @State private var grainImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            if let grainImage {
                Image(uiImage: grainImage)
                    .resizable()
                    .ignoresSafeArea()
            }
        }
        .opacity(0.04)
        .blendMode(.overlay)
        .allowsHitTesting(false)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            if grainImage == nil && size.width > 0 {
                grainImage = Self.generateGrain(
                    width: Int(size.width),
                    height: Int(size.height)
                )
            }
        }
    }

    /// Generates a static grain texture UIImage — called once, never re-rendered
    private static func generateGrain(width: Int, height: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            // Seeded RNG for deterministic pattern
            var rng = GrainRNG(seed: 42)
            let dotCount = Int(Double(width * height) * 0.008)

            for _ in 0..<dotCount {
                let x = CGFloat.random(in: 0..<CGFloat(width), using: &rng)
                let y = CGFloat.random(in: 0..<CGFloat(height), using: &rng)
                let s = CGFloat.random(in: 0.5...1.5, using: &rng)
                let opacity = CGFloat.random(in: 0.3...0.8, using: &rng)

                cgCtx.setFillColor(UIColor.white.withAlphaComponent(opacity).cgColor)
                cgCtx.fillEllipse(in: CGRect(x: x, y: y, width: s, height: s))
            }
        }
    }

    /// Simple seeded RNG for deterministic grain
    private struct GrainRNG: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
            z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }
    }
}

#Preview {
    FocusSessionView(services: .preview)
}
