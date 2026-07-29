import CoreGraphics
import SwiftUI
import Testing

@testable import Poof

@MainActor
@Suite("SwiftUI rendering")
struct PoofRenderingTests {
  @Test("The endpoint frames are transparent")
  func endpointsAreTransparent() throws {
    let first = try #require(snapshot(progress: 0))
    let last = try #require(snapshot(progress: 1))

    #expect(first.statistics.alphaTotal == 0)
    #expect(last.statistics.alphaTotal == 0)
  }

  @Test("Each pose is held without interpolation")
  func hardPoseIntervals() throws {
    let intervals: [(Double, Double)] = [
      (0.01, 0.19),
      (0.21, 0.39),
      (0.41, 0.59),
      (0.61, 0.79),
      (0.81, 0.99),
    ]

    for interval in intervals {
      let beginning = try #require(
        snapshot(
          progress: interval.0,
          reducesTransparency: true
        )
      )
      let end = try #require(
        snapshot(
          progress: interval.1,
          reducesTransparency: true
        )
      )

      #expect(beginning.normalizedDifference(from: end) < 0.01)
      #expect(beginning.statistics.bounds == end.statistics.bounds)
    }
  }

  @Test("Later poses lose mass and contract")
  func laterPosesContract() throws {
    let puffs = try #require(snapshot(progress: 0.50))
    let wisps = try #require(snapshot(progress: 0.70))
    let ringlets = try #require(snapshot(progress: 0.90))
    let puffsBounds = try #require(puffs.statistics.bounds)
    let wispsBounds = try #require(wisps.statistics.bounds)
    let ringletsBounds = try #require(ringlets.statistics.bounds)

    #expect(puffs.statistics.alphaTotal > wisps.statistics.alphaTotal)
    #expect(wisps.statistics.alphaTotal > ringlets.statistics.alphaTotal)
    #expect(puffsBounds.area > wispsBounds.area)
    #expect(wispsBounds.area > ringletsBounds.area)
    #expect(puffsBounds.width > ringletsBounds.width)
    #expect(puffsBounds.height > ringletsBounds.height)
  }

  @Test("Light and dark appearances use identical monochrome art")
  func lightAndDarkArtMatches() throws {
    let light = try #require(
      snapshot(progress: 0.30, colorScheme: .light)
    )
    let dark = try #require(
      snapshot(progress: 0.30, colorScheme: .dark)
    )

    #expect(light.normalizedDifference(from: dark) < 0.005)
    #expect(light.statistics.bounds == dark.statistics.bounds)
  }

  @Test("Drawing waits for an unseeded playback variation")
  func unseededPlaybackWaitsForVariation() throws {
    let waiting = try #require(
      snapshot(progress: 0.50, variationSeed: nil)
    )
    let ready = try #require(
      snapshot(progress: 0.50, variationSeed: 0x504F_4F46)
    )

    #expect(waiting.statistics.alphaTotal == 0)
    #expect(ready.statistics.alphaTotal > 0)
  }

  @Test("Reduce Motion removes spatial drawing")
  func reduceMotionIsBlank() throws {
    let image = try #require(
      snapshot(progress: 0.50, reducesMotion: true)
    )

    #expect(image.statistics.alphaTotal == 0)
    #expect(image.statistics.bounds == nil)
  }

  @Test("Reduce Transparency removes haze and strengthens smoke")
  func reduceTransparency() throws {
    let standard = try #require(snapshot(progress: 0.70))
    let reduced = try #require(
      snapshot(progress: 0.70, reducesTransparency: true)
    )

    #expect(standard.pixels != reduced.pixels)
    #expect(
      reduced.statistics.lowAlphaPixelCount
        < standard.statistics.lowAlphaPixelCount
    )
    #expect(
      reduced.statistics.averageVisibleAlpha
        > standard.statistics.averageVisibleAlpha
    )
  }

  @Test("Increased Contrast darkens edge detail")
  func increasedContrast() throws {
    let standard = try #require(
      snapshot(progress: 0.30, contrast: .standard)
    )
    let increased = try #require(
      snapshot(progress: 0.30, contrast: .increased)
    )

    #expect(standard.pixels != increased.pixels)
    #expect(
      increased.statistics.averageLuminance
        < standard.statistics.averageLuminance
    )
  }

  @Test("Doubling the art size doubles its bounds")
  func artScalesFrom42To84Points() throws {
    let small = try #require(
      snapshot(progress: 0.50, width: 42, height: 42)
    )
    let large = try #require(
      snapshot(progress: 0.50, width: 84, height: 84)
    )
    let smallBounds = try #require(small.statistics.bounds)
    let largeBounds = try #require(large.statistics.bounds)

    #expect(large.width == small.width * 2)
    #expect(large.height == small.height * 2)
    #expect(
      abs(Double(largeBounds.width) / Double(smallBounds.width) - 2)
        < 0.12
    )
    #expect(
      abs(Double(largeBounds.height) / Double(smallBounds.height) - 2)
        < 0.12
    )

    let alphaScale =
      Double(large.statistics.alphaTotal)
      / Double(small.statistics.alphaTotal)
    #expect(alphaScale > 3.6)
    #expect(alphaScale < 4.4)
  }

  @Test("Display scale preserves point geometry")
  func displayScalePreservesGeometry() throws {
    let oneX = try #require(
      snapshot(
        progress: 0.50,
        width: 42,
        height: 42,
        renderScale: 1
      )
    )
    let threeX = try #require(
      snapshot(
        progress: 0.50,
        width: 42,
        height: 42,
        renderScale: 3
      )
    )
    let oneXBounds = try #require(oneX.statistics.bounds)
    let threeXBounds = try #require(threeX.statistics.bounds)

    #expect(threeX.width == oneX.width * 3)
    #expect(threeX.height == oneX.height * 3)
    #expect(
      abs(Double(threeXBounds.width) / Double(oneXBounds.width) - 3)
        < 0.15
    )
    #expect(
      abs(Double(threeXBounds.height) / Double(oneXBounds.height) - 3)
        < 0.15
    )
  }

  @Test("Field scale adds padding without scaling the art")
  func fieldScaleOnlyAddsPadding() throws {
    let compactField = try #require(
      snapshot(
        progress: 0.50,
        width: 63,
        height: 63,
        artScale: 1.5
      )
    )
    let wideField = try #require(
      snapshot(
        progress: 0.50,
        width: 126,
        height: 126,
        artScale: 3
      )
    )
    let compactBounds = try #require(compactField.statistics.bounds)
    let wideBounds = try #require(wideField.statistics.bounds)

    #expect(wideField.width == compactField.width * 2)
    #expect(wideField.height == compactField.height * 2)
    #expect(abs(wideBounds.width - compactBounds.width) <= 2)
    #expect(abs(wideBounds.height - compactBounds.height) <= 2)

    let alphaRatio =
      Double(wideField.statistics.alphaTotal)
      / Double(compactField.statistics.alphaTotal)
    #expect(alphaRatio > 0.92)
    #expect(alphaRatio < 1.08)
  }

  @Test("Variation seeds make small stable changes")
  func seedVariation() throws {
    let first = try #require(
      snapshot(progress: 0.50, variationSeed: 0x1111)
    )
    let repeated = try #require(
      snapshot(progress: 0.50, variationSeed: 0x1111)
    )
    let second = try #require(
      snapshot(progress: 0.50, variationSeed: 0x2222)
    )
    let firstBounds = try #require(first.statistics.bounds)
    let repeatedBounds = try #require(repeated.statistics.bounds)
    let secondBounds = try #require(second.statistics.bounds)

    #expect(first.normalizedDifference(from: repeated) < 0.002)
    #expect(firstBounds == repeatedBounds)
    #expect(first.pixels != second.pixels)
    #expect(abs(firstBounds.width - secondBounds.width) <= 4)
    #expect(abs(firstBounds.height - secondBounds.height) <= 4)

    let alphaRatio =
      Double(second.statistics.alphaTotal)
      / Double(first.statistics.alphaTotal)
    #expect(alphaRatio > 0.88)
    #expect(alphaRatio < 1.12)
    #expect(first.normalizedDifference(from: second) < 0.08)
  }

  @Test("Opening silhouettes match the measured reference size")
  func openingSilhouetteSizes() throws {
    let cloudImage = try #require(snapshot(progress: 0.1))
    let clusterImage = try #require(snapshot(progress: 0.3))
    let cloud = try #require(cloudImage.statistics.bounds)
    let clusters = try #require(clusterImage.statistics.bounds)

    #expect((79...83).contains(cloud.width))
    #expect((72...76).contains(cloud.height))
    #expect((76...80).contains(clusters.width))
    #expect((72...76).contains(clusters.height))
  }

  @Test("Legacy measurements hold at every reference size")
  func legacyMeasurementEnvelope() throws {
    let progresses = [0.1, 0.3, 0.5, 0.7, 0.9]
    let references = LegacyReference.all

    for reference in references {
      var measurements: [LegacyMeasurement] = []

      for (index, progress) in progresses.enumerated() {
        let image = try #require(
          snapshot(
            progress: progress,
            width: Double(reference.size),
            height: Double(reference.size)
          )
        )
        let measurement = try #require(image.legacyMeasurement())
        let expectedBounds = reference.bounds[index]
        let expectedMass = reference.normalizedAlphaMass[index]
        let expectedCentroid = reference.normalizedCentroids[index]
        let centroidTolerance = index == 4 ? 0.030 : 0.025
        let relativeMassTolerance = index == 4 ? 0.15 : 0.10
        let absoluteMassFloor = index == 4 ? 0.008 : 0.012
        let massTolerance = max(
          expectedMass * relativeMassTolerance,
          absoluteMassFloor
        )

        #expect(
          abs(measurement.bounds.width - expectedBounds.width)
            <= reference.dimensionTolerance
        )
        #expect(
          abs(measurement.bounds.height - expectedBounds.height)
            <= reference.dimensionTolerance
        )
        #expect(
          abs(measurement.normalizedAlphaMass - expectedMass)
            <= massTolerance
        )
        #expect(
          abs(
            measurement.normalizedCentroid.x
              - expectedCentroid.x
          ) <= centroidTolerance
        )
        #expect(
          abs(
            measurement.normalizedCentroid.y
              - expectedCentroid.y
          ) <= centroidTolerance
        )
        #expect(
          reference.connectedComponentRanges[index].contains(
            measurement.connectedComponentCount
          )
        )

        measurements.append(measurement)
      }

      let openingMass = measurements[0].normalizedAlphaMass
      let measuredRatios = measurements.map {
        $0.normalizedAlphaMass / openingMass
      }

      for (index, ratio) in measuredRatios.enumerated() {
        #expect(
          abs(ratio - LegacyReference.alphaMassRatios[index])
            <= LegacyReference.alphaMassRatioTolerances[index]
        )
      }
    }
  }

  private func snapshot(
    progress: Double,
    colorScheme: ColorScheme = .light,
    contrast: ColorSchemeContrast = .standard,
    reducesMotion: Bool = false,
    reducesTransparency: Bool = false,
    width: Double = 84,
    height: Double = 84,
    renderScale: Double = 1,
    artScale: Double = 1,
    variationSeed: UInt64? = 0x504F_4F46
  ) -> PixelSnapshot? {
    let configuration = PoofConfiguration(seed: 0x504F_4F46)
    let content = PoofCanvas(
      progress: progress,
      palette: PoofPalette(
        colorScheme: colorScheme,
        contrast: contrast
      ),
      reducesMotion: reducesMotion,
      reducesTransparency: reducesTransparency,
      artScale: artScale,
      frameSet: variationSeed.map { seed in
        PoofSimulation.makeFrameSet(
          configuration: configuration,
          variationSeed: seed
        )
      }
    )
    .frame(width: width, height: height)
    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(width: width, height: height)
    renderer.scale = renderScale

    guard let image = renderer.cgImage else {
      return nil
    }

    return PixelSnapshot(image: image)
  }
}

