#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Huit contours organiques irréguliers, fermés
/// au repos (scale .62→1 selon l'anneau), ouvertes à l'inspire.
public struct BreathContoursView: View {
    public enum MotionPhase { case rest, inhale, exhale }

    private let motion: MotionPhase
    private let pace: Pace
    /// Durée explicite (ex. récupération 2 s) prioritaire sur le pace.
    /// À nil, le visuel au repos et le rythme du pace sont inchangés.
    private let overrideDuration: Double?
    /// Diamètre du visuel : 320 par défaut (tous les iPhones iOS 26+ font
    /// au moins 375 pt de large), réduit en hauteur compacte / paysage.
    private let side: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fermetures progressives du contour : l'anneau central reste à 62 %
    /// en exhale (pas de pâté central), l'externe reste plein.
    private static let closedScales: [CGFloat] = [0.62, 0.64, 0.67, 0.70, 0.74, 0.79, 0.86, 1.0]

    public init(motion: MotionPhase, pace: Pace, overrideDuration: Double? = nil, side: CGFloat = 320) {
        self.motion = motion
        self.pace = pace
        self.overrideDuration = overrideDuration
        self.side = side
    }

    public var body: some View {
        let timing = paceTiming(for: pace)
        let duration = overrideDuration ?? (motion == .inhale ? timing.inhaleSeconds : timing.exhaleSeconds)
        let side = self.side
        return ZStack {
            ForEach(0..<8, id: \.self) { index in
                let inset = side * CGFloat(index) * 0.07
                EoleContourShape(variant: index)
                    // Hiérarchie : internes fins et doux, externe net.
                    // Exhale en dégradé (pas d'aplat uniforme) pour garder
                    // la profondeur même poumons vides.
                    .stroke(
                        Color.white.opacity(motion == .inhale
                            ? (index == 7 ? 0.92 : 0.45 + CGFloat(index) * 0.05)
                            : (0.25 + CGFloat(index) * 0.04)),
                        lineWidth: index == 7 ? 2 : 1.5
                    )
                    .frame(width: side - inset * 2, height: side - inset * 2)
                    .scaleEffect(motion == .inhale ? 1 : Self.closedScales[index])
                    // Pas de blur animé : opacité + échelle suffisent,
                    // le flou coûterait une passe offscreen plein écran
                    // à chaque respiration.
                    .animation(
                        reduceMotion ? nil : .eoleBreath(duration: duration),
                        value: motion
                    )
            }
            // Point central fixe : les contours portent déjà le mouvement,
            // pas de micro-pulse redondant au rythme du pace.
            EoleContourShape(variant: 9)
                .stroke(Color.white.opacity(0.84), lineWidth: 1.5)
                .fill(Color.white.opacity(0.15))
                .frame(width: 8, height: 8)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

extension BreathContoursView.MotionPhase: Equatable {}
