// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KiroTracker",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "KiroTracker", targets: ["KiroTracker"])],
    targets: [
        .target(name: "KiroTrackerCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .executableTarget(name: "KiroTracker", dependencies: ["KiroTrackerCore"]),
        .testTarget(name: "KiroTrackerCoreTests", dependencies: ["KiroTrackerCore"])
    ]
)
