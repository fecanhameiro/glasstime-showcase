import SwiftUI
import os.log

private let blockLogger = Logger(subsystem: "com.glasstime", category: "Blocks")

struct GlassBlocksView: View {
    let blocks: [GlassBlock]
    let progress: Double
    let isComplete: Bool
    let isDismissing: Bool
    let screenCenter: CGPoint

    @State private var materializedIDs: Set<Int> = []
    @State private var flashingIDs: Set<Int> = []
    @State private var waveReachedIDs: Set<Int> = []
    @State private var bouncingIDs: Set<Int> = []
    @State private var completionSettle = false
    @State private var lastMilestone = 0
    @State private var hapticTrigger = 0
    @State private var completionHaptic = 0
    @State private var milestoneHaptic = 0
    @State private var lastBouncedID: Int? = nil
    @State private var lastBounceHapticTime: Date = .distantPast

    // Stored tasks for cancellation
    @State private var waveTask: Task<Void, Never>?
    @State private var dissolveTask: Task<Void, Never>?

    // Only render blocks that need to be on screen:
    // - materialized AND within screen bounds (skip off-screen overflow blocks)
    // - about to materialize in the next ~3 ticks (small look-ahead for smooth entrance)
    private var visibleBlocks: [GlassBlock] {
        let lookAhead = progress + 0.015 // ~3 blocks ahead, not 5%
        return blocks.filter { block in
            if materializedIDs.contains(block.id) {
                // Skip off-screen blocks even if materialized
                return block.edgeFadeOpacity > 0.02
            }
            return block.materializedAt <= lookAhead
        }
    }

