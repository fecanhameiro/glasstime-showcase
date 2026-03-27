import SwiftUI

struct GlassBlock: Identifiable {
    let id: Int
    let center: CGPoint
    let size: CGSize
    let materializedAt: Double
    let columnIndex: Int
    let rowIndex: Int
    let opacityVariation: Double      // 0.70...1.0 — visible but not jarring
    let brightnessVariation: Double  // -0.02...0.03 — some "washed", some "defined"
    let saturationVariation: Double  // 0.85...1.1 — depth illusion: desaturated = deeper
    let verticalPosition: Double     // 0=bottom, 1=top — drives screen-space lighting
    let horizontalPosition: Double // 0=left edge, 0.5=center, 1=right edge
    let distanceFromCenter: Double // distance from screen center in points

    /// Pre-computed edge fade opacity — used for visibility culling
    /// Mirrors the edgeFade logic in GlassBlockView
    var edgeFadeOpacity: Double {
        var fade = 1.0
        if verticalPosition > 0.60 {
            let t = (verticalPosition - 0.60) / 0.40
            fade *= 1.0 - t * 0.98
        }
        let hDist = abs(horizontalPosition - 0.5) * 2
        if hDist > 0.80 {
            let t = (hDist - 0.80) / 0.20
            fade *= 1.0 - t * 0.5
        }
        let ringRadius: Double = Double(AppSize.nucleusRing) / 2
        let fadeStart = ringRadius + 40
        let fadeEnd = ringRadius - 5
        if distanceFromCenter < fadeStart {
            if distanceFromCenter < fadeEnd {
                fade *= 0.35
            } else {
                let t = (fadeStart - distanceFromCenter) / (fadeStart - fadeEnd)
                fade *= 1.0 - t * 0.65
            }
        }
        return fade
    }
}

struct GlassBlockLayoutEngine {

