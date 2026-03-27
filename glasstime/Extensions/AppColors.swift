import SwiftUI

// MARK: - Glass Block Appearance

extension Color {
    static var glassBlockFill: Color {
        Color(light: .white.opacity(0.10), dark: .white.opacity(0.16))
    }

    static var glassBlockStroke: Color {
        Color(light: .white.opacity(0.15), dark: .white.opacity(0.15))
    }

    static let glassBlockHighlight = Color.white.opacity(0.20)
}

// MARK: - Text Colors (Over Aurora Background)

extension Color {
    static let onAuroraPrimary = Color.white
    static var onAuroraSecondary: Color {
        Color(light: .white.opacity(0.7), dark: .white.opacity(0.65))
    }
    static var onAuroraTertiary: Color {
        Color(light: .white.opacity(0.5), dark: .white.opacity(0.45))
    }
}

// MARK: - Text Colors (Over Glass Surface)

extension Color {
    /// Primary text on glass: time display — white in both modes, always legible
    static var onGlassPrimary: Color {
        Color(light: .white, dark: .white)
    }
    /// Secondary text on glass: labels like "FOCUS", "START"
    static var onGlassSecondary: Color {
        Color(light: .white.opacity(0.75), dark: .white.opacity(0.60))
    }
    /// Tertiary text on glass: "STAY FOCUSED" — whisper
    static var onGlassTertiary: Color {
        Color(light: .white.opacity(0.55), dark: .white.opacity(0.35))
    }
    /// Button text on glass: subtle but tappable
    static var onGlassButton: Color {
        Color(light: .white.opacity(0.85), dark: .white.opacity(0.65))
    }
}

// MARK: - Glass Tints

extension Color {
    /// Matches the nucleus ring glass tint — same material language
    static var glassTintRing: Color {
        Color(light: Color(red: 0.32, green: 0.52, blue: 0.62),
              dark: Color(red: 0.50, green: 0.72, blue: 0.82))
    }
    static let glassTintActive = Color.blue.opacity(0.10)
    static let glassTintPaused = Color.indigo.opacity(0.10)
    static let glassTintComplete = Color.green.opacity(0.08)
    static let glassTintPicker = Color.blue.opacity(0.10)
    static let glassTintPickerSelected = Color.blue.opacity(0.15)
}

// MARK: - Status Colors

extension Color {
    static let statusSuccess = Color.green
}

// MARK: - Aurora Palette Colors

extension Color {
    // Morning (5-9h)
    static var auroraMorningBlob1: Color {
        Color(light: Color(red: 0.85, green: 0.65, blue: 0.7),
              dark: Color(red: 0.55, green: 0.35, blue: 0.4))
    }
    static var auroraMorningBlob2: Color {
        Color(light: Color(red: 0.7, green: 0.6, blue: 0.8),
              dark: Color(red: 0.4, green: 0.3, blue: 0.55))
    }
    static var auroraMorningBlob3: Color {
        Color(light: Color(red: 0.9, green: 0.75, blue: 0.6),
              dark: Color(red: 0.55, green: 0.4, blue: 0.3))
    }

    // Day (9-17h)
    static var auroraDayBlob1: Color {
        Color(light: Color(red: 0.5, green: 0.45, blue: 0.75),
              dark: Color(red: 0.2, green: 0.18, blue: 0.4))
    }
    static var auroraDayBlob2: Color {
        Color(light: Color(red: 0.3, green: 0.55, blue: 0.6),
              dark: Color(red: 0.1, green: 0.25, blue: 0.3))
    }
    static var auroraDayBlob3: Color {
        Color(light: Color(red: 0.6, green: 0.45, blue: 0.7),
              dark: Color(red: 0.25, green: 0.18, blue: 0.35))
    }

    // Evening (17-20h)
    static var auroraEveningBlob1: Color {
        Color(light: Color(red: 0.8, green: 0.55, blue: 0.35),
              dark: Color(red: 0.45, green: 0.28, blue: 0.15))
    }
    static var auroraEveningBlob2: Color {
        Color(light: Color(red: 0.65, green: 0.35, blue: 0.45),
              dark: Color(red: 0.35, green: 0.15, blue: 0.22))
    }
    static var auroraEveningBlob3: Color {
        Color(light: Color(red: 0.45, green: 0.35, blue: 0.6),
              dark: Color(red: 0.22, green: 0.15, blue: 0.35))
    }

    // Night (20-5h)
    static var auroraNightBlob1: Color {
        Color(light: Color(red: 0.25, green: 0.25, blue: 0.4),
              dark: Color(red: 0.1, green: 0.1, blue: 0.22))
    }
    static var auroraNightBlob2: Color {
        Color(light: Color(red: 0.2, green: 0.3, blue: 0.35),
              dark: Color(red: 0.08, green: 0.15, blue: 0.2))
    }
    static var auroraNightBlob3: Color {
        Color(light: Color(red: 0.3, green: 0.25, blue: 0.45),
              dark: Color(red: 0.12, green: 0.08, blue: 0.2))
    }
}

// MARK: - Focus Aurora Palette (Blue/Green)

extension Color {
    static var auroraFocusBlob1: Color {
        Color(light: Color(red: 0.45, green: 0.65, blue: 0.85),
              dark: Color(red: 0.15, green: 0.28, blue: 0.50))
    }
    static var auroraFocusBlob2: Color {
        Color(light: Color(red: 0.30, green: 0.45, blue: 0.72),
              dark: Color(red: 0.10, green: 0.18, blue: 0.40))
    }
    static var auroraFocusBlob3: Color {
        Color(light: Color(red: 0.40, green: 0.72, blue: 0.65),
              dark: Color(red: 0.12, green: 0.32, blue: 0.28))
    }
    static var auroraFocusBackground: Color {
        Color(light: Color(red: 0.78, green: 0.83, blue: 0.90),
              dark: Color(red: 0.06, green: 0.08, blue: 0.14))
    }
}

// MARK: - Light/Dark Adaptive Color Helper

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Glass ViewModifiers

extension View {
    func premiumGlassCircle(
        tint: Color = .clear,
        interactive: Bool = true
    ) -> some View {
        self.glassEffect(
            interactive
                ? .regular.tint(tint).interactive()
                : .regular.tint(tint),
            in: .circle
        )
    }

    func premiumGlassPill(
        tint: Color = .clear,
        interactive: Bool = true
    ) -> some View {
        self.glassEffect(
            interactive
                ? .regular.tint(tint).interactive()
                : .regular.tint(tint),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    func premiumGlassCapsule(
        tint: Color = .clear,
        interactive: Bool = true
    ) -> some View {
        self.glassEffect(
            interactive
                ? .regular.tint(tint).interactive()
                : .regular.tint(tint),
            in: .capsule
        )
    }
}
