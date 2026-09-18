import SwiftUI
import Foundation
import UIKit

// Système visuel natif d'Eole.
// Les surfaces de contenu restent adaptatives et lisibles ; le verre est réservé
// aux contrôles et aux éléments flottants.
public extension Color {
    static let eolePrimary = Color.eoleAdaptive(light: 0x0F766E, dark: 0x5DD6C7)
    static let eolePrimaryStrong = Color.eoleAdaptive(light: 0x0A5C56, dark: 0x83E7DC)
    static let eoleSecondary = Color.eoleAdaptive(light: 0x4C9786, dark: 0x80D8C8)
    static let eoleAccent = Color.eoleAdaptive(light: 0xCFEAE2, dark: 0x214A44)
    static let eoleBackground = Color(uiColor: .systemGroupedBackground)
    static let eoleSurface = Color(uiColor: .secondarySystemGroupedBackground)
    static let eoleSurfaceSoft = Color(uiColor: .tertiarySystemGroupedBackground)
    static let eoleForeground = Color(uiColor: .label)
    static let eoleMuted = Color(uiColor: .secondaryLabel)
    static let eoleBorder = Color(uiColor: .separator)
    static let eoleDanger = Color(uiColor: .systemRed)
    static let eoleSessionDeep = Color.eoleAdaptive(light: 0x123F3B, dark: 0x071D1B)

    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    private static func eoleAdaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

public enum EoleRadius {
    /// Compatible aliases used by existing screens.
    public static let sm: CGFloat = 14
    public static let md: CGFloat = 20
    public static let lg: CGFloat = 28

    /// Semantic names for new native surfaces.
    public static let control: CGFloat = sm
    public static let panel: CGFloat = md
    public static let prominentPanel: CGFloat = lg
}

public enum EoleSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

public extension Font {
    // SF Pro sémantique : le système fournit métrique, poids et Dynamic Type.
    static let eoleDisplay = Font.system(.largeTitle, design: .rounded, weight: .medium)
    static let eoleTitle = Font.system(.title2, design: .rounded, weight: .medium)
    static let eoleBody = Font.system(.body, design: .default, weight: .regular)
    static let eoleCaption = Font.system(.caption, design: .default, weight: .regular)
}

public extension Animation {
    static func eoleBreath(duration: Double) -> Animation {
        .timingCurve(0.37, 0, 0.63, 1, duration: duration)
    }

    /// Courbe particulièrement douce et apaisée pour les transitions d'ambiance et d'écrans.
    static func eoleCalm(duration: Double = EoleMotion.chromeFade) -> Animation {
        .timingCurve(0.25, 0.1, 0.25, 1.0, duration: duration)
    }
}

/// Durées motion centralisées : toute nouvelle animation réutilise ces tokens
/// au lieu d'une durée magique dispersée.
public enum EoleMotion {
    /// Présentation de la séance plein écran (immersion calme et profonde).
    public static let sessionPresent: Double = 0.75
    /// Fermeture de la séance plein écran (retour apaisé vers l'accueil).
    public static let sessionDismiss: Double = 0.70
    /// Cross-fade doux du fond de séance au changement de macro-phase.
    public static let chromeFade: Double = 0.65
    /// Moment d'installation préalable (« Installe-toi ») avant le décompte.
    public static let settleDuration: Double = 1.80
    /// Dévoilement progressif et paisible de l'écran des scores en fin de séance.
    public static let completionReveal: Double = 0.85
    /// Montée fluide et progressive des barres du graphique de rétention.
    public static let chartBarRise: Double = 0.85
    /// Entrée en scène douce lors de l'ouverture de l'application.
    public static let appEntrance: Double = 0.85
    /// Press du bouton primaire (doux et réactif sans être brusque).
    public static let pressPrimary: Double = 0.28
    public static let pressPrimaryScale: CGFloat = 0.985
    /// Press des boutons icônes.
    public static let pressIcon: Double = 0.24
    public static let pressIconScale: CGFloat = 0.96
    /// Pas du compte à rebours (1 chiffre / seconde).
    public static let countdown: Double = 1.0
    /// Transition douce des contrôles hors séance (période, historique).
    public static let controlTransition: Double = 0.40
}

/// Fondus audio miroirs des défauts d'EoleAudioEngine, exposés pour rester
/// synchronisés avec le motion sans dupliquer de littéraux.
public enum EoleAudioFade {
    public static let stop: Double = 0.85
    public static let pause: Double = 0.4
    public static let resume: Double = 0.6
}

/// Panneau de contenu natif : surface groupée adaptative, sans verre décoratif.
public struct EolePanel<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = EoleSpacing.xl, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Color.eoleSurface, in: RoundedRectangle(cornerRadius: EoleRadius.panel, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: EoleRadius.panel, style: .continuous)
                    .stroke(Color.eoleBorder.opacity(0.65), lineWidth: 0.5)
            }
    }
}

