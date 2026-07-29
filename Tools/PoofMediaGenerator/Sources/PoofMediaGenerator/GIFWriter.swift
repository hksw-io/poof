import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct GIFFrame {
  let image: CGImage
  let delay: Double
}

enum GIFWriter {
  // ImageRenderer can move a handful of antialiased edge samples between
  // neighboring values. Keep the committed file when that is the only change.
  private static let maximumChangedChannelsPerFrame = 512
  private static let maximumChannelDelta = 12
  private static let maximumTotalDeltaPerFrame = 4_096

  enum WriteError: Error {
    case cannotCreateDestination
    case cannotFinalize
    case invalidFrame
    case noFrames
  }

  static func write(
    _ frames: [GIFFrame],
    to url: URL,
    loopCount: Int = 0
  ) throws {
    let temporaryURL = FileManager.default.temporaryDirectory.appending(
      path: "\(url.lastPathComponent)-\(UUID().uuidString).gif"
    )
    defer {
      try? FileManager.default.removeItem(at: temporaryURL)
    }

    try encode(frames, to: temporaryURL, loopCount: loopCount)

    if FileManager.default.fileExists(
      atPath: url.path(percentEncoded: false)
    ),
      imagesAreEquivalent(at: temporaryURL, and: url)
    {
      return
    }

    try Data(contentsOf: temporaryURL).write(to: url, options: .atomic)
  }

  private static func encode(
    _ frames: [GIFFrame],
    to url: URL,
    loopCount: Int
  ) throws {
    guard let first = frames.first else {
      throw WriteError.noFrames
    }

    guard
      frames.allSatisfy({
        $0.delay > 0
          && $0.delay.isFinite
          && $0.image.width == first.image.width
          && $0.image.height == first.image.height
      })
    else {
      throw WriteError.invalidFrame
    }

    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.gif.identifier as CFString,
        frames.count,
        nil
      )
    else {
      throw WriteError.cannotCreateDestination
    }

    let fileProperties: [CFString: Any] = [
      kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFLoopCount: loopCount
      ] as CFDictionary
    ]
    CGImageDestinationSetProperties(
      destination,
      fileProperties as CFDictionary
    )

    for frame in frames {
      let frameProperties: [CFString: Any] = [
        kCGImagePropertyGIFDictionary: [
          kCGImagePropertyGIFDelayTime: frame.delay,
          kCGImagePropertyGIFUnclampedDelayTime: frame.delay,
        ] as CFDictionary
      ]
      CGImageDestinationAddImage(
        destination,
        frame.image,
        frameProperties as CFDictionary
      )
    }

    guard CGImageDestinationFinalize(destination) else {
      throw WriteError.cannotFinalize
    }
  }

  private static func imagesAreEquivalent(
    at firstURL: URL,
    and secondURL: URL
  ) -> Bool {
    guard
      let first = CGImageSourceCreateWithURL(firstURL as CFURL, nil),
      let second = CGImageSourceCreateWithURL(secondURL as CFURL, nil),
      CGImageSourceGetCount(first) == CGImageSourceGetCount(second),
      loopCountsMatch(first, second)
    else {
      return false
    }

    for index in 0..<CGImageSourceGetCount(first) {
      guard
        delaysMatch(first, second, at: index),
        let firstImage = CGImageSourceCreateImageAtIndex(first, index, nil),
        let secondImage = CGImageSourceCreateImageAtIndex(second, index, nil),
        firstImage.width == secondImage.width,
        firstImage.height == secondImage.height,
        let firstPixels = rgbaPixels(for: firstImage),
        let secondPixels = rgbaPixels(for: secondImage),
        pixelsAreEquivalent(firstPixels, secondPixels)
      else {
        return false
      }
    }

    return true
  }

  private static func loopCountsMatch(
    _ first: CGImageSource,
    _ second: CGImageSource
  ) -> Bool {
    loopCount(in: first) == loopCount(in: second)
  }

  private static func loopCount(in source: CGImageSource) -> Int? {
    guard
      let properties = CGImageSourceCopyProperties(source, nil)
        as? [CFString: Any],
      let gif = properties[kCGImagePropertyGIFDictionary]
        as? [CFString: Any],
      let count = gif[kCGImagePropertyGIFLoopCount] as? NSNumber
    else {
      return nil
    }

    return count.intValue
  }

  private static func delaysMatch(
    _ first: CGImageSource,
    _ second: CGImageSource,
    at index: Int
  ) -> Bool {
    guard
      let firstDelay = delay(in: first, at: index),
      let secondDelay = delay(in: second, at: index)
    else {
      return false
    }

    return abs(firstDelay - secondDelay) < 0.001
  }

  private static func delay(
    in source: CGImageSource,
    at index: Int
  ) -> Double? {
    guard
      let properties = CGImageSourceCopyPropertiesAtIndex(
        source,
        index,
        nil
      ) as? [CFString: Any],
      let gif = properties[kCGImagePropertyGIFDictionary]
        as? [CFString: Any],
      let delay = gif[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber
    else {
      return nil
    }

    return delay.doubleValue
  }

  private static func rgbaPixels(for image: CGImage) -> [UInt8]? {
    let bytesPerRow = image.width * 4
    var pixels = [UInt8](
      repeating: 0,
      count: bytesPerRow * image.height
    )

    guard
      let context = CGContext(
        data: &pixels,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      return nil
    }

    context.draw(
      image,
      in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    return pixels
  }

  static func pixelsAreEquivalent(
    _ first: [UInt8],
    _ second: [UInt8]
  ) -> Bool {
    guard first.count == second.count else {
      return false
    }

    var changedChannels = 0
    var totalDelta = 0

    for (firstChannel, secondChannel) in zip(first, second) {
      let delta = abs(Int(firstChannel) - Int(secondChannel))
      guard delta <= maximumChannelDelta else {
        return false
      }

      if delta > 0 {
        changedChannels += 1
        totalDelta += delta

        guard
          changedChannels <= maximumChangedChannelsPerFrame,
          totalDelta <= maximumTotalDeltaPerFrame
        else {
          return false
        }
      }
    }

    return true
  }
}
