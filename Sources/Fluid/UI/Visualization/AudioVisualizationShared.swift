import Combine
import SwiftUI

protocol AudioVisualizationConfig {
    var noiseThreshold: CGFloat { get }
    var maxAnimationScale: CGFloat { get }
    var animationSpring: Animation { get }
}

enum AudioVisualizationScale {
    /// Expands the quieter part of the usable microphone range so conversational
    /// speech creates visible movement while levels below the noise gate stay flat.
    static func conversationalSpeechLevel(
        _ level: CGFloat,
        noiseThreshold: CGFloat
    ) -> CGFloat {
        let clampedLevel = min(max(level, 0), 1)
        let clampedThreshold = min(max(noiseThreshold, 0), 0.99)
        let normalized = max(
            min((clampedLevel - clampedThreshold) / (1 - clampedThreshold), 1),
            0
        )
        return pow(normalized, 0.42)
    }
}

final class AudioVisualizationData: ObservableObject {
    @Published var audioLevel: CGFloat = 0.0
    private var cancellable: AnyCancellable?

    init(audioLevelPublisher: AnyPublisher<CGFloat, Never>) {
        self.cancellable = audioLevelPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
    }

    deinit {
        cancellable?.cancel()
    }
}
