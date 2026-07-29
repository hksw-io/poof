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

  @Test("The sequence uses every organic contour")
  func contourCoverage() {
    let seed: UInt64 = 0x504F_4F46
    let configuration = PoofConfiguration(seed: seed)
    let glyphs = PoofPose.allCases.flatMap { pose in
      glyphs(for: pose, in: configuration, seed: seed)
    }

    #expect(Set(glyphs.map(\.contour)) == Set(PoofContour.allCases))
    #expect(Set(glyphs.map(\.paint)) == Set(PoofPaint.allCases))
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
    seed: UInt64
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
        variationSeed: seed
      )
    }
  }
}
