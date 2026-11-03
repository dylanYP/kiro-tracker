import Foundation

/// A monotonic clock prevents wall-clock changes from breaking request throttling.
public struct RefreshGate: Sendable {
    private var lastAttempt: ContinuousClock.Instant?
    public init() {}
    public mutating func begin(at now: ContinuousClock.Instant = .now) -> Bool {
        if let lastAttempt, lastAttempt.duration(to: now) < .seconds(15) { return false }
        lastAttempt = now
        return true
    }
}
