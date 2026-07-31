import Foundation
import Testing

@testable import Poof

/// The reference source sizes the cover layouts are authored against.
private let sourceCoverReferenceSizes: [(width: Double, height: Double)] = [
  (84, 84),
  (132, 48),
  (48, 132),
]

private func sourceCoverArtSide(
  width: Double,
  height: Double
) -> Double {
  min(max((width * height).squareRoot(), 42), 160)
}

/// The coverage gap search before it learned to stop scanning discs that
/// cannot change the answer. Kept here so the optimization is checked against
/// behavior rather than against recorded numbers, which would pin the result
/// to one architecture.
private func exhaustiveLargestSourceCoverGap(
  among glyphs: ArraySlice<PoofSourceCoverGlyph>,
  seed: UInt64,
  key: UInt64,
  sourceWidth: Double,
  sourceHeight: Double,
  artSide: Double
) -> (x: Double, y: Double) {
  let cellSide = max(artSide * 0.02, 1)
  let columnCount = max(Int(ceil(sourceWidth / cellSide)), 1)
  let rowCount = max(Int(ceil(sourceHeight / cellSide)), 1)
  let cellWidth = sourceWidth / Double(columnCount)
  let cellHeight = sourceHeight / Double(rowCount)
  let discs = glyphs.map { glyph in
    (
      x: sourceWidth * glyph.x,
      y: sourceHeight * glyph.y,
      radius:
        min(
          sourceWidth * glyph.width,
          sourceHeight * glyph.height
        ) * 0.30
    )
  }
  var largestGap = (x: 0.0, y: 0.0)
  var largestDeficit = -Double.infinity

  for row in 0..<rowCount {
    for column in 0..<columnCount {
      let cellKey = key + UInt64(row * columnCount + column) * 0x10
      let point = (
        x:
          -sourceWidth / 2
          + (Double(column)
            + PoofSimulation.coverUnitNoise(
              seed: seed,
              key: cellKey + 1,
              in: 0.28...0.72
            )) * cellWidth,
        y:
          -sourceHeight / 2
          + (Double(row)
            + PoofSimulation.coverUnitNoise(
              seed: seed,
              key: cellKey + 2,
              in: 0.28...0.72
            )) * cellHeight
      )
      var deficit = Double.infinity

      for disc in discs {
        deficit = min(
          deficit,
          hypot(point.x - disc.x, point.y - disc.y) - disc.radius
        )
      }

      let score =
        deficit
        * PoofSimulation.coverUnitNoise(
          seed: seed,
          key: cellKey + 3,
          in: 0.96...1.04
        )

      if score > largestDeficit {
        largestGap = point
        largestDeficit = score
      }
    }
  }

  return largestGap
}

/// The nearest-glyph scan before it was folded into a single pass.
private func exhaustiveSizedSourceCoverGlyphs(
  _ glyphs: [PoofSourceCoverGlyph],
  coverageCount: Int,
  sourceWidth: Double,
  sourceHeight: Double,
  artSide: Double
) -> [Double] {
  let cellSide = max(artSide * 0.02, 1)
  let columnCount = max(Int(ceil(sourceWidth / cellSide)), 1)
  let rowCount = max(Int(ceil(sourceHeight / cellSide)), 1)
  let cellWidth = sourceWidth / Double(columnCount)
  let cellHeight = sourceHeight / Double(rowCount)
  let halfCellDiagonal = hypot(cellWidth, cellHeight) / 2
  var requiredRadii = [Double](repeating: 0, count: glyphs.count)

  for row in 0..<rowCount {
    for column in 0..<columnCount {
      let cellCenterX =
        -sourceWidth / 2 + (Double(column) + 0.5) * cellWidth
      let cellCenterY =
        -sourceHeight / 2 + (Double(row) + 0.5) * cellHeight
      let nearestIndex =
        (0..<coverageCount).min {
          let first = glyphs[$0]
          let second = glyphs[$1]
          return hypot(
            cellCenterX - sourceWidth * first.x,
            cellCenterY - sourceHeight * first.y
          )
            < hypot(
              cellCenterX - sourceWidth * second.x,
              cellCenterY - sourceHeight * second.y
            )
        } ?? 0
      let glyph = glyphs[nearestIndex]
      let farthestDistance =
        hypot(
          cellCenterX - sourceWidth * glyph.x,
          cellCenterY - sourceHeight * glyph.y
        )
        + halfCellDiagonal

      requiredRadii[nearestIndex] = max(
        requiredRadii[nearestIndex],
        farthestDistance
      )
    }
  }

  return requiredRadii
}

