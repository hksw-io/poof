import CoreGraphics
import Foundation
import SwiftUI

@main
struct PoofMediaGenerator {
  private static let macSize = CGSize(width: 640, height: 400)
  private static let platformSize = CGSize(width: 940, height: 650)
  // The dense middle pose stays recognizable without requiring motion.
  private static let stillFrameIndex = 3

  @MainActor
  static func main() throws {
    let outputDirectory = try outputDirectory(from: CommandLine.arguments)
    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )

    for appearance in [ColorScheme.light, .dark] {
      let suffix = appearance == .light ? "light" : "dark"
      let macGIFURL = outputDirectory.appending(
        path: "poof-macos-\(suffix).gif"
      )
      let platformGIFURL = outputDirectory.appending(
        path: "poof-platforms-\(suffix).gif"
      )

      try write(
        to: macGIFURL,
        size: macSize
      ) { frame in
        MacPreview(appearance: appearance, frame: frame)
      }

      try write(
        to: platformGIFURL,
        size: platformSize
      ) { frame in
        PlatformPreview(appearance: appearance, frame: frame)
      }

      try StillWriter.write(
        frameAt: stillFrameIndex,
        from: macGIFURL,
        to: outputDirectory.appending(
          path: "poof-macos-\(suffix).png"
        )
      )
      try StillWriter.write(
        frameAt: stillFrameIndex,
        from: platformGIFURL,
        to: outputDirectory.appending(
          path: "poof-platforms-\(suffix).png"
        )
      )
    }
  }

  @MainActor
  private static func write<Content: View>(
    to url: URL,
    size: CGSize,
    content: (CaptureFrame) -> Content
  ) throws {
    let frames = try CaptureFrame.sequence.map { frame in
      let view = content(frame)
        .frame(width: size.width, height: size.height)
      let renderer = ImageRenderer(content: view)
      renderer.proposedSize = ProposedViewSize(size)
      renderer.scale = 1
      renderer.isOpaque = true
      renderer.colorMode = .nonLinear

      guard let image = renderer.cgImage else {
        throw GeneratorError.cannotRender(url.lastPathComponent)
      }

      return GIFFrame(image: image, delay: frame.delay)
    }

    try GIFWriter.write(frames, to: url)
    print("Wrote \(url.path(percentEncoded: false))")
  }

  private static func outputDirectory(
    from arguments: [String]
  ) throws -> URL {
    let arguments = Array(arguments.dropFirst())

    if arguments.isEmpty {
      return URL(
        filePath: "Documentation/Media",
        directoryHint: .isDirectory
      )
    }

    guard arguments.count == 2, arguments[0] == "--output" else {
      throw GeneratorError.usage
    }

    return URL(filePath: arguments[1], directoryHint: .isDirectory)
  }
}

private enum GeneratorError: Error {
  case cannotRender(String)
  case usage
}
