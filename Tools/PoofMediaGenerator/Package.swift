// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "PoofMediaGenerator",
  platforms: [
    .macOS(.v26)
  ],
  dependencies: [
    // Name the dependency explicitly. Path dependencies otherwise take their
    // identity from the directory, which breaks in a release tarball or any
    // clone that is not called "poof".
    .package(name: "Poof", path: "../..")
  ],
  targets: [
    .executableTarget(
      name: "PoofMediaGenerator",
      dependencies: [
        .product(name: "Poof", package: "Poof")
      ]
    ),
    .testTarget(
      name: "PoofMediaGeneratorTests",
      dependencies: ["PoofMediaGenerator"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
