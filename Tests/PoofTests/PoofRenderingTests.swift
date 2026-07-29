import CoreGraphics
import SwiftUI
import Testing

@testable import Poof

@MainActor
@Suite("SwiftUI rendering")
struct PoofRenderingTests {
  @Test("The middle frame draws smoke")
  func middleFrameDrawsSmoke() throws {
    let image = try #require(render(progress: 0.38))

    #expect(statistics(for: image).visiblePixelCount > 100)
  }

  @Test("The endpoint frames are transparent")
  func endpointsAreTransparent() throws {
    let first = try #require(render(progress: 0))
    let last = try #require(render(progress: 1))

    #expect(statistics(for: first).alphaTotal == 0)
    #expect(statistics(for: last).alphaTotal == 0)
  }

  @Test("Reduce Motion removes spatial drawing")
  func reduceMotion() throws {
    let image = try #require(
      render(progress: 0.38, reducesMotion: true)
    )

    #expect(statistics(for: image).alphaTotal == 0)
  }

  @Test("Reduce Transparency produces denser smoke")
  func reduceTransparency() throws {
    let standard = try #require(render(progress: 0.60))
    let reduced = try #require(
      render(progress: 0.60, reducesTransparency: true)
    )

    #expect(
      statistics(for: reduced).alphaTotal
        > statistics(for: standard).alphaTotal
    )
  }

  @Test("The palette adapts to light and dark appearances")
  func appearancePalettes() throws {
    let light = try #require(
      render(progress: 0.38, colorScheme: .light)
    )
    let dark = try #require(
      render(progress: 0.38, colorScheme: .dark)
    )
    let lightStatistics = statistics(for: light)
    let darkStatistics = statistics(for: dark)

    #expect(
      darkStatistics.averageLuminance
        > lightStatistics.averageLuminance + 20
    )
  }

  @Test("Increased Contrast strengthens the light-mode palette")
  func increasedContrast() throws {
    let standard = try #require(
      render(progress: 0.38, colorScheme: .light)
    )
    let increased = try #require(
      render(
        progress: 0.38,
        colorScheme: .light,
        contrast: .increased
      )
    )

    #expect(
      statistics(for: increased).averageLuminance
        < statistics(for: standard).averageLuminance - 8
    )
  }

  @Test("Arbitrary sizes render at 1x, 2x, and 3x")
  func arbitrarySizesAndScales() throws {
    let cases: [(width: Double, height: Double, scale: Double)] = [
      (42, 42, 1),
      (84, 42, 2),
      (42, 84, 3),
    ]

    for testCase in cases {
      let image = try #require(
        render(
          progress: 0.38,
          width: testCase.width,
          height: testCase.height,
          scale: testCase.scale
        )
      )

      #expect(image.width == Int(testCase.width * testCase.scale))
      #expect(image.height == Int(testCase.height * testCase.scale))
      #expect(statistics(for: image).visiblePixelCount > 20)
    }
  }

  private func render(
    progress: Double,
    colorScheme: ColorScheme = .light,
    contrast: ColorSchemeContrast = .standard,
    reducesMotion: Bool = false,
    reducesTransparency: Bool = false,
    width: Double = 160,
    height: Double = 160,
    scale: Double = 1
  ) -> CGImage? {
    let content = PoofCanvas(
      progress: progress,
      configuration: .standard,
      palette: PoofPalette(
        colorScheme: colorScheme,
        contrast: contrast
      ),
      reducesMotion: reducesMotion,
      reducesTransparency: reducesTransparency,
      usesBlur: !reducesTransparency && contrast != .increased
    )
    .frame(width: width, height: height)
    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(width: width, height: height)
    renderer.scale = scale
    return renderer.cgImage
  }

  private func statistics(for image: CGImage) -> PixelStatistics {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)

    bytes.withUnsafeMutableBytes { buffer in
      let context = CGContext(
        data: buffer.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
      context?.draw(
        image,
        in: CGRect(x: 0, y: 0, width: width, height: height)
      )
    }

    var visiblePixelCount = 0
    var alphaTotal: UInt64 = 0
    var luminanceTotal: UInt64 = 0

    for offset in stride(from: 0, to: bytes.count, by: 4) {
      let alpha = bytes[offset + 3]
      alphaTotal += UInt64(alpha)

      guard alpha > 8 else {
        continue
      }

      visiblePixelCount += 1
      luminanceTotal +=
        UInt64(bytes[offset])
        + UInt64(bytes[offset + 1])
        + UInt64(bytes[offset + 2])
    }

    let averageLuminance =
      visiblePixelCount == 0
      ? 0
      : Double(luminanceTotal) / Double(visiblePixelCount * 3)

    return PixelStatistics(
      visiblePixelCount: visiblePixelCount,
      alphaTotal: alphaTotal,
      averageLuminance: averageLuminance
    )
  }
}

private struct PixelStatistics {
  let visiblePixelCount: Int
  let alphaTotal: UInt64
  let averageLuminance: Double
}
