import Foundation
import Testing

@testable import Poof

@Suite("Poof simulation")
struct PoofSimulationTests {
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
        #expect(
          frameSet.sourceCoverGlyphs(for: unusedAspect).isEmpty
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
    let styles: [PoofStyle] = [.classic, .bloom, .snap, .drift]

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

    for style in [PoofStyle.bloom, .snap, .drift] {
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

    let driftPoses = [PoofPose.puffs, .wisps, .ringlets].map { pose in
      glyphs(
        for: pose,
        in: configuration,
        seed: seed,
        style: .drift
      )
    }
    let driftCenters = driftPoses.map(meanY)

    #expect(driftCenters[0] > driftCenters[1])
    #expect(driftCenters[1] > driftCenters[2])
    #expect(driftCenters[2] < -0.25)

    let ringletY = driftPoses[2].map(\.y)
    let ringletHeight = (ringletY.max() ?? 0) - (ringletY.min() ?? 0)
    #expect(ringletHeight > 0.25)
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

  private func meanY(of glyphs: [PoofGlyph]) -> Double {
    glyphs.reduce(0) { y, glyph in
      y + glyph.y
    } / Double(glyphs.count)
  }

  private func quantizedValueCount(_ values: [Double]) -> Int {
    Set(values.map { Int(($0 * 10_000).rounded()) }).count
  }

}
