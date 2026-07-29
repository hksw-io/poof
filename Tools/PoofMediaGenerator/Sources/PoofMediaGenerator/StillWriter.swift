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

  static func write(
    frameAt index: Int,
    from sourceURL: URL,
    to outputURL: URL
  ) throws {
    guard
      let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)
    else {
      throw WriteError.cannotCreateSource
    }
    guard
      let image = CGImageSourceCreateImageAtIndex(source, index, nil)
    else {
      throw WriteError.cannotCreateImage
    }

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
