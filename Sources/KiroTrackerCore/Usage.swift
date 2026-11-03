import Foundation

public enum CreditLevel: Sendable { case green, yellow, red }

public struct UsageSnapshot: Sendable {
    public let plan: String
    public let used: Double
    public let limit: Double
    public let overage: Double
    public let overageLimit: Double?
    public let resetsAt: Date?
    public let fetchedAt: Date

    public var remaining: Double { max(0, limit - used) }
    public var fraction: Double { min(1, max(0, used / limit)) }
    public var level: CreditLevel { remaining <= 50 ? .red : remaining <= 250 ? .yellow : .green }
    public var isOverage: Bool { overage > 0 }
    public var overageFraction: Double? {
        guard let overageLimit, overageLimit > 0 else { return nil }
        return min(1, overage / overageLimit)
    }
    public var percentage: String {
        // Round down until all included credits are used.
        let value = fraction >= 1 ? 100 : floor(fraction * 100)
        return "\(Int(value))%"
    }
    public var menuTitle: String { isOverage ? "\(percentage) +\(Self.credits(overage))" : percentage }

    public static func credits(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    public static func decode(_ data: Data, now: Date = Date()) throws -> UsageSnapshot {
        guard data.count <= UsageTransport.maximumResponseBytes else { throw TrackerError.invalidUsage }
        let response = try JSONDecoder().decode(UsageResponse.self, from: data)
        guard let credit = response.usageBreakdownList.first(where: { $0.resourceType == "CREDIT" }),
              let total = credit.currentUsageWithPrecision ?? credit.currentUsage,
              let limit = credit.usageLimitWithPrecision ?? credit.usageLimit,
              total.isFinite, total >= 0, total <= 1_000_000_000_000,
              limit.isFinite, limit > 0, limit <= 1_000_000_000_000 else {
            throw TrackerError.invalidUsage
        }
        let overage = credit.currentOveragesWithPrecision ?? credit.currentOverages ?? max(0, total - limit)
        guard overage.isFinite, overage >= 0, overage <= total else { throw TrackerError.invalidUsage }
        // Subtract overage so the main bar only shows included credits.
        let planUsed = max(0, total - overage)
        guard planUsed <= limit + 0.01 else { throw TrackerError.invalidUsage }
        // The API does not clearly separate bonus credits from plan usage.
        guard (credit.bonuses ?? []).isEmpty else { throw TrackerError.bonusUnsupported }
        let cap = credit.overageCapWithPrecision ?? credit.overageCap
        let reset = credit.nextDateReset ?? response.nextDateReset
        if let reset, !reset.isFinite || !(946684800...4102444800).contains(reset) {
            throw TrackerError.invalidUsage
        }
        // Keep unexpected server text from changing the dropdown layout.
        let rawPlan = response.subscriptionInfo?.subscriptionTitle ?? "Kiro"
        let safePlan = rawPlan.unicodeScalars.contains {
            [.control, .format, .lineSeparator, .paragraphSeparator].contains($0.properties.generalCategory)
        } ? "Kiro" : String(rawPlan.prefix(64))
        return UsageSnapshot(
            plan: safePlan,
            used: min(planUsed, limit), limit: limit, overage: overage,
            overageLimit: cap.flatMap { $0.isFinite && $0 > 0 && $0 <= 1_000_000_000_000 ? $0 : nil },
            resetsAt: reset.map { Date(timeIntervalSince1970: $0) },
            fetchedAt: now
        )
    }
}

private struct UsageResponse: Decodable {
    var usageBreakdownList: [Breakdown]
    var nextDateReset: Double?
    var subscriptionInfo: Subscription?
    struct Subscription: Decodable { var subscriptionTitle: String? }
    struct Bonus: Decodable {}
    struct Breakdown: Decodable {
        var resourceType: String?
        var currentUsage: Double?
        var currentUsageWithPrecision: Double?
        var usageLimit: Double?
        var usageLimitWithPrecision: Double?
        var currentOverages: Double?
        var currentOveragesWithPrecision: Double?
        var overageCap: Double?
        var overageCapWithPrecision: Double?
        var nextDateReset: Double?
        var bonuses: [Bonus]?
    }
}

public enum TrackerError: LocalizedError, Sendable {
    case notSignedIn, sessionExpired, invalidUsage, unsupportedRegion, bonusUnsupported, invalidDatabasePath
    case server(Int)
    public var errorDescription: String? {
        switch self {
        case .notSignedIn: "Sign in with kiro-cli login, then refresh."
        case .invalidDatabasePath: "The Kiro database path is invalid. Supply an absolute path with --database or KIRO_TRACKER_DATABASE_PATH."
        case .sessionExpired: "Kiro's session has expired. Use Kiro CLI to renew it, then refresh."
        case .invalidUsage: "Kiro returned usage data that could not be read."
        case .unsupportedRegion: "This Kiro profile region is not supported yet."
        case .bonusUnsupported: "Kiro reported bonus credits that cannot be separated from plan usage."
        case .server(let status): "Kiro is unavailable (HTTP \(status)). Try refreshing shortly."
        }
    }
}
