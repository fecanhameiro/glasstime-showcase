import SwiftUI

struct BottomControlsView: View {
    let timerState: TimerState
    let selectedMinutes: Int
    let onSelectDuration: (Int) -> Void
    let onPrimaryAction: () -> Void
    let onEnd: () -> Void

    @Namespace private var controlsNS
    @State private var selectionHaptic = 0
    @State private var abandonHaptic = 0
    #if DEBUG
    private let presets = [15, 30, 60, 300] // seconds in debug
    #else
    private let presets = [15, 25, 45, 60]  // minutes in production
    #endif

    var body: some View {
        GlassEffectContainer(spacing: Spacing.sm) {
            Group {
                switch timerState {
                case .idle:
                    idleControls
                case .running:
                    runningControls
                case .paused:
                    pausedControls
                case .completed:
                    completedControls
                case .dismissing:
                    EmptyView()
                }
            }
        }
        .animation(.spring(.smooth(duration: 0.9)), value: timerState)
        .sensoryFeedback(.impact(weight: .medium), trigger: timerState)
        .sensoryFeedback(.selection, trigger: selectionHaptic)
        .sensoryFeedback(.impact(weight: .heavy), trigger: abandonHaptic)
    }

    // MARK: - States

    @ViewBuilder
    private var idleControls: some View {
        HStack(spacing: Spacing.md) {
            ForEach(presets, id: \.self) { minutes in
                Button {
                    selectionHaptic += 1
                    onSelectDuration(minutes)
                    onPrimaryAction()
                } label: {
                    Text(presetLabel(minutes))
                        .font(AppFont.durationPreset)
                        .foregroundStyle(Color.onGlassPrimary)
                        .frame(width: AppSize.durationPill, height: AppSize.durationPill)
                }
                .glassEffect(
                    .regular.tint(Color.glassTintRing.opacity(0.45)).interactive(),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .glassEffectID("pill-\(minutes)", in: controlsNS)
            }
        }
    }

    @ViewBuilder
    private var runningControls: some View {
        Button {
            onPrimaryAction()
        } label: {
            Label(String(localized: "timer.pause"), systemImage: "pause.fill")
                .font(.body.weight(.regular))
                .foregroundStyle(Color.onGlassButton)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
        }
        .glassEffect(
            .regular.tint(Color.glassTintRing.opacity(0.40)).interactive(),
            in: .capsule
        )
        .glassEffectID("primary-action", in: controlsNS)
    }

    @ViewBuilder
    private var pausedControls: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                abandonHaptic += 1
                onEnd()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(
                .regular.tint(Color.red.opacity(0.30)).interactive(),
                in: .circle
            )
            .glassEffectID("end-action", in: controlsNS)

            Button {
                onPrimaryAction()
            } label: {
                Label(String(localized: "timer.resume"), systemImage: "play.fill")
                    .font(.body.weight(.regular))
                    .foregroundStyle(Color.onGlassButton)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
            }
            .glassEffect(
                .regular.tint(Color.glassTintRing.opacity(0.40)).interactive(),
                in: .capsule
            )
            .glassEffectID("primary-action", in: controlsNS)
        }
    }

    @ViewBuilder
    private var completedControls: some View {
        Button {
            onPrimaryAction()
        } label: {
            Label(String(localized: "timer.done"), systemImage: "checkmark")
                .font(.body.weight(.regular))
                .foregroundStyle(Color.onGlassButton)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
        }
        .glassEffect(
            .regular.tint(Color.glassTintRing.opacity(0.40)).interactive(),
            in: .capsule
        )
        .glassEffectID("primary-action", in: controlsNS)
    }
    private func presetLabel(_ value: Int) -> String {
        #if DEBUG
        if value >= 60 {
            return "\(value / 60)m"
        } else {
            return "\(value)s"
        }
        #else
        return "\(value)"
        #endif
    }
}

#Preview {
    ZStack {
        AuroraBackgroundView()
        VStack {
            Spacer()
            BottomControlsView(
                timerState: .idle,
                selectedMinutes: 25,
                onSelectDuration: { _ in },
                onPrimaryAction: {},
                onEnd: {}
            )
            .padding(.bottom, Spacing.xl)
        }
    }
}
