import Foundation
import Testing
@testable import KiroTrackerCore

private func snapshot(total: Double, overage: Double = 0, limit: Double = 1000, cap: Double? = 10000) throws -> UsageSnapshot {
    var row: [String: Any] = ["resourceType": "CREDIT", "currentUsageWithPrecision": total,
                              "usageLimitWithPrecision": limit, "currentOveragesWithPrecision": overage]
    if let cap { row["overageCapWithPrecision"] = cap }
    return try UsageSnapshot.decode(JSONSerialization.data(withJSONObject: ["usageBreakdownList": [row]]))
}

@Test func exactCreditThresholds() throws {
    #expect(try snapshot(total: 749.99).level == .green)
    #expect(try snapshot(total: 750).level == .yellow)
    #expect(try snapshot(total: 949.99).level == .yellow)
    #expect(try snapshot(total: 950).level == .red)
    #expect(try snapshot(total: 1000).level == .red)
    #expect(try snapshot(total: 999.99).percentage == "99%")
}

@Test func overageIsNotDoubleCounted() throws {
    let value = try snapshot(total: 1025.5, overage: 25.5)
    #expect(value.used == 1000)
    #expect(value.remaining == 0)
    #expect(value.fraction == 1)
    #expect(value.overageFraction == 0.00255)
    #expect(value.menuTitle == "100% +25.5")
    #expect(value.isOverage)
}

@Test func exhaustedDoesNotMeanOverage() throws {
    let value = try snapshot(total: 1000)
    #expect(!value.isOverage)
    #expect(value.menuTitle == "100%")
}

@Test func missingOverageCapDoesNotInventPercentage() throws {
    #expect(try snapshot(total: 1010, overage: 10, cap: nil).overageFraction == nil)
}

@Test func invalidValuesDoNotBecomeZeroUsage() {
    for (total, overage, limit) in [(-1.0, 0.0, 1000.0), (10, -1, 1000), (10, 11, 1000), (0, 0, 0), (1100, 0, 1000)] {
        #expect(throws: (any Error).self) { try snapshot(total: total, overage: overage, limit: limit) }
    }
}

@Test func resetAndPrecision() throws {
    let data = Data(#"{"subscriptionInfo":{"subscriptionTitle":"KIRO PRO"},"nextDateReset":1796083200,"usageBreakdownList":[{"resourceType":"CREDIT","currentUsage":147,"currentUsageWithPrecision":147.27,"usageLimit":1000}]}"#.utf8)
    let value = try UsageSnapshot.decode(data)
    #expect(value.used == 147.27)
    #expect(value.resetsAt == Date(timeIntervalSince1970: 1796083200))
    #expect(value.menuTitle == "14%")
}

@Test func bonusUsageIsExplicitlyUnsupported() {
    let data = Data(#"{"usageBreakdownList":[{"resourceType":"CREDIT","currentUsage":10,"usageLimit":1000,"bonuses":[{}]}]}"#.utf8)
    #expect(throws: (any Error).self) { try UsageSnapshot.decode(data) }
}

@Test func missingLoginIsHandled() async {
    let client = KiroClient(databaseURL: URL(fileURLWithPath: "/nonexistent-kiro-tracker-test.sqlite3"))
    await #expect(throws: (any Error).self) { try await client.fetch() }
}
