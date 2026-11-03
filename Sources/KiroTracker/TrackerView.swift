import AppKit
import SwiftUI
import KiroTrackerCore

struct TrackerView: View {
    @ObservedObject var model: TrackerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Kiro").font(.system(size: 18, weight: .semibold))
                    Text(model.snapshot?.plan.replacingOccurrences(of: "KIRO ", with: "") ?? "Usage tracker")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
                Spacer()
                if model.refreshing { ProgressView().controlSize(.small) }
                if let usage = model.snapshot {
                    Text(usage.isOverage ? "OVERAGE" : "MONTHLY")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(usage.isOverage ? Color.blue : Color.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background((usage.isOverage ? Color.blue : Color.secondary).opacity(0.1), in: Capsule())
                }
            }

            if let usage = model.snapshot {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(usage.percentage).font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("used").font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(UsageSnapshot.credits(usage.remaining)) left")
                            .font(.system(size: 12, weight: .medium)).monospacedDigit()
                    }
                    UsageBar(fraction: usage.fraction, color: color(for: usage.level))
                        .accessibilityLabel("Included credits")
                        .accessibilityValue("\(UsageSnapshot.credits(usage.used)) of \(UsageSnapshot.credits(usage.limit)) used")
                    Text("\(UsageSnapshot.credits(usage.used)) of \(UsageSnapshot.credits(usage.limit)) credits")
                        .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                }

                if usage.isOverage {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text("Overage").font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("\(UsageSnapshot.credits(usage.overage)) credits")
                                .font(.system(size: 12, weight: .medium)).monospacedDigit()
                        }
                        if let fraction = usage.overageFraction {
                            UsageBar(fraction: fraction, color: .blue)
                                .accessibilityLabel("Overage credits")
                                .accessibilityValue("\(UsageSnapshot.credits(usage.overage)) of \(UsageSnapshot.credits(usage.overageLimit!)) used")
                            Text("of \(UsageSnapshot.credits(usage.overageLimit!)) overage credits")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        } else {
                            // Show the count without a percentage when the cap is missing.
                            Capsule().fill(Color.blue).frame(width: 20, height: 6)
                            Text("No overage limit reported")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }

                if let reset = usage.resetsAt {
                    Label("Resets \(reset.formatted(.dateTime.month(.abbreviated).day().hour().minute()))", systemImage: "arrow.clockwise")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            } else if model.error == nil {
                Text("Reading your Kiro usage…").font(.system(size: 12)).foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }

            if let error = model.error {
                VStack(alignment: .leading, spacing: 4) {
                    if model.snapshot != nil {
                        Text("Showing last known usage").fontWeight(.medium)
                    }
                    Text(error)
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack {
                if let usage = model.snapshot {
                    Text("Updated \(usage.fetchedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                Button { Task { await model.refresh() } } label: {
                    Image(systemName: "arrow.clockwise").padding(4).contentShape(Rectangle())
                }
                .disabled(model.refreshing).help("Refresh usage (at most once every 15 seconds)")
                .accessibilityLabel("Refresh usage")
                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power").padding(4).contentShape(Rectangle())
                }
                .help("Quit Kiro Tracker").accessibilityLabel("Quit Kiro Tracker")
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 310)
    }

    private func color(for level: CreditLevel) -> Color {
        switch level { case .green: .green; case .yellow: .yellow; case .red: .red }
    }
}

struct UsageBar: View {
    let fraction: Double
    let color: Color
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(color)
                    .frame(width: max(0, geometry.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 7)
        .accessibilityElement(children: .ignore)
    }
}