    /// Generates a full-screen grid of blocks.
    /// All cells exist — the filling pattern determines materialization order.
    /// At progress=1.0, every cell is filled = glass mosaic covering the entire screen.
    static func generateLayout(
        containerSize: CGSize,
        blockArea: CGRect,
        seed: UInt64
    ) -> [GlassBlock] {
        var rng = SeededRandomNumberGenerator(seed: seed)
        var blocks: [GlassBlock] = []

        let blockSize = AppSize.blockSmall
        let gap: CGFloat = 4
        let cellSize = blockSize + gap

        // Edge-to-edge: grid extends BEYOND screen edges for infinite feel
        let columns = Int(ceil(containerSize.width / cellSize)) + 2 // +2 for overflow
        let rows = Int(ceil(blockArea.height / cellSize)) + 1

        guard columns > 1 && rows > 1 else { return [] }

        let totalWidth = CGFloat(columns) * cellSize - gap
        let horizontalOffset = (containerSize.width - totalWidth) / 2 // centered, overflows both sides

        // Generate ALL grid positions — perfect grid, zero offset
        struct BlockSlot {
            let col: Int
            let row: Int
            let center: CGPoint
        }

        var allSlots: [BlockSlot] = []
        for col in 0..<columns {
            for row in 0..<rows {
                let x = horizontalOffset + CGFloat(col) * cellSize + cellSize / 2
                let y = blockArea.maxY - (CGFloat(row) * cellSize + cellSize / 2)

                allSlots.append(BlockSlot(col: col, row: row, center: CGPoint(x: x, y: y)))
            }
        }

        // === FILLING PATTERN ===
        // Rising staircase with organic top edge determines the ORDER of materialization.
        // Bottom rows fill first. Within each "wave", the organic edge creates the staircase.
        // At 100%, everything is filled.

        // Compute organic column heights for each "wave" of filling
        // Wave 0: bottom row everywhere
        // Wave N: staircase pattern rises — left columns fill slower, right faster
        // Final wave: all remaining cells

        // For materialization order, assign a "fill priority" to each cell:
        // Lower rows get lower priority (fill first).
        // Within same row, columns on the right get slightly lower priority (staircase feel).
        // This creates: bottom-up + right-side-leading growth.

        // Separate visible slots from overflow (off-screen) slots
        // Overflow blocks appear instantly (materializedAt=0), don't consume progress
        var visibleSlots: [BlockSlot] = []
        var overflowSlots: [BlockSlot] = []

        for slot in allSlots {
            let isOffScreen = slot.center.x < -blockSize / 2
                || slot.center.x > containerSize.width + blockSize / 2
                || slot.center.y < -blockSize / 2
                || slot.center.y > containerSize.height + blockSize / 2
            if isOffScreen {
                overflowSlots.append(slot)
            } else {
                visibleSlots.append(slot)
            }
        }

        // Order visible slots: bottom-up with organic lateral variation
        var orderedSlots: [BlockSlot] = []
        for row in 0..<rows {
            var rowSlots = visibleSlots.filter { $0.row == row }
            guard !rowSlots.isEmpty else { continue }

            rowSlots.sort { a, b in
                let biasA = Double(a.col) - Double(row) * 0.3
                let biasB = Double(b.col) - Double(row) * 0.3
                return biasA > biasB
            }

            for i in stride(from: rowSlots.count - 1, through: 1, by: -1) {
                let j = Int.random(in: max(0, i - 2)...i, using: &rng)
                rowSlots.swapAt(i, j)
            }

            orderedSlots.append(contentsOf: rowSlots)
        }

        // Append overflow at the beginning — they materialize instantly
        let allOrderedSlots = overflowSlots + orderedSlots

        // === CLUSTER MAP ===
        // Divide the grid into ~3x3 block clusters. Each cluster shares
        // a base "personality" (lighter, darker, or neutral). This creates
        // invisible groups with coherent variation = reads as depth, not noise.
        let clusterSize = 3
        let clusterCols = (columns + clusterSize - 1) / clusterSize
        let clusterRows = (rows + clusterSize - 1) / clusterSize

        // Each cluster gets a type: 0=neutral(60%), 1=lighter(20%), 2=darker(20%)
        var clusterTypes: [Int: Int] = [:]
        for cr in 0..<clusterRows {
            for cc in 0..<clusterCols {
                let key = cr * clusterCols + cc
                let roll = Double.random(in: 0...1, using: &rng)
                if roll < 0.20 {
                    clusterTypes[key] = 1 // lighter
                } else if roll < 0.40 {
                    clusterTypes[key] = 2 // darker/softer
                } else {
                    clusterTypes[key] = 0 // neutral
                }
            }
        }

        // Assign materializedAt values + cluster-driven variation
        // Overflow blocks get materializedAt=0 (instant), visible blocks span 0...1
        let overflowCount = overflowSlots.count
        let visibleCount = visibleSlots.count
        for (index, slot) in allOrderedSlots.enumerated() {
            let materializedAt: Double
            if index < overflowCount {
                // Overflow (off-screen) — appear instantly
                materializedAt = 0.0
            } else {
                // Visible blocks — span the full 0...1 range
                let visibleIndex = index - overflowCount
                materializedAt = visibleCount > 1
                    ? min(1.0, max(0.0, Double(visibleIndex) / Double(visibleCount - 1)))
                    : 0.0
            }

            let verticalPosition = rows > 1
                ? Double(slot.row) / Double(rows - 1)
                : 0.0

            let horizontalPosition = columns > 1
                ? Double(slot.col) / Double(columns - 1)
                : 0.5

            // Vertical material gradient: bottom denser, top softer
            let verticalOpacityBias = 1.0 - verticalPosition * 0.15 // top is 15% lighter

            // Cluster personality
            let cCol = slot.col / clusterSize
            let cRow = slot.row / clusterSize
            let clusterKey = cRow * clusterCols + cCol
            let clusterType = clusterTypes[clusterKey] ?? 0

            let clusterOpacityBias: Double
            let clusterBrightnessBias: Double
            let clusterSaturationBias: Double
            switch clusterType {
            case 1: // lighter cluster — "washed by light", closer feel
                clusterOpacityBias = 0.85
                clusterBrightnessBias = 0.035
                clusterSaturationBias = 1.08
            case 2: // darker/softer cluster — "deeper glass", recessed
                clusterOpacityBias = 1.0
                clusterBrightnessBias = -0.025
                clusterSaturationBias = 0.82
            default: // neutral
                clusterOpacityBias = 0.94
                clusterBrightnessBias = 0.0
                clusterSaturationBias = 0.95
            }

            // ~5% of blocks are "outliers" — noticeably different from their cluster
            let isOutlier = Double.random(in: 0...1, using: &rng) < 0.05
            let outlierShift = isOutlier ? Double.random(in: -0.15...0.15, using: &rng) : 0.0

            // Final values: cluster base + jitter + outlier
            let opacityVariation = min(1.0, max(0.55,
                clusterOpacityBias * verticalOpacityBias
                + Double.random(in: -0.06...0.04, using: &rng)
                + outlierShift
            ))

            let brightnessVariation = clusterBrightnessBias
                + Double.random(in: -0.01...0.01, using: &rng)
                + outlierShift * 0.3

            // Saturation: closer clusters more vivid, deeper clusters washed out
            let saturationVariation = min(1.15, max(0.75,
                clusterSaturationBias + Double.random(in: -0.05...0.05, using: &rng)
            ))

            // Distance from screen center (for circle breathing zone)
            let screenCenter = CGPoint(
                x: containerSize.width / 2,
                y: containerSize.height / 2
            )
            let dx = slot.center.x - screenCenter.x
            let dy = slot.center.y - screenCenter.y
            let distFromCenter = sqrt(dx * dx + dy * dy)

            blocks.append(GlassBlock(
                id: index,
                center: slot.center,
                size: CGSize(width: blockSize, height: blockSize),
                materializedAt: materializedAt,
                columnIndex: slot.col,
                rowIndex: slot.row,
                opacityVariation: opacityVariation,
                brightnessVariation: brightnessVariation,
                saturationVariation: saturationVariation,
                verticalPosition: verticalPosition,
                horizontalPosition: horizontalPosition,
                distanceFromCenter: distFromCenter
            ))
        }

        return blocks
    }
}

// MARK: - Seeded Random Number Generator

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
