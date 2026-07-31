import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum StillWriter {
  enum WriteError: Error {
    case cannotCreateDestination
    case cannotCreateImage
    case cannotCreateSource
    case cannotFinalize
  }

  /// Writes a still from the rendered image.
  ///
  /// The still used to be decoded back out of the GIF that had just been
  /// written, which put it through a 256-entry palette on the way: the
  /// committed stills carried as few as 81 distinct colors, banding the window
  /// shadow into visible steps. The renderer's own image is right there.
  static func write(
    _ image: CGImage,
    to outputURL: URL
  ) throws {
    let temporaryURL = FileManager.default.temporaryDirectory.appending(
      path: "\(outputURL.lastPathComponent)-\(UUID().uuidString).png"
    )
    defer {
      try? FileManager.default.removeItem(at: temporaryURL)
    }

    guard
      let destination = CGImageDestinationCreateWithURL(
        temporaryURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      )
    else {
      throw WriteError.cannotCreateDestination
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw WriteError.cannotFinalize
    }

    let data = try Data(contentsOf: temporaryURL)
    if FileManager.default.fileExists(
      atPath: outputURL.path(percentEncoded: false)
    ),
      let existingData = try? Data(contentsOf: outputURL),
      data == existingData
    {
      return
    }

    try data.write(to: outputURL, options: .atomic)
  }
}
