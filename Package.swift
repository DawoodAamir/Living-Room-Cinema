// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "CinemaCore", platforms: [.macOS(.v15)], products: [.library(name: "CinemaCore", targets: ["CinemaCore"])], targets: [.target(name: "CinemaCore", path: "Sources/Core"), .testTarget(name: "CinemaTests", dependencies: ["CinemaCore"], path: "Tests/Core")])