private struct PixelSnapshot {
  let width: Int
  let height: Int
  let pixels: [UInt8]
  let statistics: PixelStatistics

  init(image: CGImage) {
    width = image.width
    height = image.height

    let bytesPerRow = image.width * 4
    var pixels = [UInt8](
      repeating: 0,
      count: bytesPerRow * image.height
    )

    pixels.withUnsafeMutableBytes { buffer in
      let context = CGContext(
        data: buffer.baseAddress,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
      context?.draw(
        image,
        in: CGRect(
          x: 0,
          y: 0,
          width: image.width,
          height: image.height
        )
      )
    }

    self.pixels = pixels
    statistics = PixelStatistics(
      pixels: pixels,
      width: image.width,
      height: image.height
    )
  }

  func normalizedDifference(from other: PixelSnapshot) -> Double {
    guard pixels.count == other.pixels.count else {
      return 1
    }

    let totalDifference = zip(pixels, other.pixels).reduce(0) {
      $0 + abs(Int($1.0) - Int($1.1))
    }
    return Double(totalDifference)
      / Double(pixels.count * Int(UInt8.max))
  }

  func legacyMeasurement() -> LegacyMeasurement? {
    let alphaBoundsThreshold: UInt8 = 13
    let alphaMassThreshold: UInt8 = 3
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    var alphaMass = 0.0
    var weightedX = 0.0
    var weightedY = 0.0

    for offset in stride(from: 0, to: pixels.count, by: 4) {
      let alpha = pixels[offset + 3]
      let pixelIndex = offset / 4
      let x = pixelIndex % width
      let y = pixelIndex / width

      if alpha >= alphaBoundsThreshold {
        minimumX = min(minimumX, x)
        minimumY = min(minimumY, y)
        maximumX = max(maximumX, x)
        maximumY = max(maximumY, y)
      }

      guard alpha >= alphaMassThreshold else {
        continue
      }

      let weight = Double(alpha) / Double(UInt8.max)
      alphaMass += weight
      weightedX += Double(x) * weight
      weightedY += Double(y) * weight
    }

    guard
      alphaMass > 0,
      maximumX >= minimumX,
      maximumY >= minimumY
    else {
      return nil
    }

    return LegacyMeasurement(
      bounds: PixelBounds(
        minimumX: minimumX,
        minimumY: minimumY,
        maximumX: maximumX,
        maximumY: maximumY
      ),
      normalizedAlphaMass: alphaMass / Double(width * height),
      normalizedCentroid: CGPoint(
        x: (weightedX / alphaMass - Double(width) / 2)
          / Double(width),
        y: (weightedY / alphaMass - Double(height) / 2)
          / Double(height)
      ),
      connectedComponentCount: connectedComponentCount(
        luminanceThreshold: 16,
        minimumArea: 4
      )
    )
  }

  private func connectedComponentCount(
    luminanceThreshold: Int,
    minimumArea: Int
  ) -> Int {
    var included = [Bool](repeating: false, count: width * height)

    for pixelIndex in included.indices {
      let offset = pixelIndex * 4
      let luminance =
        (2_126 * Int(pixels[offset])
          + 7_152 * Int(pixels[offset + 1])
          + 722 * Int(pixels[offset + 2])) / 10_000
      included[pixelIndex] = luminance >= luminanceThreshold
    }

    var visited = [Bool](repeating: false, count: included.count)
    var componentCount = 0

    for start in included.indices
    where included[start] && visited[start] == false {
      var stack = [start]
      var area = 0
      visited[start] = true

      while let pixelIndex = stack.popLast() {
        area += 1
        let x = pixelIndex % width
        let y = pixelIndex / width

        for deltaY in -1...1 {
          for deltaX in -1...1
          where deltaX != 0 || deltaY != 0 {
            let neighborX = x + deltaX
            let neighborY = y + deltaY

            guard
              (0..<width).contains(neighborX),
              (0..<height).contains(neighborY)
            else {
              continue
            }

            let neighbor = neighborY * width + neighborX
            guard included[neighbor], visited[neighbor] == false else {
              continue
            }

            visited[neighbor] = true
            stack.append(neighbor)
          }
        }
      }

      if area >= minimumArea {
        componentCount += 1
      }
    }

    return componentCount
  }
}

private struct LegacyMeasurement {
  let bounds: PixelBounds
  let normalizedAlphaMass: Double
  let normalizedCentroid: CGPoint
  let connectedComponentCount: Int
}

private struct LegacyReference {
  static let alphaMassRatios = [
    1.0000,
    0.9175,
    0.6350,
    0.2804,
    0.0886,
  ]

