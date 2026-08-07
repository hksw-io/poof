import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

struct VideoFrame: Sendable {
  let image: CGImage
  /// How long this image stays on screen, in seconds.
  let duration: Double
}

/// Writes an H.264 MP4 from rendered frames.
///
/// The poof is a sequence of hard pose swaps, so a playback holds each of a
/// handful of images rather than tweening between them. Frames are therefore
/// authored as image-plus-duration and repeated up to the video's frame rate,
/// which keeps the render count at the number of distinct images no matter how
/// long or how smooth the output has to be.
enum VideoWriter {
  enum WriteError: Error {
    case cannotAppend
    case cannotCreatePixelBuffer
    case cannotStart
    case failed(String)
    case noFrames
  }

  /// Social platforms re-encode anyway; this is high enough that they are
  /// re-encoding something clean rather than compounding artifacts.
  private static let bitsPerPixelPerSecond = 0.12

  static func write(
    _ frames: [VideoFrame],
    to url: URL,
    size: CGSize,
    frameRate: Int32 = 30
  ) async throws {
    guard !frames.isEmpty else {
      throw WriteError.noFrames
    }

    try? FileManager.default.removeItem(at: url)

    let width = Int(size.width)
    let height = Int(size.height)
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let bitRate = Int(
      Double(width * height) * Double(frameRate) * bitsPerPixelPerSecond
    )
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: bitRate,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
          // A keyframe every second keeps scrubbing and looping crisp.
          AVVideoMaxKeyFrameIntervalKey: Int(frameRate),
        ],
      ]
    )
    input.expectsMediaDataInRealTime = false

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      ]
    )

    writer.add(input)

    guard writer.startWriting() else {
      throw WriteError.failed(
        writer.error?.localizedDescription ?? "cannot start writing"
      )
    }

    writer.startSession(atSourceTime: .zero)

    var presentedFrame: Int64 = 0

    for frame in frames {
      let count = max(
        Int((frame.duration * Double(frameRate)).rounded()),
        1
      )
      let buffer = try pixelBuffer(
        from: frame.image,
        pool: adaptor.pixelBufferPool,
        width: width,
        height: height
      )

      // The same buffer is presented repeatedly: the encoder reads it at
      // append time, and holding one image is exactly what a pose swap is.
      for _ in 0..<count {
        while !input.isReadyForMoreMediaData {
          try await Task.sleep(for: .milliseconds(2))
        }

        let time = CMTime(value: presentedFrame, timescale: frameRate)

        guard adaptor.append(buffer, withPresentationTime: time) else {
          throw WriteError.failed(
            writer.error?.localizedDescription ?? "cannot append frame"
          )
        }

        presentedFrame += 1
      }
    }

    input.markAsFinished()
    writer.endSession(
      atSourceTime: CMTime(value: presentedFrame, timescale: frameRate)
    )
    await writer.finishWriting()

    if writer.status == .failed {
      throw WriteError.failed(
        writer.error?.localizedDescription ?? "unknown failure"
      )
    }
  }

  private static func pixelBuffer(
    from image: CGImage,
    pool: CVPixelBufferPool?,
    width: Int,
    height: Int
  ) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?

    if let pool {
      CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    }

    if buffer == nil {
      CVPixelBufferCreate(
        nil,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        [
          kCVPixelBufferCGImageCompatibilityKey as String: true,
          kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ] as CFDictionary,
        &buffer
      )
    }

    guard let buffer else {
      throw WriteError.cannotCreatePixelBuffer
    }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer {
      CVPixelBufferUnlockBaseAddress(buffer, [])
    }

    guard
      let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? image.colorSpace!,
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
          | CGBitmapInfo.byteOrder32Little.rawValue
      )
    else {
      throw WriteError.cannotCreatePixelBuffer
    }

    context.draw(
      image,
      in: CGRect(x: 0, y: 0, width: width, height: height)
    )

    return buffer
  }
}
