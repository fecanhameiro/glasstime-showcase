import Foundation

struct AppServices {
    let timer: any TimerServicing
    let haptics: any HapticsServicing
    let analytics: any AnalyticsServicing
    let sound: any SoundServicing
    let liveActivity: any LiveActivityServicing
    let serverTimer: any ServerTimerServicing
}
