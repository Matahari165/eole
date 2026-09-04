import CoreHaptics
import Foundation

#if os(iOS)
import UIKit
#endif

/// Repères haptiques natifs, désactivés par défaut.
@MainActor
public final class EoleHaptics {
    public var enabled = false
    #if os(iOS)
    private var engine: CHHapticEngine?
    #endif

    public init() {}

    public func prepare() {
        #if os(iOS)
        guard enabled, engine == nil else { return }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let hapticEngine = try CHHapticEngine()
            hapticEngine.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.engine = nil
                    self?.prepare()
                }
            }
            hapticEngine.stoppedHandler = { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.enabled else { return }
                    try? self.engine?.start()
                }
            }
            engine = hapticEngine
            engine?.isAutoShutdownEnabled = true
            try engine?.start()
        } catch {
            engine = nil
        }
        #endif
    }

    /// Impulsion brève lors des transitions de phase.
    public func tap() {
        #if os(iOS)
        guard enabled else { return }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if let engine, (try? engine.start()) != nil {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6),
                ],
                relativeTime: 0, duration: 0.035
            )
            try? engine.makePlayer(with: CHHapticPattern(events: [event], parameters: [])).start(atTime: 0)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }

    /// Double impulsion au début d'une rétention.
    public func ding() {
        #if os(iOS)
        guard enabled, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        guard let engine else {
            tap()
            return
        }
        guard (try? engine.start()) != nil else { return }
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35),
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35),
                ],
                relativeTime: 0.059
            ),
        ]
        try? engine.makePlayer(with: CHHapticPattern(events: events, parameters: [])).start(atTime: 0)
        #endif
    }

    public func release() {
        #if os(iOS)
        engine?.stop(completionHandler: nil)
        engine = nil
        #endif
    }
}
