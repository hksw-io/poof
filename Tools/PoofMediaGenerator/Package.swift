// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "PoofMediaGenerator",
  platforms: [
    .macOS(.v26)
  ],
  dependencies: [
    .package(path: "../..")
  ],
  targets: [
    .executableTarget(
      name: "PoofMediaGenerator",
      dependencies: [
        .product(name: "Poof", package: "poof")
      ]
    ),
    .testTarget(
      name: "PoofMediaGeneratorTests",
      dependencies: ["PoofMediaGenerator"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
