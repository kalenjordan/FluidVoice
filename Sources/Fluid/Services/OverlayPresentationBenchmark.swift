import Foundation

/// Correlates a physical shortcut press with the overlay presentation path.
/// The logger uses system uptime so wall-clock adjustments cannot skew latency.
final class OverlayPresentationBenchmark: @unchecked Sendable {
    static let shared = OverlayPresentationBenchmark()

    struct Token: Sendable {
        let id: UInt64
        let startedAt: TimeInterval
        let trigger: String
    }

    private let lock = NSLock()
    private var nextID: UInt64 = 0
    private var activeMeasurement: Token?

    private init() {}

    @discardableResult
    func begin(trigger: String) -> Token {
        let measurement = self.lock.withLock { () -> Token in
            self.nextID &+= 1
            let measurement = Token(
                id: self.nextID,
                startedAt: ProcessInfo.processInfo.systemUptime,
                trigger: trigger
            )
            self.activeMeasurement = measurement
            return measurement
        }
        self.log(measurement, stage: "key_down")
        return measurement
    }

    func currentToken() -> Token? {
        self.lock.withLock { self.activeMeasurement }
    }

    func mark(_ stage: String, token: Token? = nil, completesMeasurement: Bool = false) {
        let measurement = self.lock.withLock { () -> Token? in
            let measurement = token ?? self.activeMeasurement
            if completesMeasurement, self.activeMeasurement?.id == measurement?.id {
                self.activeMeasurement = nil
            }
            return measurement
        }
        guard let measurement else { return }
        self.log(measurement, stage: stage)
    }

    private func log(_ measurement: Token, stage: String) {
        let elapsedMilliseconds = Int(
            ((ProcessInfo.processInfo.systemUptime - measurement.startedAt) * 1_000).rounded()
        )
        DebugLogger.shared.benchmark(
            "OVERLAY_LATENCY",
            message: "id=\(measurement.id) stage=\(stage) elapsedMs=\(elapsedMilliseconds) trigger=\(measurement.trigger)",
            source: "OverlayBenchmark"
        )
    }
}
