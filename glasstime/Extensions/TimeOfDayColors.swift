import SwiftUI

struct AuroraPalette {
    let blob1: Color
    let blob2: Color
    let blob3: Color
    let background: Color

    static let focus = AuroraPalette(
        blob1: .auroraFocusBlob1,
        blob2: .auroraFocusBlob2,
        blob3: .auroraFocusBlob3,
        background: .auroraFocusBackground
    )
}

enum TimeOfDayPeriod: CaseIterable {
    case morning   // 5-9h
    case day       // 9-17h
    case evening   // 17-20h
    case night     // 20-5h

    static var current: TimeOfDayPeriod {
        period(for: Date())
    }

    static func period(for date: Date) -> TimeOfDayPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<9: return .morning
        case 9..<17: return .day
        case 17..<20: return .evening
        default: return .night
        }
    }

    var blob1: Color {
        switch self {
        case .morning: return .auroraMorningBlob1
        case .day: return .auroraDayBlob1
        case .evening: return .auroraEveningBlob1
        case .night: return .auroraNightBlob1
        }
    }

    var blob2: Color {
        switch self {
        case .morning: return .auroraMorningBlob2
        case .day: return .auroraDayBlob2
        case .evening: return .auroraEveningBlob2
        case .night: return .auroraNightBlob2
        }
    }

    var blob3: Color {
        switch self {
        case .morning: return .auroraMorningBlob3
        case .day: return .auroraDayBlob3
        case .evening: return .auroraEveningBlob3
        case .night: return .auroraNightBlob3
        }
    }
}
