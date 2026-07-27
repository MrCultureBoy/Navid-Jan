import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Retour haptique centralisé.
///
/// Chaque évènement du jeu a sa signature tactile : une validation ne se sent
/// pas comme une montée de niveau. Le tout respecte le réglage utilisateur.
enum Haptics {

    /// Piloté par les réglages ; mis à jour au démarrage.
    nonisolated(unsafe) static var isEnabled = true

    enum Event {
        case selection
        case light
        case medium
        case heavy
        case success
        case warning
        case error
        case levelUp
        case questComplete
        case combo(Int)
    }

    static func play(_ event: Event) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        switch event {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .levelUp:
            // Trois impacts croissants : on « sent » la montée.
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred(intensity: 0.6)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                generator.impactOccurred(intensity: 0.8)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        case .questComplete:
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred(intensity: 0.9)
        case .combo(let count):
            // Plus le combo monte, plus l'impact est franc.
            let intensity = min(1.0, 0.45 + Double(count) * 0.11)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: intensity)
        }
        #endif
    }

    static func selection() { play(.selection) }
    static func success() { play(.success) }
    static func light() { play(.light) }
    static func warning() { play(.warning) }
}
