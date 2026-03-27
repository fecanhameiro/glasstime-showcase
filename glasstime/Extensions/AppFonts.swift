import SwiftUI

enum AppFont {
    static let timerDisplay: Font = .system(size: 56, weight: .light, design: .rounded).monospacedDigit()
    static let timerLabel: Font = .system(size: 14, weight: .medium, design: .rounded)
    static let durationPreset: Font = .system(size: 20, weight: .semibold, design: .rounded)
    static let durationLabel: Font = .system(size: 13, weight: .regular, design: .rounded)
    static let completionTitle: Font = .system(size: 28, weight: .bold, design: .rounded)
    static let completionSubtitle: Font = .system(size: 15, weight: .medium, design: .rounded)
}