  static let alphaMassRatioTolerances = [
    0.0001,
    0.025,
    0.025,
    0.020,
    0.012,
  ]

  // Numeric envelopes preserve the measured public behavior without storing
  // or deriving artwork from the legacy implementation.
  static let all = [
    LegacyReference(
      size: 42,
      bounds: [
        PixelSize(width: 40, height: 36),
        PixelSize(width: 38, height: 37),
        PixelSize(width: 37, height: 36),
        PixelSize(width: 28, height: 33),
        PixelSize(width: 24, height: 27),
      ],
      normalizedAlphaMass: [
        0.5508,
        0.5048,
        0.3485,
        0.1541,
        0.0489,
      ],
      normalizedCentroids: [
        CGPoint(x: -0.0149, y: -0.0333),
        CGPoint(x: -0.0155, y: -0.0106),
        CGPoint(x: -0.0113, y: -0.0195),
        CGPoint(x: -0.0260, y: -0.0003),
        CGPoint(x: -0.0579, y: -0.0130),
      ],
      connectedComponentRanges: [
        1...2,
        1...2,
        1...8,
        8...12,
        10...13,
      ],
      dimensionTolerance: 2
    ),
    LegacyReference(
      size: 84,
      bounds: [
        PixelSize(width: 81, height: 73),
        PixelSize(width: 78, height: 74),
        PixelSize(width: 75, height: 73),
        PixelSize(width: 57, height: 68),
        PixelSize(width: 50, height: 56),
      ],
      normalizedAlphaMass: [
        0.5645,
        0.5180,
        0.3589,
        0.1583,
        0.0499,
      ],
      normalizedCentroids: [
        CGPoint(x: -0.0090, y: -0.0274),
        CGPoint(x: -0.0096, y: -0.0045),
        CGPoint(x: -0.0053, y: -0.0134),
        CGPoint(x: -0.0200, y: 0.0058),
        CGPoint(x: -0.0528, y: -0.0062),
      ],
      connectedComponentRanges: [
        1...2,
        1...2,
        6...10,
        10...19,
        10...14,
      ],
      dimensionTolerance: 3
    ),
    LegacyReference(
      size: 97,
      bounds: [
        PixelSize(width: 95, height: 85),
        PixelSize(width: 91, height: 86),
        PixelSize(width: 88, height: 86),
        PixelSize(width: 67, height: 80),
        PixelSize(width: 58, height: 65),
      ],
      normalizedAlphaMass: [
        0.5783,
        0.5310,
        0.3680,
        0.1625,
        0.0514,
      ],
      normalizedCentroids: [
        CGPoint(x: -0.0082, y: -0.0268),
        CGPoint(x: -0.0088, y: -0.0037),
        CGPoint(x: -0.0046, y: -0.0127),
        CGPoint(x: -0.0196, y: 0.0073),
        CGPoint(x: -0.0524, y: -0.0054),
      ],
      connectedComponentRanges: [
        1...2,
        1...2,
        8...13,
        13...20,
        11...15,
      ],
      dimensionTolerance: 3
    ),
  ]