    var body: some View {
        ZStack {
            ForEach(visibleBlocks) { block in
                let isMaterialized = materializedIDs.contains(block.id)
                let isFlashing = flashingIDs.contains(block.id)
                let isWaveHit = waveReachedIDs.contains(block.id)
                let isBouncing = bouncingIDs.contains(block.id)

                GlassBlockView(
                    block: block,
                    isMaterialized: isMaterialized,
                    showHighlightFlash: isFlashing,
                    isBouncing: isBouncing
                )
                .brightness(isWaveHit ? 0.035 : 0)
                .scaleEffect(completionSettle && isMaterialized ? 0.985 : (isWaveHit ? 1.015 : 1.0))
                .position(block.center)
            }
        }
        .drawingGroup() // Metal-accelerated compositing — flattens 276 blocks into single texture
        // Touch interaction: press-in on tap, trail on drag
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    pressBlockAt(value.location)
                }
                .onEnded { value in
                    releaseBlock()
                }
        )
        .onAppear {
            materializeBlocks(for: progress)
        }
        .onChange(of: progress) { _, newProgress in
            // Don't materialize during dismiss — blocks are dissolving
            guard !isDismissing else { return }
            materializeBlocks(for: newProgress)
            checkMilestones(newProgress)
        }
        .onChange(of: isComplete) { _, complete in
            if complete {
                completionWave()
            }
        }
        .onChange(of: isDismissing) { _, dismissing in
            if dismissing {
                // Cancel wave if still running before starting dissolve
                waveTask?.cancel()
                waveTask = nil
                dissolveBlocks()
            } else {
                // Full reset when going back to idle — always, regardless of isComplete
                cancelAllTasks()
                resetAllState()
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .sensoryFeedback(.success, trigger: completionHaptic)
        .sensoryFeedback(.impact(weight: .medium), trigger: milestoneHaptic)
    }

    // MARK: - State Management

    private func cancelAllTasks() {
        waveTask?.cancel()
        waveTask = nil
        dissolveTask?.cancel()
        dissolveTask = nil
    }

    private func resetAllState() {
        materializedIDs = []
        flashingIDs = []
        waveReachedIDs = []
        bouncingIDs = []
        completionSettle = false
        lastMilestone = 0
    }

    // MARK: - Completion Wave

    private func completionWave() {
        let materializedBlocks = blocks.filter { materializedIDs.contains($0.id) }
        guard !materializedBlocks.isEmpty else { return }

        let sortedByDistance = materializedBlocks.sorted { distFromCenter($0) < distFromCenter($1) }

        let bandCount = 8
        let bandSize = max(1, sortedByDistance.count / bandCount)

        waveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            completionHaptic += 1 // .success haptic — "you did it"
            withAnimation(.spring(.smooth(duration: 0.3))) {
                completionSettle = true
            }

            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(.smooth(duration: 0.6))) {
                completionSettle = false
            }

            for band in 0..<bandCount {
                guard !Task.isCancelled else { return }

                let start = band * bandSize
                let end = min(start + bandSize, sortedByDistance.count)
                guard start < end else { continue }

                let bandIDs = Set(sortedByDistance[start..<end].map(\.id))

                withAnimation(.spring(.smooth(duration: 0.25))) {
                    waveReachedIDs.formUnion(bandIDs)
                }
                hapticTrigger += 1

                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(.smooth(duration: 0.4))) {
                    waveReachedIDs.subtract(bandIDs)
                }
            }
        }
    }

    // MARK: - Dissolve (Reverse Materialization)

    private func dissolveBlocks() {
        let materialized = blocks.filter { materializedIDs.contains($0.id) }
        let sortedByRow = materialized.sorted { $0.rowIndex > $1.rowIndex }

        let bandCount = 10
        let bandSize = max(1, sortedByRow.count / bandCount)

        dissolveTask = Task { @MainActor in
            for band in 0..<bandCount {
                guard !Task.isCancelled else { return }

                let start = band * bandSize
                let end = min(start + bandSize, sortedByRow.count)
                guard start < end else { continue }

                let bandIDs = Set(sortedByRow[start..<end].map(\.id))

                withAnimation(.spring(.smooth(duration: 0.5))) {
                    materializedIDs.subtract(bandIDs)
                }

                try? await Task.sleep(for: .milliseconds(150))
            }

            // Clean up any remaining
            guard !Task.isCancelled else { return }
            withAnimation(.spring(.smooth(duration: 0.3))) {
                resetAllState()
            }
        }
    }

    // MARK: - Touch Interaction

    /// Finds the block at a point (if any)
    private func blockAt(_ point: CGPoint) -> GlassBlock? {
        let halfSize = AppSize.blockSmall / 2
        return blocks.first(where: { b in
            materializedIDs.contains(b.id)
            && abs(b.center.x - point.x) < halfSize
            && abs(b.center.y - point.y) < halfSize
        })
    }

    /// Press-in: block compresses immediately (like the ring)
    /// Drag: previous block releases with trail, new block compresses
    private func pressBlockAt(_ point: CGPoint) {
        guard let block = blockAt(point) else { return }
        guard block.id != lastBouncedID else { return }

        // Release previous block with visible trail (longer spring)
        if let prevID = lastBouncedID {
            _ = withAnimation(.spring(.bouncy(duration: 0.6, extraBounce: 0.1))) {
                bouncingIDs.remove(prevID)
            }
        }

        lastBouncedID = block.id

        // Compress new block immediately — press-in feel
        _ = withAnimation(.spring(.snappy(duration: 0.12))) {
            bouncingIDs.insert(block.id)
        }

        // Rate-limited haptic
        let now = Date()
        if now.timeIntervalSince(lastBounceHapticTime) > 0.08 {
            hapticTrigger += 1
            lastBounceHapticTime = now
        }
    }

    /// Release: current block springs back with bouncy rebound
    private func releaseBlock() {
        if let blockID = lastBouncedID {
            _ = withAnimation(.spring(.bouncy(duration: 0.5, extraBounce: 0.15))) {
                bouncingIDs.remove(blockID)
            }
        }
        lastBouncedID = nil
    }

    // MARK: - Haptic Milestones

    private func checkMilestones(_ currentProgress: Double) {
        let percent = Int(currentProgress * 100)
        let milestones = [25, 50, 75]
        for milestone in milestones {
            if percent >= milestone && lastMilestone < milestone {
                lastMilestone = milestone
                milestoneHaptic += 1
            }
        }
    }

    private func distFromCenter(_ block: GlassBlock) -> Double {
        let dx = block.center.x - screenCenter.x
        let dy = block.center.y - screenCenter.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Materialization

    private func materializeBlocks(for currentProgress: Double) {
        let newBlocks = blocks.filter {
            $0.materializedAt <= currentProgress && !materializedIDs.contains($0.id)
        }
        guard !newBlocks.isEmpty else { return }

        let firstBlock = newBlocks[0]
        let baseDuration: Double
        if firstBlock.materializedAt < 0.25 {
            baseDuration = 0.6
        } else if firstBlock.materializedAt < 0.75 {
            baseDuration = 0.4
        } else {
            baseDuration = 0.3
        }

        let newIDs = Set(newBlocks.map(\.id))
        withAnimation(.spring(.smooth(duration: baseDuration))) {
            materializedIDs.formUnion(newIDs)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(baseDuration * 600)))

            withAnimation(.spring(.smooth(duration: 0.15))) {
                flashingIDs.formUnion(newIDs)
            }

            try? await Task.sleep(for: .milliseconds(200))

            withAnimation(.spring(.smooth(duration: 0.25))) {
                flashingIDs.subtract(newIDs)
            }
        }
    }
}