/// Tuile de métrique : une valeur dominante, un libellé stable et un contexte optionnel.
public struct EoleMetricTile: View {
    private let label: String
    private let value: String
    private let detail: String?

    public init(label: String, value: String, detail: String? = nil) {
        self.label = label
        self.value = value
        self.detail = detail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: EoleSpacing.sm) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.eoleMuted)
                .lineLimit(2)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.eoleForeground)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.eoleMuted)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(EoleSpacing.lg)
        .background(Color.eoleSurfaceSoft, in: RoundedRectangle(cornerRadius: EoleRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: EoleRadius.control, style: .continuous)
                .stroke(Color.eoleBorder.opacity(0.55), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

/// En-tête de section compact, cohérent entre Accueil, Progrès et Réglages.
public struct EoleSectionHeader: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String?

    public init(_ title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(alignment: .top, spacing: EoleSpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.eolePrimary)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.eoleForeground)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.eoleMuted)
                }
            }
        }
    }
}

/// Action principale utilisant le style Liquid Glass système.
public struct EolePrimaryButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            // Tint clair en dark : texte sombre fixe pour garder le contraste,
            // blanc sur tint sombre en light.
            .foregroundStyle(colorScheme == .dark ? Color(hex: 0x07332F) : .white)
            .padding(.horizontal, EoleSpacing.lg)
            .glassEffect(.regular.tint(Color.eolePrimary).interactive(), in: Capsule())
            .scaleEffect(!reduceMotion && configuration.isPressed ? EoleMotion.pressPrimaryScale : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: EoleMotion.pressPrimary), value: configuration.isPressed)
    }
}

/// Regroupe les contrôles proches pour que le système puisse fusionner leurs
/// surfaces de verre et conserver une hiérarchie visuelle calme.
public struct EoleGlassContainer<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = EoleSpacing.md, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        GlassEffectContainer(spacing: spacing) { content }
    }
}

public struct EoleGlassIconButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height: 44)
            .font(.body.weight(.semibold))
            .contentShape(Circle())
            .glassEffect(.regular.interactive(), in: Circle())
            .scaleEffect(!reduceMotion && configuration.isPressed ? EoleMotion.pressIconScale : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: EoleMotion.pressIcon), value: configuration.isPressed)
    }
}

/// Fond système volontairement sobre : les surfaces de contenu restent lisibles.
public struct EoleAmbientBackground: View {
    public init() {}

    public var body: some View {
        Color.eoleBackground
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Forme de contour organique : aucun anneau n'est un cercle parfait.
/// Les perturbations sont déterministes pour éviter un tremblement visuel.
public struct EoleContourShape: Shape {
    private let variant: Int

    public init(variant: Int) { self.variant = variant }

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let count = 12
        let points = (0..<count).map { index -> CGPoint in
            let angle = (Double(index) / Double(count)) * .pi * 2 - .pi / 2
            let wobble = 1 + 0.035 * sin(Double(index * 5 + variant * 7))
            return CGPoint(
                x: center.x + CGFloat(cos(angle) * radius * wobble),
                y: center.y + CGFloat(sin(angle) * radius * wobble)
            )
        }

        func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        var path = Path()
        path.move(to: midpoint(points[0], points[1]))
        for index in 1...count {
            let current = points[index % count]
            let next = points[(index + 1) % count]
            path.addQuadCurve(to: midpoint(current, next), control: current)
        }
        path.closeSubpath()
        return path
    }
}

public struct EoleLogo: View {
    private let size: CGFloat
    public init(size: CGFloat = 56) { self.size = size }
    public var body: some View {
        ZStack {
            EoleContourShape(variant: 31)
                .trim(from: 0.06, to: 0.72)
                .stroke(Color.eolePrimary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .padding(size * 0.08)
                .rotationEffect(.degrees(-48))
            EoleContourShape(variant: 37)
                .trim(from: 0.18, to: 0.61)
                .stroke(Color.eoleSecondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .padding(size * 0.25)
                .rotationEffect(.degrees(122))
            Circle().fill(Color.eolePrimary).frame(width: 4.5, height: 4.5)
                .offset(x: size * 0.26, y: -size * 0.17)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