@Suite("Poof simulation")
struct PoofSimulationTests {
  @Test("The pruned coverage gap search matches an exhaustive scan")
  func largestSourceCoverGapMatchesExhaustiveScan() {
    for profile in 0..<PoofSimulation.sourceCoverGeometryProfileCount {
      let seed = UInt64(profile)

      for size in sourceCoverReferenceSizes {
        let aspect = PoofSourceCoverAspect(
          size: CGSize(width: size.width, height: size.height)
        )
        let frameSet = PoofSimulation.makeFrameSet(
          configuration: PoofConfiguration(seed: seed),
          coversSource: true,
          sourceCoverAspect: aspect,
          variationSeed: seed
        )
        let glyphs = frameSet.sourceCoverGlyphs(for: aspect)

        guard !glyphs.isEmpty else {
          continue
        }

        let artSide = sourceCoverArtSide(
          width: size.width,
          height: size.height
        )
        let repairStart = PoofSourceCoverLayout.baseGlyphCount
        let repairEnd =
          repairStart + PoofSourceCoverLayout.repairGlyphCount

        for prefix in repairStart..<min(repairEnd, glyphs.count) {
          let key = UInt64(prefix) * 0x100
          let pruned = PoofSimulation.largestSourceCoverGap(
            among: glyphs.prefix(prefix),
            seed: seed,
            key: key,
            sourceWidth: size.width,
            sourceHeight: size.height,
            artSide: artSide
          )
          let exhaustive = exhaustiveLargestSourceCoverGap(
            among: glyphs.prefix(prefix),
            seed: seed,
            key: key,
            sourceWidth: size.width,
            sourceHeight: size.height,
            artSide: artSide
          )

          #expect(
            pruned.x == exhaustive.x && pruned.y == exhaustive.y,
            """
            profile \(profile), \(size.width)×\(size.height), \
            prefix \(prefix): \(pruned) vs \(exhaustive)
            """
          )
        }
      }
    }
  }

  @Test("The single-pass coverage sizing matches an exhaustive scan")
  func sizedSourceCoverGlyphsMatchExhaustiveScan() {
    for profile in 0..<PoofSimulation.sourceCoverGeometryProfileCount {
      let seed = UInt64(profile)

      for size in sourceCoverReferenceSizes {
        let aspect = PoofSourceCoverAspect(
          size: CGSize(width: size.width, height: size.height)
        )
        let frameSet = PoofSimulation.makeFrameSet(
          configuration: PoofConfiguration(seed: seed),
          coversSource: true,
          sourceCoverAspect: aspect,
          variationSeed: seed
        )
        let glyphs = frameSet.sourceCoverGlyphs(for: aspect)

        guard !glyphs.isEmpty else {
          continue
        }

        let artSide = sourceCoverArtSide(
          width: size.width,
          height: size.height
        )
        let coverageCount = min(
          PoofSourceCoverLayout.openingGlyphCount,
          glyphs.count
        )
        let radii = PoofSimulation.sourceCoverageRadii(
          glyphs,
          coverageCount: coverageCount,
          sourceWidth: size.width,
          sourceHeight: size.height,
          artSide: artSide
        )
        let exhaustiveRadii = exhaustiveSizedSourceCoverGlyphs(
          glyphs,
          coverageCount: coverageCount,
          sourceWidth: size.width,
          sourceHeight: size.height,
          artSide: artSide
        )

        #expect(
          radii == exhaustiveRadii,
          "profile \(profile), \(size.width)×\(size.height)"
        )
      }
    }
  }

  @Test("Five hard poses occupy consecutive progress intervals")
  func poseBoundaries() {
    let cases: [(progress: Double, expected: PoofPose?)] = [
      (-1, nil),
      (.nan, nil),
      (0, nil),
      (.leastNonzeroMagnitude, .cloud),
      (0.199_999, .cloud),
      (1.0 / 5.0, .clusters),
      (0.399_999, .clusters),
      (2.0 / 5.0, .puffs),
      (0.599_999, .puffs),
      (3.0 / 5.0, .wisps),
      (0.799_999, .wisps),
      (4.0 / 5.0, .ringlets),
      (0.999_999, .ringlets),
      (1, nil),
      (.infinity, nil),
    ]

    for testCase in cases {
      #expect(
        PoofSimulation.pose(for: testCase.progress)
          == testCase.expected
      )
    }
  }

  @Test("Each pose is held for one fifteenth of a second")
  func timing() {
    #expect(PoofPose.allCases.count == 5)
    #expect(PoofSimulation.frameDuration == 1.0 / 15.0)
    #expect(PoofSimulation.duration == 5.0 / 15.0)
    #expect(
      PoofSimulation.duration
        == PoofSimulation.frameDuration
        * Double(PoofPose.allCases.count)
    )
  }

  @Test("A plume is silent at the endpoints")
  func plumeIsSilentAtEndpoints() {
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(seed: 0x504F_4F46),
      variationSeed: 0x504F_4F46
    )

    for progress in [0.0, 1.0, -1.0, 2.0, Double.nan, .infinity] {
      #expect(frameSet.blends(at: progress).isEmpty)
    }
  }

  @Test("A plume is repeatable, bounded, and always alive in between")
  func plumeIsRepeatableAndBounded() {
    func frameSet(seed: UInt64) -> PoofFrameSet {
      PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(
          particleCount: 64,
          seed: seed
        ),
        variationSeed: seed
      )
    }

    let first = frameSet(seed: 0x504F_4F46)
    let repeated = frameSet(seed: 0x504F_4F46)
    var everyBlend: [PoofGlyphBlend] = []

    for step in 5...88 {
      let progress = Double(step) / 100
      let blends = first.blends(at: progress)

      #expect(blends == repeated.blends(at: progress))
      // Continuous smoke is never momentarily absent mid-playback. Past the
      // global fade the field is deliberately emptying, so it stops here.
      #expect(!blends.isEmpty, "nothing alive at \(progress)")
      #expect(blends.count <= 64)

      everyBlend.append(contentsOf: blends)
    }

    for blend in everyBlend {
      #expect(blend.glyph.x.isFinite)
      #expect(blend.glyph.y.isFinite)
      #expect(blend.glyph.width > 0)
      #expect(blend.glyph.height > 0)
      #expect((0...1).contains(blend.glyph.opacity))
      #expect(abs(blend.glyph.x) <= 1.2)
      #expect(abs(blend.glyph.y) <= 1.2)
    }
  }

  @Test("A plume stays inside the drawable field")
  func plumeStaysInsideTheField() {
    // The standalone effect fills its frame, so anything past the authored
    // envelope is clipped. Travel, growth, curl, and buoyancy all have to fit
    // in one budget, which is why size is fitted before speed is chosen.
    for style in [PoofStyle.classic, .bloom, .snap] {
      for particleCount in [12, 28, 64] {
        for spread in [0.55, 0.82, 1.10] {
          let frameSet = PoofSimulation.makeFrameSet(
            configuration: PoofConfiguration(
              particleCount: particleCount,
              spread: spread,
              seed: 0x504F_4F46
            ),
            style: style,
            variationSeed: 0x504F_4F46
          )

          for step in 1..<60 {
            for blend in frameSet.blends(at: Double(step) / 60) {
              let glyph = blend.glyph

              #expect(
                abs(glyph.x) + glyph.width / 2 <= 0.47,
                "\(style)/\(particleCount)/\(spread) x \(glyph.x)"
              )
              #expect(
                abs(glyph.y) + glyph.height / 2 <= 0.47,
                "\(style)/\(particleCount)/\(spread) y \(glyph.y)"
              )
            }
          }
        }
      }
    }
  }

  @Test("Plume emission is staggered, seeded, and repeatable")
  func plumeEmissionIsStaggered() {
    func plume(seed: UInt64) -> PoofPlume {
      PoofPlume.make(
        configuration: PoofConfiguration(seed: seed),
        style: .classic,
        profile: .standalone,
        origins: PoofPlume.origins(
          from: PoofPose.allCases.map { pose in
            (0..<PoofSimulation.glyphCount(
              for: pose,
              configuration: PoofConfiguration(seed: seed)
            ))
            .compactMap {
              PoofSimulation.glyph(
                at: $0,
                pose: pose,
                configuration: PoofConfiguration(seed: seed),
                variationSeed: seed
              )
            }
          }
        ),
        variationSeed: seed
      )
    }

    let first = plume(seed: 0x504F_4F46)
    let births = first.particles.map(\.birth)

    // Puffs arrive across the playback rather than all at once, which is what
    // lets the cloud build and then trickle instead of appearing whole. A few
    // near-collisions are fine; a pile-up is not.
    #expect(
      quantizedValueCount(births)
        >= Int(Double(births.count) * 0.9)
    )
    #expect((births.min() ?? 1) < 0.05)
    #expect((births.max() ?? 0) >= 0.30)
    #expect(first.particles == plume(seed: 0x504F_4F46).particles)
    #expect(first.particles != plume(seed: 0x1111).particles)
  }

  @Test("Plume trajectories are continuous")
  func plumeVelocityIsContinuous() {
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(seed: 0x504F_4F46),
      variationSeed: 0x504F_4F46
    )
    let step = 0.002
    var previousByIndex: [Int: (x: Double, y: Double)] = [:]
    var maximumJump = 0.0

    for sample in 1..<400 {
      let progress = Double(sample) / 400
      var current: [Int: (x: Double, y: Double)] = [:]

      for blend in frameSet.blends(at: progress) {
        let point = (x: blend.glyph.x, y: blend.glyph.y)
        current[blend.paletteIndex] = point

        if let previous = previousByIndex[blend.paletteIndex] {
          maximumJump = max(
            maximumJump,
            ((point.x - previous.x) * (point.x - previous.x)
              + (point.y - previous.y) * (point.y - previous.y)).squareRoot()
          )
        }
      }

      previousByIndex = current
    }

    // No puff teleports: every position is a closed form in its own age, so
    // the whole path is smooth by construction rather than by keyframe.
    #expect(maximumJump < step * 12, "largest jump \(maximumJump)")
  }

  @Test("Plume appearance is fixed per puff and follows emission order")
  func plumeAppearanceFollowsEmissionOrder() {
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(seed: 0x504F_4F46),
      variationSeed: 0x504F_4F46
    )
    var contoursByIndex: [Int: Set<PoofContour>] = [:]
    var meanSizes: [Double] = []

    for step in 1..<50 {
      let blends = frameSet.blends(at: Double(step) / 50)

      for blend in blends {
        contoursByIndex[blend.paletteIndex, default: []]
          .insert(blend.glyph.contour)
      }

      guard !blends.isEmpty else {
        continue
      }

      meanSizes.append(
        blends.reduce(0) { $0 + $1.glyph.width } / Double(blends.count)
      )
    }

    // A puff keeps its identity for its whole life; nothing morphs.
    for contours in contoursByIndex.values {
      #expect(contours.count == 1)
    }

    // Smoke thins by growing and fading, not by deflating.
    let earlyMean = meanSizes.prefix(8).reduce(0, +) / 8
    let lateMean =
      meanSizes.suffix(8).reduce(0, +) / Double(meanSizes.suffix(8).count)

    #expect(lateMean > earlyMean)
  }

  @Test("Classic plumes keep to puffs while expressive styles do not")
  func plumeVocabularyFollowsStyle() {
    for style in [PoofStyle.classic, .bloom, .snap] {
      let frameSet = PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(particleCount: 64, seed: 7),
        style: style,
        variationSeed: 7
      )
      var contours: Set<PoofContour> = []

      for step in 1..<80 {
        for blend in frameSet.blends(at: Double(step) / 80) {
          contours.insert(blend.glyph.contour)
        }
      }

      #expect(!contours.isEmpty)

      if style == .classic {
        #expect(contours.isSubset(of: [.puff4, .puff5]), "\(contours)")
      } else {
        #expect(
          !contours.isSubset(of: [.puff4, .puff5]),
          "\(style) drew only puffs"
        )
      }
    }
  }

  @Test("The second pose is visibly more compact than dense puffs")
  func compactSecondPose() {
    let configuration = PoofConfiguration(seed: 0x504F_4F46)

    for style in [PoofStyle.classic, .bloom, .snap] {
      let clusters = glyphs(
        for: .clusters,
        in: configuration,
        seed: 0x504F_4F46,
        style: style
      )
      let puffs = glyphs(
        for: .puffs,
        in: configuration,
        seed: 0x504F_4F46,
        style: style
      )
      let clusterArea = descriptorBoundsArea(clusters)
      let puffArea = descriptorBoundsArea(puffs)

      #expect(
        clusterArea < puffArea * 0.92,
        "\(style): clusters \(clusterArea), puffs \(puffArea)"
      )
    }
  }

  @Test("Every pose exposes bounded work")
  func glyphCounts() {
    let seed: UInt64 = 0x504F_4F46
    let configuration = PoofConfiguration(
      particleCount: 64,
      seed: seed
    )

    #expect(
      PoofSimulation.glyphCount(
        for: .cloud,
        configuration: configuration
      ) == 7
    )
    #expect(
      PoofSimulation.glyphCount(
        for: .clusters,
        configuration: configuration
      ) == 4
    )

    #expect(glyphs(for: .cloud, in: configuration, seed: seed).count == 7)
    #expect(glyphs(for: .clusters, in: configuration, seed: seed).count == 4)
    #expect(glyphs(for: .puffs, in: configuration, seed: seed).count == 64)
    #expect(glyphs(for: .wisps, in: configuration, seed: seed).count == 41)
    #expect(glyphs(for: .ringlets, in: configuration, seed: seed).count == 30)

    for particleCount in [12, 64] {
      let boundedConfiguration = PoofConfiguration(
        particleCount: particleCount
      )

      for pose in PoofPose.allCases {
        #expect(
          PoofSimulation.glyphCount(
            for: pose,
            configuration: boundedConfiguration
          ) <= boundedConfiguration.particleCount
        )
      }
    }
  }

  @Test("Later poses retain progressively fewer puffs")
  func survivalContraction() {
    let seed: UInt64 = 0xCAFE_BABE
    let configuration = PoofConfiguration(
      particleCount: 64,
      seed: seed
    )
    let puffs = glyphs(for: .puffs, in: configuration, seed: seed)
    let wisps = glyphs(for: .wisps, in: configuration, seed: seed)
    let ringlets = glyphs(
      for: .ringlets,
      in: configuration,
      seed: seed
    )

    #expect(puffs.count == configuration.particleCount)
    #expect(puffs.count > wisps.count)
    #expect(wisps.count > ringlets.count)
    #expect(ringlets.isEmpty == false)
    #expect(puffs.count == 64)
    #expect(wisps.count == 41)
    #expect(ringlets.count == 30)
  }

  @Test("Breakup poses use independently authored layouts")
  func independentBreakupLayouts() {
    let seed: UInt64 = 0x504F_4F46
    let configuration = PoofConfiguration(seed: seed)
    let puffs = glyphs(for: .puffs, in: configuration, seed: seed)
    let wisps = glyphs(for: .wisps, in: configuration, seed: seed)
    let ringlets = glyphs(
      for: .ringlets,
      in: configuration,
      seed: seed
    )

    #expect(puffs.count == 28)
    #expect(wisps.count == 18)
    #expect(ringlets.count == 13)
    #expect(
      zip(puffs, wisps).filter { puff, wisp in
        hypot(puff.x - wisp.x, puff.y - wisp.y) > 0.04
      }.count > 12
    )
    #expect(
      zip(wisps, ringlets).filter { wisp, ringlet in
        hypot(wisp.x - ringlet.x, wisp.y - ringlet.y) > 0.04
      }.count > 8
    )
  }

  @Test("Every drawable glyph remains finite and bounded")
  func finiteBoundedGlyphs() {
    let configurations = [
      PoofConfiguration(
        particleCount: 12,
        spread: 0.55,
        seed: 1
      ),
      PoofConfiguration(
        particleCount: 64,
        spread: 1.10,
        seed: .max
      ),
    ]

    for configuration in configurations {
      for seed in [UInt64.min, 0xCAFE_BABE, UInt64.max] {
        for pose in PoofPose.allCases {
          for glyph in glyphs(
            for: pose,
            in: configuration,
            seed: seed
          ) {
            #expect(glyph.x.isFinite)
            #expect(glyph.y.isFinite)
            #expect(glyph.width.isFinite)
            #expect(glyph.height.isFinite)
            #expect(glyph.opacity.isFinite)
            #expect(glyph.rotation.isFinite)
            #expect(abs(glyph.x) <= 0.60)
            #expect(abs(glyph.y) <= 0.60)
            #expect((0...1).contains(glyph.width))
            #expect((0...1).contains(glyph.height))
            #expect((0...1).contains(glyph.opacity))
            #expect(PoofContour.allCases.contains(glyph.contour))
            #expect(PoofPaint.allCases.contains(glyph.paint))
          }
        }
      }
    }
  }

  @Test("A variation seed produces stable poses")
  func stableVariation() {
    let firstConfiguration = PoofConfiguration(
      particleCount: 24,
      seed: 0xCAFE_BABE
    )
    let secondConfiguration = PoofConfiguration(
      particleCount: 24,
      seed: 0xCAFE_BABE
    )

    for pose in PoofPose.allCases {
      let first = glyphs(
        for: pose,
        in: firstConfiguration,
        seed: 0xCAFE_BABE
      )
      let second = glyphs(
        for: pose,
        in: secondConfiguration,
        seed: 0xCAFE_BABE
      )

      #expect(first == second)
    }
  }

  @Test("Source-cover variation is coherent and repeatable")
  func stableSourceCoverVariation() throws {
    let first = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(seed: 1),
      variationSeed: 1
    )
    let repeated = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(seed: 1),
      variationSeed: 1
    )
    let second = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(seed: 2),
      variationSeed: 2
    )

    for aspect in [
      PoofSourceCoverAspect.square,
      .wide,
      .tall,
    ] {
      let firstGlyphs = first.sourceCoverGlyphs(for: aspect)
      let repeatedGlyphs = repeated.sourceCoverGlyphs(for: aspect)
      let secondGlyphs = second.sourceCoverGlyphs(for: aspect)

      #expect(firstGlyphs.count == PoofSourceCoverLayout.glyphCount)
      #expect(firstGlyphs == repeatedGlyphs)
      #expect(firstGlyphs != secondGlyphs)
      #expect(
        firstGlyphs.allSatisfy {
          $0.x.isFinite
            && $0.y.isFinite
            && $0.width.isFinite
            && $0.height.isFinite
            && $0.rotation.isFinite
        }
      )
    }
    for item in [
      (
        aspect: PoofSourceCoverAspect.square,
        size: CGSize(width: 84, height: 84)
      ),
      (
        aspect: PoofSourceCoverAspect.wide,
        size: CGSize(width: 132, height: 48)
      ),
      (
        aspect: PoofSourceCoverAspect.tall,
        size: CGSize(width: 48, height: 132)
      ),
    ] {
      let glyphs = first.sourceCoverGlyphs(for: item.aspect)
      let rootGlyphs =
        glyphs.prefix(PoofSourceCoverLayout.rootGlyphCount)
      let descendants =
        glyphs.dropFirst(PoofSourceCoverLayout.rootGlyphCount)

      #expect(glyphs.count == PoofSourceCoverLayout.glyphCount)
      #expect(Set(rootGlyphs.map(\.clusterIndex)) == Set(0..<4))
      #expect(
        (0..<4).allSatisfy { clusterIndex in
          rootGlyphs.filter {
            $0.clusterIndex == clusterIndex
          }.count == 3
        }
      )
      #expect(
        rootGlyphs.allSatisfy {
          $0.lineageParentIndex == nil
        }
      )
      #expect(
        descendants.enumerated().allSatisfy { offset, glyph in
          guard let parentIndex = glyph.lineageParentIndex else {
            return false
          }

          return parentIndex
            < offset + PoofSourceCoverLayout.rootGlyphCount
            && glyphs[parentIndex].clusterIndex == glyph.clusterIndex
        }
      )
      let ordinaryChildIndices =
        Array(
          PoofSourceCoverLayout
            .rootGlyphCount..<PoofSourceCoverLayout
            .baseGlyphCount
        )
        + Array(
          (PoofSourceCoverLayout.baseGlyphCount
            + PoofSourceCoverLayout.repairGlyphCount)..<PoofSourceCoverLayout.glyphCount
        )

      for childIndex in ordinaryChildIndices {
        let child = glyphs[childIndex]
        let parentIndex = try #require(child.lineageParentIndex)
        let parent = glyphs[parentIndex]
        let distance = hypot(
          item.size.width * (child.x - parent.x),
          item.size.height * (child.y - parent.y)
        )
        let childRadius =
          0.45
          * min(
            item.size.width * child.width,
            item.size.height * child.height
          )
        let parentRadius =
          0.45
          * min(
            item.size.width * parent.width,
            item.size.height * parent.height
          )

        #expect(
          distance <= childRadius + parentRadius + 1e-9,
          "\(item.aspect), child \(childIndex), distance \(distance)"
        )
      }
      #expect(Set(glyphs.map(\.contour)) == [.puff4, .puff5])
      #expect(quantizedValueCount(glyphs.map(\.x)) > 30)
      #expect(quantizedValueCount(glyphs.map(\.y)) > 30)
      #expect(quantizedValueCount(glyphs.map(\.width)) >= 8)
      #expect(
        Set(
          glyphs.map {
            ($0.paletteIndex + $0.tone.rawValue) % 4
          }
        ).count >= 3
      )
    }
  }

  @Test("Source-cover generation can target one aspect")
  func targetedSourceCoverGeneration() {
    for aspect in PoofSourceCoverAspect.allCases {
      let frameSet = PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(seed: 42),
        sourceCoverAspect: aspect,
        variationSeed: 42
      )

      #expect(frameSet.sourceCoverAspect == aspect)
      #expect(
        frameSet.sourceCoverGlyphs(for: aspect).count
          == PoofSourceCoverLayout.glyphCount
      )

      for unusedAspect in PoofSourceCoverAspect.allCases
      where unusedAspect != aspect {
        // Nothing is generated for the other aspects. Playback substitutes
        // the built aspect rather than drawing nothing, so this asks the
        // layout what it holds instead of what it would draw.
        #expect(
          frameSet.storedSourceCoverGlyphs(for: unusedAspect).isEmpty
        )
        #expect(
          frameSet.sourceCoverGlyphs(for: unusedAspect).count
            == PoofSourceCoverLayout.glyphCount
        )
      }
    }
  }

  @Test("Different playback seeds only make slight variations")
  func boundedVariation() {
    let configuration = PoofConfiguration(
      particleCount: 64,
      seed: 0x504F_4F46
    )
    var changedGlyphCount = 0

    for pose in PoofPose.allCases {
      let first = glyphs(
        for: pose,
        in: configuration,
        seed: 1
      )
      let second = glyphs(
        for: pose,
        in: configuration,
        seed: 2
      )

      #expect(first.count == second.count)

      for (firstGlyph, secondGlyph) in zip(first, second) {
        if firstGlyph != secondGlyph {
          changedGlyphCount += 1
        }

        #expect(abs(firstGlyph.x - secondGlyph.x) < 0.08)
        #expect(abs(firstGlyph.y - secondGlyph.y) < 0.08)
        #expect(
          abs(firstGlyph.width - secondGlyph.width)
            <= firstGlyph.width * 0.07
        )
        #expect(
          abs(firstGlyph.height - secondGlyph.height)
            <= firstGlyph.height * 0.07
        )
        #expect(abs(firstGlyph.rotation - secondGlyph.rotation) <= 0.21)
        #expect(firstGlyph.opacity == secondGlyph.opacity)
        #expect(firstGlyph.contour == secondGlyph.contour)
        #expect(firstGlyph.paint == secondGlyph.paint)
        #expect(firstGlyph.tone == secondGlyph.tone)
      }
    }

    #expect(changedGlyphCount > 0)
  }

  @Test("Opening poses stay canonical while breakup poses vary")
  func variationConcentratesInBreakup() {
    let configuration = PoofConfiguration(seed: 0x504F_4F46)
    var openingDistances: [Double] = []
    var breakupDistances: [Double] = []

    for pose in PoofPose.allCases {
      let first = glyphs(
        for: pose,
        in: configuration,
        seed: 0x1111
      )
      let second = glyphs(
        for: pose,
        in: configuration,
        seed: 0x2222
      )

      for (firstGlyph, secondGlyph) in zip(first, second) {
        let distance = hypot(
          firstGlyph.x - secondGlyph.x,
          firstGlyph.y - secondGlyph.y
        )

        if pose == .cloud || pose == .clusters {
          openingDistances.append(distance)
          #expect(distance < 0.012)
          #expect(
            abs(firstGlyph.width - secondGlyph.width)
              < firstGlyph.width * 0.015
          )
          #expect(
            abs(firstGlyph.rotation - secondGlyph.rotation) < 0.025
          )
        } else {
          breakupDistances.append(distance)
        }
      }
    }

    let openingAverage =
      openingDistances.reduce(0, +)
      / Double(openingDistances.count)
    let breakupAverage =
      breakupDistances.reduce(0, +)
      / Double(breakupDistances.count)

    #expect(breakupAverage > openingAverage * 2)
  }

  @Test("Explicit classic style preserves the original descriptors")
  func classicCompatibility() {
    let configuration = PoofConfiguration(seed: 0x504F_4F46)
    let implicit = PoofSimulation.makeFrameSet(
      configuration: configuration,
      variationSeed: 0xCAFE_BABE
    )
    let explicit = PoofSimulation.makeFrameSet(
      configuration: configuration,
      style: .classic,
      variationSeed: 0xCAFE_BABE
    )

    for pose in PoofPose.allCases {
      #expect(implicit.glyphs(for: pose) == explicit.glyphs(for: pose))
    }
  }

  @Test("Every style is deterministic, distinct, and bounded")
  func styledDescriptors() {
    let configuration = PoofConfiguration(
      particleCount: 64,
      spread: 1.10,
      seed: 0x504F_4F46
    )
    let styles: [PoofStyle] = [.classic, .bloom, .snap]

    for style in styles {
      for pose in PoofPose.allCases {
        let first = glyphs(
          for: pose,
          in: configuration,
          seed: 0xCAFE_BABE,
          style: style
        )
        let repeated = glyphs(
          for: pose,
          in: configuration,
          seed: 0xCAFE_BABE,
          style: style
        )

        #expect(first == repeated)
        #expect(first.isEmpty == false)
        #expect(first.count <= 64)

        for glyph in first {
          #expect(glyph.x.isFinite)
          #expect(glyph.y.isFinite)
          #expect(glyph.width.isFinite)
          #expect(glyph.height.isFinite)
          #expect(glyph.opacity.isFinite)
          #expect(glyph.rotation.isFinite)
          #expect(abs(glyph.x) <= 0.60)
          #expect(abs(glyph.y) <= 0.60)
          #expect((0...1).contains(glyph.width))
          #expect((0...1).contains(glyph.height))
          #expect((0...1).contains(glyph.opacity))
        }
      }
    }

    let classic = glyphs(
      for: .puffs,
      in: configuration,
      seed: 0xCAFE_BABE,
      style: .classic
    )

    for style in [PoofStyle.bloom, .snap] {
      #expect(
        glyphs(
          for: .puffs,
          in: configuration,
          seed: 0xCAFE_BABE,
          style: style
        ) != classic
      )
    }
  }

  @Test("Modern styles follow distinct pose trajectories")
  func styleTrajectories() {
    let configuration = PoofConfiguration(seed: 0x504F_4F46)
    let seed: UInt64 = 0xCAFE_BABE
    let classicPuffs = glyphs(
      for: .puffs,
      in: configuration,
      seed: seed
    )
    let bloomPuffs = glyphs(
      for: .puffs,
      in: configuration,
      seed: seed,
      style: .bloom
    )

    #expect(
      meanArea(of: bloomPuffs)
        > meanArea(of: classicPuffs) * 1.8
    )

    let snapRadii = [PoofPose.puffs, .wisps, .ringlets].map { pose in
      meanRadius(
        of: glyphs(
          for: pose,
          in: configuration,
          seed: seed,
          style: .snap
        )
      )
    }

    #expect(snapRadii[0] < snapRadii[1])
    #expect(snapRadii[1] < snapRadii[2])

  }

  @Test("The sequence uses every organic contour")
  func contourCoverage() {
    let seed: UInt64 = 0x504F_4F46
    let configuration = PoofConfiguration(seed: seed)
    let allGlyphs: [PoofGlyph] = PoofPose.allCases.flatMap { pose in
      glyphs(for: pose, in: configuration, seed: seed)
    }

    #expect(
      Set(allGlyphs.map { $0.contour })
        == Set(PoofContour.allCases)
    )
    #expect(
      Set(allGlyphs.map { $0.paint })
        == Set(PoofPaint.allCases)
    )
  }

  @Test("Out-of-range fixed glyph indices are absent")
  func fixedGlyphBounds() {
    let configuration = PoofConfiguration.standard

    #expect(
      PoofSimulation.glyph(
        at: 7,
        pose: .cloud,
        configuration: configuration,
        variationSeed: 1
      ) == nil
    )
    #expect(
      PoofSimulation.glyph(
        at: 4,
        pose: .clusters,
        configuration: configuration,
        variationSeed: 1
      ) == nil
    )
    #expect(
      PoofSimulation.glyph(
        at: 28,
        pose: .puffs,
        configuration: configuration,
        variationSeed: 1
      ) == nil
    )
    #expect(
      PoofSimulation.glyph(
        at: 18,
        pose: .wisps,
        configuration: configuration,
        variationSeed: 1
      ) == nil
    )
    #expect(
      PoofSimulation.glyph(
        at: 13,
        pose: .ringlets,
        configuration: configuration,
        variationSeed: 1
      ) == nil
    )
  }

  private func glyphs(
    for pose: PoofPose,
    in configuration: PoofConfiguration,
    seed: UInt64,
    style: PoofStyle = .classic
  ) -> [PoofGlyph] {
    (0..<PoofSimulation.glyphCount(
      for: pose,
      configuration: configuration
    ))
    .compactMap { index in
      PoofSimulation.glyph(
        at: index,
        pose: pose,
        configuration: configuration,
        style: style,
        variationSeed: seed
      )
    }
  }

  private func meanArea(of glyphs: [PoofGlyph]) -> Double {
    glyphs.reduce(0) { area, glyph in
      area + glyph.width * glyph.height
    } / Double(glyphs.count)
  }

  private func meanRadius(of glyphs: [PoofGlyph]) -> Double {
    glyphs.reduce(0) { radius, glyph in
      radius + hypot(glyph.x, glyph.y)
    } / Double(glyphs.count)
  }

  private func descriptorBoundsArea(_ glyphs: [PoofGlyph]) -> Double {
    let bounds = glyphs.reduce(
      (
        minX: Double.infinity,
        minY: Double.infinity,
        maxX: -Double.infinity,
        maxY: -Double.infinity
      )
    ) { bounds, glyph in
      let renderedHeight =
        glyph.height * (glyph.contour == .curl ? 1.60 : 1)
      let cosine = abs(cos(glyph.rotation))
      let sine = abs(sin(glyph.rotation))
      let extentX =
        glyph.width / 2 * cosine
        + renderedHeight / 2 * sine
      let extentY =
        glyph.width / 2 * sine
        + renderedHeight / 2 * cosine

      return (
        min(bounds.minX, glyph.x - extentX),
        min(bounds.minY, glyph.y - extentY),
        max(bounds.maxX, glyph.x + extentX),
        max(bounds.maxY, glyph.y + extentY)
      )
    }

    return (bounds.maxX - bounds.minX) * (bounds.maxY - bounds.minY)
  }

  private func quantizedValueCount(_ values: [Double]) -> Int {
    Set(values.map { Int(($0 * 10_000).rounded()) }).count
  }

}
