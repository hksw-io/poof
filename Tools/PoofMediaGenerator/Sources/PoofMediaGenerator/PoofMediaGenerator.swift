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
  static func main() async throws {
    let request = try request(from: CommandLine.arguments)
    try FileManager.default.createDirectory(
      at: request.outputDirectory,
      withIntermediateDirectories: true
    )

    switch request.kind {
    case .documentation:
      try documentation(in: request.outputDirectory)
    case .social:
      try await social(in: request.outputDirectory)
    }
  }

  /// The clips for a social post.
  ///
  /// These are deliberately not part of `make media`: they are not committed,
  /// nothing pixel-compares them, and they are cut for a feed rather than for
  /// the README.
  @MainActor
  private static func social(in outputDirectory: URL) async throws {
    let clips:
      [(name: String, size: CGSize, frames: [CaptureFrame], view: (CaptureFrame) -> AnyView)] = [
        (
          "poof-grid", SocialGrid.size, SocialSequence.grid,
          { AnyView(SocialGrid(frame: $0)) }
        ),
        (
          "poof-hero", SocialHero.size, SocialSequence.hero,
          { AnyView(SocialHero(frame: $0)) }
        ),
      ]

    for clip in clips {
      let frames = try render(
        clip.frames,
        size: clip.size,
        content: clip.view
      )
      let videoURL = outputDirectory.appending(path: "\(clip.name).mp4")

      try await VideoWriter.write(
        frames.map { VideoFrame(image: $0.image, duration: $0.delay) },
        to: videoURL,
        size: clip.size
      )
      print("Wrote \(videoURL.path(percentEncoded: false))")

      let gifURL = outputDirectory.appending(path: "\(clip.name).gif")
      try GIFWriter.write(frames, to: gifURL)
      print("Wrote \(gifURL.path(percentEncoded: false))")
    }
  }

  @MainActor
  private static func documentation(in outputDirectory: URL) throws {
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
    let frames = try render(captureFrames, size: size, content: content)

    try GIFWriter.write(frames, to: url)
    print("Wrote \(url.path(percentEncoded: false))")

    return frames
  }

  @MainActor
  private static func render<Content: View>(
    _ captureFrames: [CaptureFrame],
    size: CGSize,
    content: (CaptureFrame) -> Content
  ) throws -> [GIFFrame] {
    try captureFrames.map { frame in
      let view = content(frame)
        .frame(width: size.width, height: size.height)
      let renderer = ImageRenderer(content: view)
      renderer.proposedSize = ProposedViewSize(size)
      renderer.scale = 1
      renderer.isOpaque = true
      renderer.colorMode = .nonLinear

      guard let image = renderer.cgImage else {
        throw GeneratorError.cannotRender("\(size)")
      }

      return GIFFrame(image: image, delay: frame.delay)
    }
  }

  struct Request {
    enum Kind {
      case documentation
      case social
    }

    let kind: Kind
    let outputDirectory: URL
  }

  static func request(from arguments: [String]) throws -> Request {
    let arguments = Array(arguments.dropFirst())

    if arguments.isEmpty {
      return Request(
        kind: .documentation,
        outputDirectory: URL(
          filePath: "Documentation/Media",
          directoryHint: .isDirectory
        )
      )
    }

    guard arguments.count == 2 else {
      throw GeneratorError.usage
    }

    let directory = URL(filePath: arguments[1], directoryHint: .isDirectory)

    switch arguments[0] {
    case "--output":
      return Request(kind: .documentation, outputDirectory: directory)
    case "--social":
      return Request(kind: .social, outputDirectory: directory)
    default:
      throw GeneratorError.usage
    }
  }
}

private enum GeneratorError: Error {
  case cannotRender(String)
  case usage
}
