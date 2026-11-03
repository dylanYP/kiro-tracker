import AppKit
import SwiftUI
import KiroTrackerCore

@MainActor
final class TrackerModel: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var error: String?
    @Published var refreshing = false
    var onChange: (() -> Void)?
    private let client = KiroClient()
    private var refreshGate = RefreshGate()

    func refresh() async {
        // Skip repeated clicks while a request or cooldown is active.
        guard !refreshing, refreshGate.begin() else { return }
        refreshing = true
        defer { refreshing = false; onChange?() }
        do {
            snapshot = try await client.fetch()
            error = nil
        } catch {
            // Clear old usage if the account is no longer available.
            if let failure = error as? TrackerError {
                switch failure {
                case .notSignedIn, .sessionExpired, .unsupportedRegion, .invalidDatabasePath: snapshot = nil
                default: break
                }
            }
            self.error = (error as? TrackerError)?.localizedDescription
                ?? "Couldn’t reach Kiro. Check your connection and try again."
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let model = TrackerModel()
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var polling: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        item.button?.image = KiroLogo.image()
        item.button?.imagePosition = .imageLeading
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.delegate = self
        // Skip the animation so the dropdown opens at its final position.
        popover.animates = false
        model.onChange = { [weak self] in self?.updateStatus() }
        updateStatus()
        // Allow some timing slack so macOS can group background work.
        polling = Task { [weak self] in
            while !Task.isCancelled {
                await self?.model.refresh()
                do { try await Task.sleep(for: .seconds(300), tolerance: .seconds(30)) }
                catch { return }
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.model.refresh() }
        }
        #if DEBUG
        if CommandLine.arguments.contains("--inspect-layout") {
            Task {
                try? await Task.sleep(for: .seconds(2))
                togglePopover()
                if let button = item.button, let statusWindow = button.window,
                   let window = popover.contentViewController?.view.window {
                    let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
                    print("Immediate opening gap: \(anchor.minY - window.frame.maxY)pt")
                }
                try? await Task.sleep(for: .seconds(1))
                if let button = item.button, let statusWindow = button.window,
                   let window = popover.contentViewController?.view.window {
                    let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
                    print("Menu anchor: \(anchor); dropdown: \(window.frame); gap: \(anchor.minY - window.frame.maxY)pt")
                }
                popover.performClose(nil)
                print("Closed dropdown released its view: \(popover.contentViewController == nil)")
                assert(popover.contentViewController == nil)
                NSApp.terminate(nil)
            }
        }
        #endif
    }

    private func updateStatus() {
        let stale = model.error != nil
        item.button?.title = (model.snapshot?.menuTitle ?? "—%") + (stale ? " !" : "")
        let label: String
        if let usage = model.snapshot {
            label = "Kiro: \(usage.percentage) used, \(UsageSnapshot.credits(usage.remaining)) credits left"
                + (usage.isOverage ? ", \(UsageSnapshot.credits(usage.overage)) overage credits" : "")
                + (stale ? ". Update failed; showing last known usage." : "")
        } else { label = "Kiro Tracker: \(model.error ?? "Loading usage")" }
        item.button?.toolTip = label
        item.button?.setAccessibilityLabel(label)
        if popover.isShown { alignPopover() }
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil); return }
        guard let button = item.button else { return }
        popover.contentViewController = NSHostingController(rootView: TrackerView(model: model))
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        alignPopover()
        // Check for new usage when the dropdown opens.
        Task { await model.refresh() }
    }

    func popoverDidClose(_ notification: Notification) {
        // Free the dropdown view when it closes.
        popover.contentViewController = nil
    }

    private func alignPopover() {
        guard let button = item.button, let statusWindow = button.window,
              let window = popover.contentViewController?.view.window else { return }
        let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        // Keep the dropdown four points below the menu bar.
        window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: anchor.minY - 4))
    }

    func applicationWillTerminate(_ notification: Notification) {
        polling?.cancel()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }
}

@main
enum KiroTrackerMain {
    @MainActor static func main() async {
        if CommandLine.arguments.contains("--help") {
            print("""
            Kiro Tracker — native macOS menu-bar usage tracker
              --check           Fetch usage once and exit without opening the GUI
              --database PATH   Use a custom Kiro CLI SQLite database (read-only)
              --help            Show this help
            Database precedence: --database, KIRO_TRACKER_DATABASE_PATH, then the
            current user's standard Application Support/kiro-cli/data.sqlite3.
            """)
            return
        }
        #if DEBUG
        if CommandLine.arguments.contains("--render-previews") {
            _ = NSApplication.shared
            do { try renderPreviews() } catch { print(error); exit(1) }
            return
        }
        #endif
        // Check live usage without opening the app.
        if CommandLine.arguments.contains("--check") {
            do {
                let usage = try await KiroClient().fetch()
                print("\(usage.plan): \(UsageSnapshot.credits(usage.used))/\(UsageSnapshot.credits(usage.limit)) credits; overage \(UsageSnapshot.credits(usage.overage)); menu \(usage.menuTitle)")
            } catch {
                print("Usage check failed: \(error.localizedDescription)")
                exit(1)
            }
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    #if DEBUG
    @MainActor private static func renderPreviews() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiro-tracker-previews-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, total, overage) in [("green", 147.27, 0.0), ("yellow", 750.0, 0.0),
                                     ("red", 950.0, 0.0), ("overage", 1250.0, 250.0)] {
            let row: [String: Any] = ["resourceType": "CREDIT", "currentUsageWithPrecision": total,
                "usageLimit": 1000, "currentOveragesWithPrecision": overage,
                "overageCap": 10000, "nextDateReset": 1796083200]
            let data = try JSONSerialization.data(withJSONObject: ["usageBreakdownList": [row],
                "subscriptionInfo": ["subscriptionTitle": "KIRO PRO"]])
            let model = TrackerModel()
            model.snapshot = try UsageSnapshot.decode(data)
            let renderer = ImageRenderer(content: TrackerView(model: model)
                .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .light))
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw TrackerError.invalidUsage
            }
            try png.write(to: folder.appendingPathComponent("\(name).png"))
        }
        print("Rendered synthetic UI states to \(folder.path)")
    }
    #endif
}