  let size: Int
  let bounds: [PixelSize]
  let normalizedAlphaMass: [Double]
  let normalizedCentroids: [CGPoint]
  let connectedComponentRanges: [ClosedRange<Int>]
  let dimensionTolerance: Int
}

private struct PixelSize {
  let width: Int
  let height: Int
}

private struct PixelStatistics {
  let alphaTotal: UInt64
  let lowAlphaPixelCount: Int
  let averageVisibleAlpha: Double
  let averageLuminance: Double
  let bounds: PixelBounds?

  init(pixels: [UInt8], width: Int, height: Int) {
    var alphaTotal: UInt64 = 0
    var visibleAlphaTotal: UInt64 = 0
    var visiblePixelCount = 0
    var lowAlphaPixelCount = 0
    var luminanceTotal: UInt64 = 0
    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1

    for offset in stride(from: 0, to: pixels.count, by: 4) {
      let alpha = pixels[offset + 3]
      alphaTotal += UInt64(alpha)

      guard alpha > 8 else {
        continue
      }

      let pixelIndex = offset / 4
      let x = pixelIndex % width
      let y = pixelIndex / width
      minimumX = min(minimumX, x)
      minimumY = min(minimumY, y)
      maximumX = max(maximumX, x)
      maximumY = max(maximumY, y)
      visibleAlphaTotal += UInt64(alpha)
      visiblePixelCount += 1
      luminanceTotal +=
        UInt64(pixels[offset])
        + UInt64(pixels[offset + 1])
        + UInt64(pixels[offset + 2])

      if alpha < 128 {
        lowAlphaPixelCount += 1
      }
    }

    self.alphaTotal = alphaTotal
    self.lowAlphaPixelCount = lowAlphaPixelCount
    averageVisibleAlpha =
      visiblePixelCount == 0
      ? 0
      : Double(visibleAlphaTotal) / Double(visiblePixelCount)
    averageLuminance =
      visiblePixelCount == 0
      ? 0
      : Double(luminanceTotal) / Double(visiblePixelCount * 3)
    bounds =
      maximumX < minimumX || maximumY < minimumY
      ? nil
      : PixelBounds(
        minimumX: minimumX,
        minimumY: minimumY,
        maximumX: maximumX,
        maximumY: maximumY
      )
  }
}

private struct PixelBounds: Equatable {
  let minimumX: Int
  let minimumY: Int
  let maximumX: Int
  let maximumY: Int

  var width: Int {
    maximumX - minimumX + 1
  }

  var height: Int {
    maximumY - minimumY + 1
  }

  var area: Int {
    width * height
  }
}
