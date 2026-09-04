import SwiftUI
import Foundation

// Système visuel Eole : palette du web, transposée dans les rôles natifs iOS.
public extension Color {
    static let eolePrimary = Color(hex: 0x176F65)
    static let eolePrimaryStrong = Color(hex: 0x0C514B)
    static let eoleSecondary = Color(hex: 0x84B8A8)
    static let eoleAccent = Color(hex: 0xBAD7CC)
    static let eoleBackground = Color(hex: 0xEFF4F1)
    static let eoleSurfaceSoft = Color(hex: 0xE5EEEA)
    static let eoleForeground = Color(hex: 0x17332E)
    static let eoleMuted = Color(hex: 0x5F726C)
    static let eoleBorder = Color(hex: 0xD6E1DC)
    static let eoleDanger = Color(hex: 0xB64343)
    static let eoleSessionDeep = Color(hex: 0x123F3B)

    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

public enum EoleRadius {
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 18
    public static let lg: CGFloat = 26
}

public extension Font {
    // `relativeTo` keeps the Eole voice while allowing Dynamic Type to enlarge
    // text for people who need it.
    static let eoleDisplay = Font.custom("Avenir Next", size: 32, relativeTo: .largeTitle).weight(.medium)
    static let eoleTitle = Font.custom("Avenir Next", size: 24, relativeTo: .title2).weight(.medium)
    static let eoleBody = Font.custom("Avenir Next", size: 16, relativeTo: .body)
    static let eoleCaption = Font.custom("Avenir Next", size: 13, relativeTo: .caption)
}

public extension Animation {
    static func eoleBreath(duration: Double) -> Animation {
        .timingCurve(0.37, 0, 0.63, 1, duration: duration)
    }
}

/// Surface de contenu non vitrée : le verre reste réservé aux contrôles.
public struct EoleCard<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        content
            .padding(18)
            .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: EoleRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: EoleRadius.lg)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            }
    }
}

/// Action principale utilisant le style Liquid Glass système.
public struct EolePrimaryButton: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next", size: 16, relativeTo: .body).weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .glassEffect(.regular.tint(Color.eolePrimary).interactive(), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

/// Regroupe les contrôles proches pour que le système puisse fusionner leurs
/// surfaces de verre et conserver une hiérarchie visuelle calme.
public struct EoleGlassContainer<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        GlassEffectContainer(spacing: spacing) { content }
    }
}

public struct EoleGlassIconButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height: 44)
            .font(.body.weight(.semibold))
            .glassEffect(.regular.interactive(), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

public struct EoleAmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init() {}

    public var body: some View {
        ZStack {
            Color.eoleBackground
            RadialGradient(
                colors: [.white.opacity(0.9), .clear],
                center: .topLeading,
                startRadius: 4,
                endRadius: 270
            )
            RadialGradient(
                colors: [Color.eoleAccent.opacity(0.22), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 300
            )
            if !reduceMotion {
                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 190, height: 190)
                    .blur(radius: 34)
                    .offset(x: 115, y: 210)
                    .accessibilityHidden(true)
            }
        }
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
            Circle().stroke(Color.eolePrimary.opacity(0.22), lineWidth: 1)
            Circle().trim(from: 0.05, to: 0.78)
                .stroke(Color.eolePrimary, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                .rotationEffect(.degrees(-54))
            Circle().fill(Color.eolePrimary).frame(width: 5, height: 5)
                .offset(y: -size * 0.28)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

public struct EoleEyebrow: View {
    private let text: String
    private let color: Color
    public init(_ text: String, color: Color = .eolePrimary) {
        self.text = text
        self.color = color
    }
    public var body: some View {
        Text(text.uppercased())
            .font(.custom("Avenir Next", size: 11, relativeTo: .caption).weight(.bold))
            .tracking(2.1)
            .foregroundStyle(color)
    }
}
