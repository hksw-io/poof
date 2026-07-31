import CoreGraphics
import Foundation
import SwiftUI

@main
struct PoofMediaGenerator {
  private static let macSize = CGSize(width: 640, height: 400)
  private static let optionsSize = CGSize(width: 940, height: 580)
  // The dense middle pose stays recognizable without requiring motion.
  private static let stillFrameIndex = 3
  private static let optionsStillFrameIndex =
    CaptureFrame.optionSequence.count / 2

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
      let optionsGIFURL = outputDirectory.appending(
        path: "poof-options-\(suffix).gif"
      )
      let macFrames = try write(
        to: macGIFURL,
        size: macSize
      ) { frame in
        MacPreview(appearance: appearance, frame: frame)
      }

      let optionsFrames = try write(
        to: optionsGIFURL,
        size: optionsSize,
        frames: CaptureFrame.optionSequence
      ) { frame in
        OptionsPreview(appearance: appearance, frame: frame)
      }

      // Stills come from the rendered frames, not from the GIF that was just
      // written, so they keep their full color depth.
      try StillWriter.write(
        macFrames[stillFrameIndex].image,
        to: outputDirectory.appending(
          path: "poof-macos-\(suffix).png"
        )
      )
      try StillWriter.write(
        optionsFrames[optionsStillFrameIndex].image,
        to: outputDirectory.appending(
          path: "poof-options-\(suffix).png"
        )
      )
    }
  }

  @MainActor
  @discardableResult
  private static func write<Content: View>(
    to url: URL,
    size: CGSize,
    frames captureFrames: [CaptureFrame] = CaptureFrame.sequence,
    content: (CaptureFrame) -> Content
  ) throws -> [GIFFrame] {
    let frames = try captureFrames.map { frame in
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

    return frames
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
