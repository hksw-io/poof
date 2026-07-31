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

  @Test("Smooth sampling reaches each pose and stays silent at endpoints")
  func smoothSampling() throws {
    #expect(PoofSimulation.smoothSample(for: -.infinity) == nil)
    #expect(PoofSimulation.smoothSample(for: .nan) == nil)
    #expect(PoofSimulation.smoothSample(for: 0) == nil)
    #expect(PoofSimulation.smoothSample(for: 1) == nil)
    #expect(PoofSimulation.smoothSample(for: .infinity) == nil)

    let anchors: [(Double, Int, PoofPose)] = [
      (0.1, 0, .cloud),
      (0.3, 1, .clusters),
      (0.5, 2, .puffs),
      (0.7, 3, .wisps),
      (0.9, 4, .ringlets),
    ]

    for (progress, segment, pose) in anchors {
      let sample = try #require(
        PoofSimulation.smoothSample(for: progress)
      )

      #expect(sample.segment == segment)
      #expect(abs(sample.amount - 1) < 1e-12)
      #expect(sample.end == pose)
      #expect(sample.weight(for: pose) == sample.amount)
    }

    for progress in [0.05, 0.20, 0.40, 0.60, 0.80, 0.95] {
      let sample = try #require(
        PoofSimulation.smoothSample(for: progress)
      )

      #expect(abs(sample.amount - 0.5) < 1e-12)
    }

    let quarterSample = try #require(
      PoofSimulation.smoothSample(for: 0.15)
    )
    #expect(abs(quarterSample.amount - 0.25) < 1e-12)
  }

  @Test("Smooth glyph interpolation is repeatable and bounded")
  func smoothGlyphInterpolation() throws {
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(
        particleCount: 64,
        seed: 0x504F_4F46
      ),
      variationSeed: 0x504F_4F46
    )

    for progress in stride(from: 0.01, through: 0.99, by: 0.01) {
      let sample = try #require(
        PoofSimulation.smoothSample(for: progress)
      )
      let first = frameSet.glyphs(for: sample)
      let repeated = frameSet.glyphs(for: sample)

      #expect(first == repeated)
      #expect(first.count <= 64)
      #expect(
        first.allSatisfy { glyph in
          glyph.x.isFinite
            && glyph.y.isFinite
            && glyph.width.isFinite
            && glyph.height.isFinite
            && glyph.opacity.isFinite
            && glyph.rotation.isFinite
            && (0...1).contains(glyph.opacity)
        }
      )
    }
  }

  @Test("Smooth anchors preserve every authored layout")
  func smoothAnchorGlyphs() throws {
    let seed: UInt64 = 0x504F_4F46
    let configuration = PoofConfiguration(
      particleCount: 64,
      seed: seed
    )
    let anchors: [(Double, PoofPose)] = [
      (0.10, .cloud),
      (0.30, .clusters),
      (0.50, .puffs),
      (0.70, .wisps),
      (0.90, .ringlets),
    ]

    for style in [PoofStyle.classic, .bloom, .snap] {
      let frameSet = PoofSimulation.makeFrameSet(
        configuration: configuration,
        style: style,
        variationSeed: seed
      )

      for (progress, pose) in anchors {
        let sample = try #require(
          PoofSimulation.smoothSample(for: progress)
        )
        var actual = frameSet.glyphs(for: sample)
        let authored = frameSet.glyphs(for: pose)

        #expect(actual.count == authored.count)

        for expected in authored {
          let matchIndex = actual.firstIndex {
            geometriesMatch($0, expected)
          }
          #expect(matchIndex != nil)
          if let matchIndex {
            actual.remove(at: matchIndex)
          }
        }
        #expect(actual.isEmpty)
      }
    }
  }

  @Test("Smooth tracks keep appearance fixed and scale their lifecycle")
  func smoothGlyphAppearanceChanges() throws {
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(
        particleCount: 64,
        seed: 0x504F_4F46
      ),
      variationSeed: 0x504F_4F46
    )
    let plan = smoothPlan(for: frameSet)

    #expect(plan.tracks.count <= 64)

    for progress in [0.05, 0.20, 0.40, 0.60, 0.80, 0.95] {
      let sample = try #require(
        PoofSimulation.smoothSample(for: progress)
      )
      let states = plan.states(for: sample)

      #expect(states.count == plan.tracks.count)
      #expect(
        zip(states, plan.tracks).allSatisfy { state, track in
          state.glyph.contour == track.contour
            && state.glyph.paint == track.paint
            && state.glyph.tone == track.tone
            && state.glyph.opacity == track.opacity
            && state.paletteIndex == track.paletteIndex
            && (0...1).contains(state.scale)
        }
      )
      #expect(
        states.contains {
          $0.scale > 0 && $0.scale < 1
        }
      )
    }
  }

  @Test("Smooth lifecycle timing is seeded and staggered")
  func smoothLifecycleTiming() throws {
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(
        particleCount: 64,
        seed: 0x504F_4F46
      ),
      variationSeed: 0x504F_4F46
    )
    let anchors = smoothAnchors(for: frameSet)
    let first = PoofSmoothPlan(
      poseAnchors: anchors,
      variationSeed: 0x504F_4F46
    )
    let repeated = PoofSmoothPlan(
      poseAnchors: anchors,
      variationSeed: 0x504F_4F46
    )
    let varied = PoofSmoothPlan(
      poseAnchors: anchors,
      variationSeed: 0x504F_4F47
    )

    #expect(first == repeated)
    #expect(
      zip(first.tracks, varied.tracks).contains {
        $0.lifecycles != $1.lifecycles
      }
    )
    let clusterToPuffStarts = first.tracks.compactMap { track in
      track.activity[2] == 0 && track.activity[3] == 1
        ? track.lifecycles[2].start
        : nil
    }.sorted()
    let startGaps = zip(
      clusterToPuffStarts,
      clusterToPuffStarts.dropFirst()
    ).map { $1 - $0 }

    #expect(clusterToPuffStarts.count == 60)
    #expect(quantizedValueCount(clusterToPuffStarts) == 60)
    #expect(clusterToPuffStarts.first.map { $0 < 0.04 } == true)
    #expect(clusterToPuffStarts.last.map { $0 > 0.73 } == true)
    #expect(startGaps.min() ?? 0 > 0.005)

    let sample = try #require(
      PoofSimulation.smoothSample(for: 0.40)
    )
    let scales = first.states(for: sample).map(\.scale)
    #expect(scales.contains(0))
    #expect(scales.contains(1))
    #expect(scales.contains { $0 > 0 && $0 < 1 })
    #expect(quantizedValueCount(scales) > 12)
  }

  @Test("Smooth tracks have continuous velocity at authored poses")
  func smoothTrackVelocity() throws {
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(seed: 0x504F_4F46),
      variationSeed: 0x504F_4F46
    )
    let plan = smoothPlan(for: frameSet)
    let epsilon = 0.000_01

    for progress in PoofSmoothPlan.anchorProgress.dropFirst().dropLast() {
      let before = try #require(
        PoofSimulation.smoothSample(for: progress - epsilon)
      )
      let at = try #require(
        PoofSimulation.smoothSample(for: progress)
      )
      let after = try #require(
        PoofSimulation.smoothSample(for: progress + epsilon)
      )

      for track in plan.tracks {
        let beforeState = track.state(for: before)
        let atState = track.state(for: at)
        let afterState = track.state(for: after)
        let leftVelocity = smoothVelocity(
          from: beforeState.glyph,
          to: atState.glyph,
          duration: epsilon
        )
        let rightVelocity = smoothVelocity(
          from: atState.glyph,
          to: afterState.glyph,
          duration: epsilon
        )

        #expect(
          zip(leftVelocity, rightVelocity).allSatisfy {
            abs($0 - $1) < 0.02
          }
        )
      }
    }
  }

  @Test("Smooth tracks pair nearby glyphs instead of crossing")
  func smoothGlyphMatching() {
    let start = [
      PoofGlyph(x: -0.4, y: 0, width: 0.2, height: 0.2),
      PoofGlyph(x: 0.4, y: 0, width: 0.2, height: 0.2),
    ]
    let end = [
      PoofGlyph(x: 0.35, y: 0, width: 0.2, height: 0.2),
      PoofGlyph(x: -0.35, y: 0, width: 0.2, height: 0.2),
    ]
    let plan = PoofSmoothPlan(
      poseAnchors: [start, end].map { glyphs in
        glyphs.enumerated().map {
          PoofGlyphLayer(
            glyph: $0.element,
            paletteIndex: $0.offset
          )
        }
      },
      variationSeed: 0x504F_4F46
    )

    #expect(plan.tracks.count == 2)
    #expect(plan.tracks[0].anchors[1].x < 0)
    #expect(plan.tracks[0].anchors[2].x < 0)
    #expect(plan.tracks[1].anchors[1].x > 0)
    #expect(plan.tracks[1].anchors[2].x > 0)
  }

  @Test("Progressive smooth breakup avoids crossing trajectories")
  func progressiveSmoothTracking() {
    let seed: UInt64 = 0x504F_4F46
    let configuration = PoofConfiguration(
      particleCount: 64,
      seed: seed
    )
    let sourceRect = CGRect(x: 0, y: 0, width: 84, height: 84)

    for style in [PoofStyle.classic, .bloom, .snap] {
      let frameSet = PoofSimulation.makeFrameSet(
        configuration: configuration,
        style: style,
        coversSource: true,
        sourceCoverAspect: .square,
        variationSeed: seed
      )
      let poseAnchors = PoofPose.allCases.map {
        PoofArtwork.progressiveGlyphs(
          for: $0,
          in: sourceRect,
          artSide: 84,
          frameSet: frameSet
        )
      }
      let plan = PoofSmoothPlan(
        poseAnchors: poseAnchors,
        variationSeed: seed,
        preservingLineageThrough: PoofPose.puffs.rawValue
      )

      for poseIndex in 0...2 {
        let commonCount = min(
          poseAnchors[poseIndex].count,
          plan.tracks.count
        )
        #expect(
          plan.tracks.prefix(commonCount).allSatisfy {
            $0.activity[poseIndex + 1] == 1
          }
        )
      }

      for segmentIndex in 3...4 {
        let crossings = crossingCount(
          in: plan.tracks.filter {
            $0.activity[segmentIndex] == 1
              && $0.activity[segmentIndex + 1] == 1
          },
          segment: segmentIndex
        )

        #expect(
          crossings <= 20,
          "\(style) segment \(segmentIndex) has \(crossings) crossings"
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

  private func smoothPlan(
    for frameSet: PoofFrameSet
  ) -> PoofSmoothPlan {
    PoofSmoothPlan(
      poseAnchors: smoothAnchors(for: frameSet),
      variationSeed: frameSet.variationSeed
    )
  }

  private func smoothAnchors(
    for frameSet: PoofFrameSet
  ) -> [[PoofGlyphLayer]] {
    PoofPose.allCases.map { pose in
      frameSet.glyphs(for: pose).enumerated().map {
        PoofGlyphLayer(
          glyph: $0.element,
          paletteIndex: $0.offset
        )
      }
    }
  }

  private func geometriesMatch(
    _ first: PoofGlyph,
    _ second: PoofGlyph
  ) -> Bool {
    abs(first.x - second.x) < 1e-12
      && abs(first.y - second.y) < 1e-12
      && abs(first.width - second.width) < 1e-12
      && abs(first.height - second.height) < 1e-12
      && abs(
        atan2(
          sin(first.rotation - second.rotation),
          cos(first.rotation - second.rotation)
        )
      ) < 1e-12
  }

  private func smoothVelocity(
    from start: PoofGlyph,
    to end: PoofGlyph,
    duration: Double
  ) -> [Double] {
    [
      (end.x - start.x) / duration,
      (end.y - start.y) / duration,
      (end.width - start.width) / duration,
      (end.height - start.height) / duration,
      (end.rotation - start.rotation) / duration,
    ]
  }

  private func crossingCount(
    in tracks: [PoofSmoothTrack],
    segment: Int
  ) -> Int {
    tracks.indices.reduce(0) { count, firstIndex in
      count
        + tracks.indices.dropFirst(firstIndex + 1).filter {
          trajectoriesCross(
            tracks[firstIndex],
            tracks[$0],
            segment: segment
          )
        }.count
    }
  }

  private func trajectoriesCross(
    _ first: PoofSmoothTrack,
    _ second: PoofSmoothTrack,
    segment: Int
  ) -> Bool {
    let firstStart = CGPoint(
      x: first.anchors[segment].x,
      y: first.anchors[segment].y
    )
    let firstEnd = CGPoint(
      x: first.anchors[segment + 1].x,
      y: first.anchors[segment + 1].y
    )
    let secondStart = CGPoint(
      x: second.anchors[segment].x,
      y: second.anchors[segment].y
    )
    let secondEnd = CGPoint(
      x: second.anchors[segment + 1].x,
      y: second.anchors[segment + 1].y
    )
    let firstSideProduct =
      orientation(firstStart, firstEnd, secondStart)
      * orientation(firstStart, firstEnd, secondEnd)
    let secondSideProduct =
      orientation(secondStart, secondEnd, firstStart)
      * orientation(secondStart, secondEnd, firstEnd)

    return firstSideProduct < 0 && secondSideProduct < 0
  }

  private func orientation(
    _ start: CGPoint,
    _ end: CGPoint,
    _ point: CGPoint
  ) -> Double {
    (end.x - start.x) * (point.y - start.y)
      - (end.y - start.y) * (point.x - start.x)
  }

}
