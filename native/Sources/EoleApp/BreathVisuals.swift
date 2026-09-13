#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Huit contours organiques irréguliers, fermés
/// au repos (scale .46→1 selon l'anneau), ouvertes à l'inspire.
public struct BreathContoursView: View {
    public enum MotionPhase { case rest, inhale, exhale }

    private let motion: MotionPhase
    private let pace: Pace
    /// Durée explicite (ex. récupération 2 s) prioritaire sur le pace.
    /// À nil, le visuel au repos et le rythme du pace sont inchangés.
    private let overrideDuration: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fermetures progressives du contour (inset 0→49%).
    private static let closedScales: [CGFloat] = [0.46, 0.48, 0.5, 0.53, 0.57, 0.64, 0.78, 1.0]

    public init(motion: MotionPhase, pace: Pace, overrideDuration: Double? = nil) {
        self.motion = motion
        self.pace = pace
        self.overrideDuration = overrideDuration
    }

    public var body: some View {
        let timing = paceTimings[pace] ?? paceTimings[.normal]!
        let duration = overrideDuration ?? (motion == .inhale ? timing.inhaleSeconds : timing.exhaleSeconds)
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    let inset = side * CGFloat(index) * 0.07
                    EoleContourShape(variant: index)
                        .stroke(Color.white.opacity(index == 7 ? 0.92 : 0.55), lineWidth: 2)
                        .frame(width: side - inset * 2, height: side - inset * 2)
                        .scaleEffect(motion == .inhale ? 1 : Self.closedScales[index])
                        .opacity(motion == .inhale ? (0.54 + CGFloat(index) * 0.04) : 0.28)
                        .animation(
                            reduceMotion ? nil : .eoleBreath(duration: duration),
                            value: motion
                        )
                }
                EoleContourShape(variant: 9)
                    .stroke(Color.white.opacity(0.84), lineWidth: 1.5)
                    .fill(Color.white.opacity(motion == .inhale ? 0.2 : 0.1))
                    .frame(width: 8, height: 8)
                    .scaleEffect(motion == .inhale ? 1.06 : 0.94)
                    .animation(
                        reduceMotion ? nil : .eoleBreath(duration: duration),
                        value: motion
                    )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}

extension BreathContoursView.MotionPhase: Equatable {}
