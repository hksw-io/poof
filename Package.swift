// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "Poof",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
    .tvOS(.v26),
    .watchOS(.v26),
    .visionOS(.v26),
  ],
  products: [
    .library(name: "Poof", targets: ["Poof"]),
    .executable(name: "PoofDemo", targets: ["PoofDemo"]),
  ],
  targets: [
    .target(name: "Poof"),
    .executableTarget(
      name: "PoofDemo",
      dependencies: ["Poof"],
      resources: [.process("Resources")]
    ),
    .testTarget(name: "PoofDemoTests", dependencies: ["PoofDemo"]),
    .testTarget(name: "PoofTests", dependencies: ["Poof"]),
  ],
  swiftLanguageModes: [.v6]
)
