import CoreGraphics
import SwiftUI
import Testing

@testable import Poof

private let allPoofStyles: [PoofStyle] = [
  .classic,
  .bloom,
  .snap,
]

private enum SourceCoverEdge: CaseIterable {
  case top
  case bottom
  case left
  case right

  func point(
    in rect: CGRect,
    fraction: Double,
    outwardDistance: Double
  ) -> CGPoint {
    switch self {
    case .top:
      CGPoint(
        x: rect.minX + rect.width * fraction,
        y: rect.minY - outwardDistance
      )
    case .bottom:
      CGPoint(
        x: rect.minX + rect.width * fraction,
        y: rect.maxY + outwardDistance
      )
    case .left:
      CGPoint(
        x: rect.minX - outwardDistance,
        y: rect.minY + rect.height * fraction
      )
    case .right:
      CGPoint(
        x: rect.maxX + outwardDistance,
        y: rect.minY + rect.height * fraction
      )
    }
  }
}

@MainActor
@Suite("SwiftUI rendering")
struct PoofRenderingTests {
  @Test("Public effect renders a pose")
  func publicEffectRenders() throws {
    let content = PoofEffect(
      progress: 0.50,
      configuration: PoofConfiguration(seed: 0x504F_4F46)
    )
    .frame(width: 84, height: 84)
    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(width: 84, height: 84)
    renderer.scale = 1

    let image = try #require(renderer.cgImage)
    #expect(PixelSnapshot(image: image).statistics.alphaTotal > 0)
  }

  @Test("Public styled effect renders")
  func publicStyledEffectRenders() throws {
    for style in allPoofStyles {
      let content = PoofEffect(
        progress: 0.50,
        style: style,
        configuration: PoofConfiguration(seed: 0x504F_4F46)
      )
      .frame(width: 84, height: 84)
      let renderer = ImageRenderer(content: content)
      renderer.proposedSize = ProposedViewSize(width: 84, height: 84)
      renderer.scale = 1

      let image = try #require(renderer.cgImage)
      #expect(PixelSnapshot(image: image).statistics.alphaTotal > 0)
    }
  }

  @Test("Public effect accepts palette and smooth motion")
  func publicRenderingOptions() throws {
    let content = PoofEffect(
      progress: 0.42,
      style: .snap,
      configuration: PoofConfiguration(seed: 0x504F_4F46),
      palette: .pastel,
      motion: .smooth
    )
    .frame(width: 84, height: 84)
    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(width: 84, height: 84)
    renderer.scale = 2

    let image = try #require(renderer.cgImage)
    let snapshot = PixelSnapshot(image: image)

    #expect(snapshot.statistics.alphaTotal > 0)
    #expect(snapshot.chromaticPixelCount > 100)
  }

  @Test("Every public style renders all five poses")
  func publicStylesRenderEveryPose() throws {
    let progresses = [0.1, 0.3, 0.5, 0.7, 0.9]

    for style in allPoofStyles {
      for progress in progresses {
        let image = try #require(
          snapshot(progress: progress, style: style)
        )

        #expect(image.statistics.alphaTotal > 0)
        #expect(image.statistics.bounds != nil)
      }
    }
  }

  @Test("The endpoint frames are transparent")
  func endpointsAreTransparent() throws {
    for style in allPoofStyles {
      let first = try #require(snapshot(progress: 0, style: style))
      let last = try #require(snapshot(progress: 1, style: style))
      let smoothFirst = try #require(
        snapshot(progress: 0, style: style, motion: .smooth)
      )
      let smoothLast = try #require(
        snapshot(progress: 1, style: style, motion: .smooth)
      )

      #expect(first.statistics.alphaTotal == 0)
      #expect(last.statistics.alphaTotal == 0)
      #expect(smoothFirst.statistics.alphaTotal == 0)
      #expect(smoothLast.statistics.alphaTotal == 0)
    }
  }

  @Test("Progressive removal keeps the source whole until smoke covers it")
  func progressiveRemovalWaitsForCoverage() throws {
    let progresses = [0.10, 0.30, 0.50, 0.70, 0.90]

    for style in allPoofStyles {
      let images = try #require(
        contentRemovalSnapshots(
          progresses: [0] + progresses,
          style: style
        )
      )
      let full = images[0]
      for image in images[1...2] {
        #expect(image.normalizedDifference(from: full) < 0.005)
        #expect(image.sourceBlueConnectedComponentCount == 1)
      }
      for image in images[3...5] {
        #expect(image.statistics.alphaTotal == 0)
      }

      for (previous, current) in zip(images, images.dropFirst()) {
        #expect(current.alphaExcessPixelCount(over: previous) <= 8)
      }
    }
  }

  @Test("Smooth progressive removal waits for complete coverage")
  func smoothProgressiveRemoval() throws {
    let progresses = [0.0, 0.10, 0.30, 0.50, 0.70, 0.90]

    for style in allPoofStyles {
      let frames = try #require(
        progressiveTransitionSnapshots(
          progresses: progresses,
          style: style,
          motion: .smooth,
          variationSeed: 0x504F_4F46
        )
      )

      expectGradualSourceRemoval(frames)
    }

    for size in [
      CGSize(width: 132, height: 48),
      CGSize(width: 48, height: 132),
    ] {
      let frames = try #require(
        progressiveTransitionSnapshots(
          progresses: progresses,
          motion: .smooth,
          width: size.width,
          height: size.height,
          variationSeed: 0xCAFE_BABE
        )
      )

      expectGradualSourceRemoval(frames)
    }
  }

  @Test("Progressive smoke carries coverage forward and engulfs the source")
  func progressiveCoverageEngulfsSource() throws {
    for seed in 0..<UInt64(PoofSimulation.sourceCoverGeometryProfileCount) {
      let frameSet = PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(seed: seed),
        variationSeed: seed
      )

      for size in [
        CGSize(width: 84, height: 84),
        CGSize(width: 132, height: 48),
        CGSize(width: 48, height: 132),
      ] {
        let rect = CGRect(origin: .zero, size: size)
        #expect(
          PoofArtwork.sourceCoverPath(
            for: .puffs,
            in: rect,
            frameSet: frameSet
          ) != nil
        )
        let elements = PoofArtwork.sourceCoverElements(
          for: .puffs,
          in: rect,
          frameSet: frameSet
        )
        let aspect =
          if size.width > size.height * 1.4 {
            PoofSourceCoverAspect.wide
          } else if size.height > size.width * 1.4 {
            PoofSourceCoverAspect.tall
          } else {
            PoofSourceCoverAspect.square
          }
        let descriptors = frameSet.sourceCoverGlyphs(for: aspect)
        let adjustmentTolerance =
          PoofLayout.artSide(for: size) * 1e-6
        var adjustedCenterCount = 0

        for (descriptor, element) in zip(descriptors, elements) {
          let rawCenter = CGPoint(
            x: rect.midX + rect.width * descriptor.x,
            y: rect.midY + rect.height * descriptor.y
          )

          if hypot(
            rawCenter.x - element.center.x,
            rawCenter.y - element.center.y
          ) > adjustmentTolerance {
            adjustedCenterCount += 1
          }
        }
        // A few outer puffs may meet the transparent overscan boundary while
        // rounding a square source. The cap keeps that correction local.
        #expect(
          adjustedCenterCount <= 3,
          "seed \(seed), \(size.width)×\(size.height), bounded \(adjustedCenterCount) centers"
        )
        let coverBounds = elements.reduce(CGRect.null) {
          $0.union($1.path.boundingRect)
        }
        let maximumOverhang =
          PoofLayout.artSide(for: size)
          * PoofArtwork.sourceCoverMaximumOverhangRatio
        let overhangTolerance =
          PoofLayout.artSide(for: size) * 1e-6
        let overhangs = [
          rect.minX - coverBounds.minX,
          rect.minY - coverBounds.minY,
          coverBounds.maxX - rect.maxX,
          coverBounds.maxY - rect.maxY,
        ]
        #expect(elements.count == PoofSourceCoverLayout.glyphCount)
        #expect(
          elements.count <= PoofArtwork.maximumRenderedElementCount
        )
        #expect(elements.allSatisfy { $0.path.isEmpty == false })
        #expect(
          PoofArtwork.renderedGlyphs(
            for: .puffs,
            occludesSource: false,
            frameSet: frameSet
          ).count == frameSet.glyphs(for: .puffs).count
        )

        if size.width == size.height {
          #expect(
            elements.allSatisfy {
              $0.path.boundingRect.width < rect.width * 0.45
                && $0.path.boundingRect.height < rect.height * 0.45
            }
          )
        } else {
          #expect(
            elements.allSatisfy {
              let bounds = $0.path.boundingRect
              let aspectRatio = bounds.width / bounds.height
              return aspectRatio > 0.65 && aspectRatio < 1.55
            }
          )
          #expect(
            elements.allSatisfy {
              max(
                $0.path.boundingRect.width,
                $0.path.boundingRect.height
              ) < min(rect.width, rect.height) * 0.80
            }
          )
        }
        #expect(
          overhangs.allSatisfy {
            $0 <= maximumOverhang + overhangTolerance
          }
            && (overhangs.max() ?? 0) >= 0.5,
          "seed \(seed), \(size.width)×\(size.height), overhangs: \(overhangs)"
        )

        for pose in [PoofPose.wisps, .ringlets] {
          #expect(
            PoofArtwork.sourceCoverPath(
              for: pose,
              in: rect,
              frameSet: frameSet
            ) == nil
          )
        }
        let cloudElements = PoofArtwork.sourceCoverElements(
          for: .cloud,
          in: rect,
          frameSet: frameSet
        )
        let clusterElements = PoofArtwork.sourceCoverElements(
          for: .clusters,
          in: rect,
          frameSet: frameSet
        )
        #expect(
          cloudElements.count == PoofSourceCoverLayout.cloudGlyphCount
        )
        #expect(
          clusterElements.count
            == PoofSourceCoverLayout.openingGlyphCount
        )
        #expect(
          PoofArtwork.renderedGlyphs(
            for: .cloud,
            occludesSource: true,
            frameSet: frameSet
          ).isEmpty
        )
        #expect(
          PoofArtwork.renderedGlyphs(
            for: .clusters,
            occludesSource: true,
            frameSet: frameSet
          ).isEmpty
        )
        #expect(
          PoofArtwork.renderedGlyphs(
            for: .puffs,
            occludesSource: true,
            frameSet: frameSet
          ).isEmpty
        )
      }
    }
  }

  @Test("Painted dense-pose paths cover the source without a catchall")
  func sourceCoverPathsCoverSource() throws {
    for seed in 0..<UInt64(PoofSimulation.sourceCoverGeometryProfileCount) {
      let frameSet = PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(seed: seed),
        variationSeed: seed
      )

      for size in [
        CGSize(width: 84, height: 84),
        CGSize(width: 132, height: 48),
        CGSize(width: 48, height: 132),
      ] {
        let rect = CGRect(origin: .zero, size: size)
        let elements = PoofArtwork.sourceCoverElements(
          for: .puffs,
          in: rect,
          frameSet: frameSet
        )
        let fillStrokeStyle = StrokeStyle(
          lineWidth: PoofArtwork.sourceCoverFillStrokeWidth(
            artSide: PoofLayout.artSide(for: size)
          ),
          lineCap: .round,
          lineJoin: .round
        )
        let paintedPaths = elements.flatMap {
          [
            $0.path,
            $0.path.strokedPath(fillStrokeStyle),
          ]
        }

        var uncoveredPoint: CGPoint?
        var y = rect.minY + 2.5

        while y < rect.maxY - 2, uncoveredPoint == nil {
          var x = rect.minX + 2.5

          while x < rect.maxX - 2 {
            let point = CGPoint(x: x, y: y)

            if !paintedPaths.contains(where: {
              $0.contains(point, eoFill: false)
            }) {
              uncoveredPoint = point
              break
            }

            x += 1
          }

          y += 1
        }

        #expect(
          uncoveredPoint == nil,
          "seed \(seed), \(size.width)×\(size.height), gap: \(String(describing: uncoveredPoint))"
        )
      }
    }
  }

  @Test("Source-cover silhouettes are seeded and ragged")
  func sourceCoverSilhouettesAreSeededAndRagged() throws {
    let rect = CGRect(x: 0, y: 0, width: 84, height: 84)
    let maximumDepth = PoofLayout.artSide(for: rect.size) * 0.14
    var signatures = Set<[Int]>()

    for seed in 0..<UInt64(PoofSimulation.sourceCoverGeometryProfileCount) {
      let frameSet = PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(seed: seed),
        variationSeed: seed
      )
      let path = try #require(
        PoofArtwork.sourceCoverPath(
          for: .puffs,
          in: rect,
          frameSet: frameSet
        )
      )
      let profiles = SourceCoverEdge.allCases.map {
        sourceCoverDepthProfile(
          for: $0,
          path: path,
          rect: rect,
          maximumDepth: maximumDepth
        )
      }

      for (edge, profile) in zip(SourceCoverEdge.allCases, profiles) {
        let minimum = try #require(profile.min())
        let maximum = try #require(profile.max())
        let mean = profile.reduce(0, +) / Double(profile.count)
        let variance =
          profile.reduce(0) {
            $0 + ($1 - mean) * ($1 - mean)
          } / Double(profile.count)
        let bucketCount = Set(
          profile.map { Int(($0 / 0.5).rounded()) }
        ).count

        #expect(
          maximum - minimum >= 1.5,
          "seed \(seed), \(edge): \(minimum)...\(maximum)"
        )
        #expect(
          variance.squareRoot() >= 0.4,
          "seed \(seed), \(edge), deviation: \(variance.squareRoot())"
        )
        #expect(
          bucketCount >= 4,
          "seed \(seed), \(edge), buckets: \(bucketCount)"
        )
      }

      #expect(
        opposingProfileDifference(profiles[0], profiles[1]) >= 0.4,
        "seed \(seed), top and bottom are too similar"
      )
      #expect(
        opposingProfileDifference(profiles[2], profiles[3]) >= 0.4,
        "seed \(seed), left and right are too similar"
      )

      signatures.insert(
        profiles.flatMap { profile in
          profile.map { Int(($0 / 0.25).rounded()) }
        }
      )
    }

    #expect(signatures.count == PoofSimulation.sourceCoverGeometryProfileCount)
  }

  @Test("Cover descriptors appear in three deliberate stages")
  func sourceCoverDescriptorsAreStaged() {
    let cases:
      [(
        aspect: PoofSourceCoverAspect,
        size: CGSize
      )] = [
        (.square, CGSize(width: 84, height: 84)),
        (.wide, CGSize(width: 132, height: 48)),
        (.tall, CGSize(width: 48, height: 132)),
      ]

    for seed in 0..<UInt64(PoofSimulation.sourceCoverGeometryProfileCount) {
      let frameSet = PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(seed: seed),
        variationSeed: seed
      )

      for item in cases {
        let rect = CGRect(origin: .zero, size: item.size)

        #expect(
          frameSet.sourceCoverGlyphs(for: item.aspect).count
            == PoofSourceCoverLayout.glyphCount
        )

        let cloudElements = PoofArtwork.sourceCoverElements(
          for: .cloud,
          in: rect,
          frameSet: frameSet
        )
        let clusterElements = PoofArtwork.sourceCoverElements(
          for: .clusters,
          in: rect,
          frameSet: frameSet
        )
        let puffElements = PoofArtwork.sourceCoverElements(
          for: .puffs,
          in: rect,
          frameSet: frameSet
        )

        #expect(
          cloudElements.count == PoofSourceCoverLayout.cloudGlyphCount
        )
        #expect(
          clusterElements.count
            == PoofSourceCoverLayout.openingGlyphCount
        )
        #expect(puffElements.count == PoofSourceCoverLayout.glyphCount)
        #expect(
          (cloudElements + clusterElements + puffElements).allSatisfy {
            !$0.path.boundingRect.isEmpty
          }
        )
        #expect(
          clusterElements.prefix(PoofSourceCoverLayout.rootGlyphCount)
            .allSatisfy {
              $0.scale == PoofArtwork.sourceCoverClusterRootGrowth
            }
        )
        #expect(
          clusterElements
            .dropFirst(PoofSourceCoverLayout.rootGlyphCount)
            .prefix(
              PoofSourceCoverLayout.baseGlyphCount
                - PoofSourceCoverLayout.rootGlyphCount
            )
            .allSatisfy {
              $0.scale == PoofArtwork.sourceCoverClusterChildGrowth
            }
        )
        let repairEndIndex =
          PoofSourceCoverLayout.baseGlyphCount
          + PoofSourceCoverLayout.repairGlyphCount
        #expect(
          clusterElements
            .dropFirst(PoofSourceCoverLayout.baseGlyphCount)
            .prefix(PoofSourceCoverLayout.repairGlyphCount)
            .allSatisfy {
              $0.scale == PoofArtwork.sourceCoverClusterRepairGrowth
            }
        )
        #expect(
          clusterElements
            .dropFirst(repairEndIndex)
            .allSatisfy {
              $0.scale == PoofArtwork.sourceCoverClusterFringeGrowth
            }
        )
        #expect(puffElements.allSatisfy { $0.scale == 1 })

        let cloudPath = combinedPath(for: cloudElements)
        let clusterPath = combinedPath(for: clusterElements)
        let cloudEdgeCoverage = sourceEdgeCoverageFractions(
          of: cloudPath,
          in: rect
        )
        let clusterEdgeCoverage = sourceEdgeCoverageFractions(
          of: clusterPath,
          in: rect
        )

        #expect(
          cloudEdgeCoverage.max() ?? 1 < 0.55,
          "seed \(seed), \(item.aspect), cloud edges: \(cloudEdgeCoverage)"
        )
        #expect(
          clusterEdgeCoverage.min() ?? 1 < 0.85,
          "seed \(seed), \(item.aspect), cluster edges: \(clusterEdgeCoverage)"
        )
      }
    }
  }

  @Test("Cover branches expand recursively from prior smoke")
  func sourceCoverBranchesExpandFromPriorSmoke() {
    for seed in [UInt64(0), 1, 31, 63] {
      let frameSet = PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(seed: seed),
        variationSeed: seed
      )

      for size in [
        CGSize(width: 84, height: 84),
        CGSize(width: 132, height: 48),
        CGSize(width: 48, height: 132),
      ] {
        let rect = CGRect(origin: .zero, size: size)
        let aspect =
          if size.width > size.height * 1.4 {
            PoofSourceCoverAspect.wide
          } else if size.height > size.width * 1.4 {
            PoofSourceCoverAspect.tall
          } else {
            PoofSourceCoverAspect.square
          }
        let descriptors = frameSet.sourceCoverGlyphs(for: aspect)
        let cloud = PoofArtwork.sourceCoverElements(
          for: .cloud,
          in: rect,
          frameSet: frameSet
        )
        let clusters = PoofArtwork.sourceCoverElements(
          for: .clusters,
          in: rect,
          frameSet: frameSet
        )
        let puffs = PoofArtwork.sourceCoverElements(
          for: .puffs,
          in: rect,
          frameSet: frameSet
        )

        #expect(cloud.count == PoofSourceCoverLayout.rootGlyphCount)
        #expect(clusters.count == PoofSourceCoverLayout.openingGlyphCount)
        #expect(puffs.count == PoofSourceCoverLayout.glyphCount)

        let centerTolerance =
          PoofLayout.artSide(for: size) * 1e-9

        for index in cloud.indices {
          let expectedCloudCenter = CGPoint(
            x:
              rect.midX
              + (puffs[index].center.x - rect.midX)
                * PoofArtwork.sourceCoverCloudReach,
            y:
              rect.midY
              + (puffs[index].center.y - rect.midY)
              * PoofArtwork.sourceCoverCloudReach
          )
          let expectedClusterCenter = CGPoint(
            x:
              rect.midX
              + (puffs[index].center.x - rect.midX)
                * PoofArtwork.sourceCoverClusterRootReach,
            y:
              rect.midY
              + (puffs[index].center.y - rect.midY)
              * PoofArtwork.sourceCoverClusterRootReach
          )

          #expect(
            pointDistance(cloud[index].center, expectedCloudCenter)
              <= centerTolerance
          )
          #expect(
            pointDistance(clusters[index].center, expectedClusterCenter)
              <= centerTolerance
          )
          #expect(
            cloud[index].scale == PoofArtwork.sourceCoverCloudGrowth
          )
          #expect(
            clusters[index].scale
              == PoofArtwork.sourceCoverClusterRootGrowth
          )
        }

        let cloudPath = combinedPath(for: cloud)
        let clusterPath = combinedPath(for: clusters)
        #expect(
          sampledContainmentRatio(
            of: cloudPath,
            inside: clusterPath,
            spacing: 0.5
          ) >= 0.995
        )

        let clusterChildIndices =
          PoofSourceCoverLayout.rootGlyphCount..<clusters.count

        for index in clusterChildIndices {
          let parentIndex = descriptors[index].lineageParentIndex
          #expect(parentIndex != nil)
          guard let parentIndex else {
            continue
          }

          #expect(parentIndex < index)
          let expectedCenter = CGPoint(
            x:
              clusters[parentIndex].center.x
              + (puffs[index].center.x
                - clusters[parentIndex].center.x)
                * PoofArtwork.sourceCoverBranchGrowth,
            y:
              clusters[parentIndex].center.y
              + (puffs[index].center.y
                - clusters[parentIndex].center.y)
              * PoofArtwork.sourceCoverBranchGrowth
          )
          let overlap = sampledContainmentRatio(
            of: clusters[index].path,
            inside: clusters[parentIndex].path,
            spacing: 0.5
          )

          #expect(
            pointDistance(clusters[index].center, expectedCenter)
              <= centerTolerance
          )
          #expect(
            clusters[index].scale
              == expectedClusterGrowth(at: index)
          )
          #expect(
            overlap > 0,
            "seed \(seed), \(aspect), child \(index) misses parent \(parentIndex)"
          )
        }

        for index in clusters.indices {
          let identityOverlap = sampledContainmentRatio(
            of: clusters[index].path,
            inside: puffs[index].path,
            spacing: 0.25
          )
          #expect(
            identityOverlap > 0,
            "seed \(seed), \(aspect), puff \(index) appears remotely"
          )
        }

        for index in clusters.count..<puffs.count {
          let parentIndex = descriptors[index].lineageParentIndex
          #expect(parentIndex != nil)

          guard let parentIndex else {
            continue
          }

          #expect(parentIndex < clusters.count)
          #expect(
            sampledContainmentRatio(
              of: puffs[index].path,
              inside: clusterPath,
              spacing: 0.25
            ) > 0,
            "seed \(seed), \(aspect), final puff \(index) misses prior smoke"
          )
        }

        #expect(
          sampledContainmentRatio(
            of: clusterPath,
            inside: combinedPath(for: puffs),
            spacing: 0.5
          ) >= 0.99
        )
      }
    }
  }

  @Test("Every seeded growth profile keeps each puff attached")
  func sourceCoverLineageIsContinuousAcrossAllProfiles() {
    let cases:
      [(
        aspect: PoofSourceCoverAspect,
        size: CGSize
      )] = [
        (.square, CGSize(width: 84, height: 84)),
        (.wide, CGSize(width: 132, height: 48)),
        (.tall, CGSize(width: 48, height: 132)),
      ]

    for seed in 0..<UInt64(PoofSimulation.sourceCoverGeometryProfileCount) {
      let frameSet = PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(seed: seed),
        variationSeed: seed
      )

      for item in cases {
        let rect = CGRect(origin: .zero, size: item.size)
        let descriptors = frameSet.sourceCoverGlyphs(for: item.aspect)
        let clusters = PoofArtwork.sourceCoverElements(
          for: .clusters,
          in: rect,
          frameSet: frameSet
        )
        let puffs = PoofArtwork.sourceCoverElements(
          for: .puffs,
          in: rect,
          frameSet: frameSet
        )

        for index in clusters.indices {
          #expect(
            pathsOverlapAlongCenterLine(clusters[index], puffs[index]),
            "seed \(seed), \(item.aspect), puff \(index) appears remotely"
          )

          guard let parentIndex = descriptors[index].lineageParentIndex else {
            continue
          }

          #expect(
            pathsOverlapAlongCenterLine(
              clusters[index],
              clusters[parentIndex]
            ),
            "seed \(seed), \(item.aspect), child \(index) misses parent \(parentIndex)"
          )
        }
      }
    }
  }

  @Test("The progressive cover expands evenly without replacing puffs")
  func progressiveCoverExpandsEvenly() throws {
    let renderScale = 3.0

    for style in allPoofStyles {
      let masks = try [0.199_999, 0.200_001, 0.400_001].map {
        progress in
        AlphaMask(
          snapshot: try #require(
            progressiveSmokeSnapshot(
              progress: progress,
              style: style,
              renderScale: renderScale
            )
          )
        )
      }
      var areaGrowths: [Double] = []

      for (previous, current) in zip(masks, masks.dropFirst()) {
        let intersection = previous.intersectionCount(with: current)
        let retention = Double(intersection) / Double(previous.count)
        let areaGrowth = Double(current.count) / Double(previous.count)
        let centroidMovement =
          hypot(
            previous.centroid.x - current.centroid.x,
            previous.centroid.y - current.centroid.y
          ) / renderScale

        areaGrowths.append(areaGrowth)
        #expect(
          retention >= 0.995,
          "\(style) retention: \(retention)"
        )
        #expect(
          areaGrowth > 1,
          "\(style) area growth: \(areaGrowth)"
        )
        #expect(
          centroidMovement <= 3,
          "\(style) centroid movement: \(centroidMovement)"
        )
      }

      #expect(
        (2.5...6.5).contains(areaGrowths[0]),
        "\(style) branch growth: \(areaGrowths[0])"
      )
      #expect(
        (1.1...1.5).contains(areaGrowths[1]),
        "\(style) final growth: \(areaGrowths[1])"
      )
      #expect(
        areaGrowths[0] > areaGrowths[1],
        "\(style) area growths: \(areaGrowths)"
      )
    }
  }

  @Test("Progressive frame two is visibly smaller than dense puffs")
  func progressiveSecondPoseIsCompact() throws {
    for style in allPoofStyles {
      for motion in [PoofMotion.stepped, .smooth] {
        let clusters = try #require(
          progressiveSmokeSnapshot(
            progress: 0.30,
            style: style,
            renderScale: 2,
            motion: motion
          )
        )
        let puffs = try #require(
          progressiveSmokeSnapshot(
            progress: 0.50,
            style: style,
            renderScale: 2,
            motion: motion
          )
        )
        let clusterBounds = try #require(clusters.statistics.bounds)
        let puffBounds = try #require(puffs.statistics.bounds)

        #expect(clusterBounds.area * 10 < puffBounds.area * 9)
        #expect(
          clusters.statistics.alphaTotal * 10
            < puffs.statistics.alphaTotal * 9
        )
      }
    }
  }

  @Test("Progressive source-mask frames are hard held")
  func progressiveRemovalHoldsFrames() throws {
    let intervals: [(Double, Double)] = [
      (0.01, 0.19),
      (0.21, 0.39),
      (0.41, 0.59),
      (0.61, 0.79),
      (0.81, 0.99),
    ]

    for style in allPoofStyles {
      let images = try #require(
        contentRemovalSnapshots(
          progresses: intervals.flatMap { [$0.0, $0.1] },
          style: style
        )
      )

      for (index, _) in intervals.enumerated() {
        let beginning = images[index * 2]
        let end = images[index * 2 + 1]

        // ImageRenderer may rasterize identical offscreen compositor cells
        // with slightly different edge coverage. Compare the rendered masks
        // within the same tolerance used for the smoke pose holds.
        #expect(beginning.normalizedDifference(from: end) < 0.01)
        #expect(beginning.statistics.bounds == end.statistics.bounds)
      }
    }
  }

  @Test("Progressive smoke consumes a chromatic source in coherent stages")
  func progressiveSmokeConsumesSource() throws {
    let progresses = [0.10, 0.30, 0.50, 0.70, 0.90]

    for style in allPoofStyles {
      for colorScheme in [ColorScheme.light, .dark] {
        let frames = try #require(
          progressiveTransitionSnapshots(
            progresses: [0] + progresses,
            style: style,
            colorScheme: colorScheme,
            variationSeed: 0x1111
          )
        )
        expectGradualSourceRemoval(frames)
      }

      let accessibleFrames = try #require(
        progressiveTransitionSnapshots(
          progresses: [0] + progresses,
          style: style,
          contrast: .increased,
          reducesTransparency: true,
          renderScale: 3,
          variationSeed: 0x2222
        )
      )

      expectGradualSourceRemoval(accessibleFrames)

      for size in [
        CGSize(width: 132, height: 48),
        CGSize(width: 48, height: 132),
      ] {
        let rectangularFrames = try #require(
          progressiveTransitionSnapshots(
            progresses: [0] + progresses,
            style: style,
            width: size.width,
            height: size.height,
            variationSeed: 0x3333
          )
        )

        expectGradualSourceRemoval(rectangularFrames)
      }
    }
  }

  @Test("The engulfing pose fully obscures every tested source surface")
  func progressivePuffsFullyObscureSource() throws {
    let sourceColors = [
      Color(.sRGB, red: 0.04, green: 0.24, blue: 1),
      Color(.sRGB, red: 1, green: 0.04, blue: 0.08),
    ]

    for style in allPoofStyles {
      for size in [
        CGSize(width: 84, height: 84),
        CGSize(width: 132, height: 48),
        CGSize(width: 48, height: 132),
      ] {
        for variationSeed in [
          UInt64(0),
          1,
          31,
          63,
          0x504F_4F46,
        ] {
          let blue = try #require(
            progressiveTransitionSnapshots(
              progresses: [0.50],
              style: style,
              width: size.width,
              height: size.height,
              renderScale: 3,
              variationSeed: variationSeed,
              sourceColor: sourceColors[0]
            )?.first
          )
          let red = try #require(
            progressiveTransitionSnapshots(
              progresses: [0.50],
              style: style,
              width: size.width,
              height: size.height,
              renderScale: 3,
              variationSeed: variationSeed,
              sourceColor: sourceColors[1]
            )?.first
          )

          #expect(
            blue.maximumColorDifference(from: red) <= 1,
            """
            \(style), \(size.width)×\(size.height), seed \(variationSeed), \
            exposed: \(blue.colorDifferencePixelCount(from: red))
            """
          )
        }
      }
    }
  }

  @Test("Smoke never exposes source pixels covered by an earlier pose")
  func progressiveCoverageNeverRegresses() throws {
    let sourceColors = [
      Color(.sRGB, red: 0.04, green: 0.24, blue: 1),
      Color(.sRGB, red: 1, green: 0.04, blue: 0.08),
    ]

    for style in allPoofStyles {
      let blue = try #require(
        progressiveTransitionSnapshots(
          progresses: [0.10, 0.30, 0.50],
          style: style,
          renderScale: 3,
          variationSeed: 0x504F_4F46,
          sourceColor: sourceColors[0]
        )
      )
      let red = try #require(
        progressiveTransitionSnapshots(
          progresses: [0.10, 0.30, 0.50],
          style: style,
          renderScale: 3,
          variationSeed: 0x504F_4F46,
          sourceColor: sourceColors[1]
        )
      )

      for index in blue.indices.dropFirst() {
        #expect(
          blue[index].sourceExposureReappearanceCount(
            comparedWith: red[index],
            over: blue[index - 1],
            previousAlternate: red[index - 1]
          ) == 0,
          "\(style), pose index \(index)"
        )
      }
    }
  }

  @Test("Progressive source-mask endpoints and accessibility are stable")
  func progressiveRemovalEndpointsAndAccessibility() throws {
    let endpoints = try #require(
      contentRemovalSnapshots(progresses: [0, 1])
    )
    let reducedFrames = try #require(
      contentRemovalSnapshots(
        progresses: [0, 0.50],
        reducesMotion: true
      )
    )
    let waitingFrames = try #require(
      contentRemovalSnapshots(
        progresses: [0, 0.50],
        variationSeed: nil
      )
    )
    let first = endpoints[0]
    let last = endpoints[1]
    let reduced = reducedFrames[1]
    let waiting = waitingFrames[1]
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(seed: 0x504F_4F46),
      variationSeed: 0x504F_4F46
    )
    let firstPath = PoofSourceMask(
      progress: 0,
      motion: .stepped,
      frameSet: frameSet
    ).path(in: CGRect(x: 0, y: 0, width: 84, height: 84))
    let lastPath = PoofSourceMask(
      progress: 1,
      motion: .stepped,
      frameSet: frameSet
    ).path(in: CGRect(x: 0, y: 0, width: 84, height: 84))

    #expect(firstPath.contains(CGPoint(x: 42, y: 42)))
    #expect(first.statistics.alphaTotal > 0)
    #expect(waiting.pixels == first.pixels)
    #expect(last.statistics.alphaTotal == 0)
    #expect(lastPath.isEmpty)
    let reducedAlphaRatio =
      Double(reduced.statistics.alphaTotal)
      / Double(first.statistics.alphaTotal)
    #expect(abs(reducedAlphaRatio - 0.5) < 0.02)
  }

  @Test("Source masks match across appearance and display scale")
  func surfaceMasksAreAppearanceIndependent() throws {
    for style in allPoofStyles {
      let lightFrames = try #require(
        contentRemovalSnapshots(
          progresses: [0, 0.50],
          style: style,
          colorScheme: .light
        )
      )
      let darkFrames = try #require(
        contentRemovalSnapshots(
          progresses: [0, 0.50],
          style: style,
          colorScheme: .dark
        )
      )
      let threeXFrames = try #require(
        contentRemovalSnapshots(
          progresses: [0, 0.50],
          style: style,
          colorScheme: .dark,
          renderScale: 3
        )
      )
      let expandedFieldFrames = try #require(
        contentRemovalSnapshots(
          progresses: [0, 0.50],
          style: style,
          fieldScale: 3
        )
      )
      let light = lightFrames[1]
      let dark = darkFrames[1]
      let threeX = threeXFrames[1]
      let expandedField = expandedFieldFrames[1]
      let lightRetention =
        Double(light.statistics.alphaTotal)
        / Double(light.width * light.height * Int(UInt8.max))
      let threeXRetention =
        Double(threeX.statistics.alphaTotal)
        / Double(threeX.width * threeX.height * Int(UInt8.max))

      #expect(light.pixels == dark.pixels)
      #expect(light.pixels == expandedField.pixels)
      #expect(abs(lightRetention - threeXRetention) < 0.02)
    }
  }

  @Test("Progressive source masks are stable across playback seeds")
  func progressiveRemovalSeedIndependence() {
    let rect = CGRect(x: 0, y: 0, width: 84, height: 84)
    let progresses = [0.0, 0.10, 0.30, 0.50, 0.70, 0.90, 1.0]

    for style in allPoofStyles {
      let firstFrameSet = PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(seed: 0x1111),
        style: style,
        variationSeed: 0x1111
      )
      let repeatedFrameSet = PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(seed: 0x1111),
        style: style,
        variationSeed: 0x1111
      )
      let variedFrameSet = PoofSimulation.makeFrameSet(
        configuration: PoofConfiguration(seed: 0x2222),
        style: style,
        variationSeed: 0x2222
      )

      for progress in progresses {
        let first = PoofSourceMask(
          progress: progress,
          motion: .stepped,
          frameSet: firstFrameSet
        ).path(in: rect)
        let repeated = PoofSourceMask(
          progress: progress,
          motion: .stepped,
          frameSet: repeatedFrameSet
        ).path(in: rect)
        let varied = PoofSourceMask(
          progress: progress,
          motion: .stepped,
          frameSet: variedFrameSet
        ).path(in: rect)

        #expect(first == repeated)
        #expect(first == varied)
      }
    }
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

    for style in allPoofStyles {
      for interval in intervals {
        let beginning = try #require(
          snapshot(
            progress: interval.0,
            style: style,
            reducesTransparency: true
          )
        )
        let end = try #require(
          snapshot(
            progress: interval.1,
            style: style,
            reducesTransparency: true
          )
        )

        #expect(beginning.normalizedDifference(from: end) < 0.01)
        #expect(beginning.statistics.bounds == end.statistics.bounds)
      }
    }
  }

  @Test("Smooth motion continuously changes between pose anchors")
  func smoothPoseIntervals() throws {
    for style in allPoofStyles {
      let early = try #require(
        snapshot(
          progress: 0.21,
          style: style,
          motion: .smooth,
          reducesTransparency: true
        )
      )
      let late = try #require(
        snapshot(
          progress: 0.29,
          style: style,
          motion: .smooth,
          reducesTransparency: true
        )
      )
      let intervalDifference = early.normalizedDifference(from: late)

      #expect(intervalDifference > 0.02)

      for midpoint in [0.05, 0.20, 0.40, 0.60, 0.80, 0.95] {
        let closeBefore = try #require(
          snapshot(
            progress: midpoint - 0.001,
            style: style,
            motion: .smooth,
            reducesTransparency: true
          )
        )
        let closeAfter = try #require(
          snapshot(
            progress: midpoint + 0.001,
            style: style,
            motion: .smooth,
            reducesTransparency: true
          )
        )
        let closeDifference =
          closeBefore.normalizedDifference(from: closeAfter)

        #expect(closeDifference > 0)
        #expect(closeDifference < intervalDifference)
      }
    }
  }

  @Test("Smooth motion preserves draw order across pose anchors")
  func smoothPoseAnchorContinuity() throws {
    let epsilon = 0.000_001

    for style in allPoofStyles {
      for anchor in [0.10, 0.30, 0.50, 0.70, 0.90] {
        let before = try #require(
          snapshot(
            progress: anchor - epsilon,
            style: style,
            motion: .smooth,
            reducesTransparency: true,
            particleCount: 64,
            width: 160,
            height: 160,
            renderScale: 3
          )
        )
        let after = try #require(
          snapshot(
            progress: anchor + epsilon,
            style: style,
            motion: .smooth,
            reducesTransparency: true,
            particleCount: 64,
            width: 160,
            height: 160,
            renderScale: 3
          )
        )

        #expect(before.normalizedDifference(from: after) < 0.001)
      }
    }
  }

  @Test("Smooth motion follows every authored pose envelope")
  func smoothPoseAnchors() throws {
    for style in allPoofStyles {
      for progress in [0.10, 0.30, 0.50, 0.70, 0.90] {
        let stepped = try #require(
          snapshot(progress: progress, style: style)
        )
        let smooth = try #require(
          snapshot(
            progress: progress,
            style: style,
            motion: .smooth
          )
        )
        let steppedBounds = try #require(
          stepped.statistics.bounds
        )
        let smoothBounds = try #require(
          smooth.statistics.bounds
        )

        #expect(stepped.normalizedDifference(from: smooth) < 0.09)
        #expect(abs(steppedBounds.width - smoothBounds.width) <= 6)
        #expect(abs(steppedBounds.height - smoothBounds.height) <= 6)
        #expect(
          abs(
            steppedBounds.minimumX + steppedBounds.maximumX
              - smoothBounds.minimumX - smoothBounds.maximumX
          ) <= 6
        )
        #expect(
          abs(
            steppedBounds.minimumY + steppedBounds.maximumY
              - smoothBounds.minimumY - smoothBounds.maximumY
          ) <= 6
        )
      }
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

  @Test("Light and dark appearances use identical style palettes")
  func lightAndDarkArtMatches() throws {
    for style in allPoofStyles {
      let light = try #require(
        snapshot(
          progress: 0.30,
          style: style,
          colorScheme: .light
        )
      )
      let dark = try #require(
        snapshot(
          progress: 0.30,
          style: style,
          colorScheme: .dark
        )
      )

      #expect(light.normalizedDifference(from: dark) < 0.005)
      #expect(light.statistics.bounds == dark.statistics.bounds)
    }
  }

  @Test("Default palette is grayscale for every style")
  func automaticPalette() throws {
    for style in allPoofStyles {
      let neutral = try #require(
        snapshot(
          progress: 0.30,
          style: style,
          reducesTransparency: true
        )
      )

      #expect(neutral.chromaticPixelCount == 0)
    }
  }

  @Test("Built-in palettes apply to every style")
  func builtInPalettes() throws {
    for style in allPoofStyles {
      let pastel = try #require(
        snapshot(
          progress: 0.30,
          style: style,
          palette: .pastel,
          reducesTransparency: true
        )
      )
      let monochrome = try #require(
        snapshot(
          progress: 0.30,
          style: style,
          palette: .monochrome,
          reducesTransparency: true
        )
      )

      #expect(pastel.chromaticPixelCount > 100)
      #expect(monochrome.chromaticPixelCount == 0)
    }
  }

  @Test("Custom fill colors work across styles, motion, and appearance")
  func customPalette() throws {
    let palette = PoofPalette(
      colors: [
        Color(red: 0.98, green: 0.45, blue: 0.32),
        Color(red: 0.35, green: 0.78, blue: 0.95),
      ]
    )
    for style in allPoofStyles {
      let light = try #require(
        snapshot(
          progress: 0.40,
          style: style,
          palette: palette,
          motion: .smooth,
          colorScheme: .light,
          reducesTransparency: true
        )
      )
      let repeated = try #require(
        snapshot(
          progress: 0.40,
          style: style,
          palette: palette,
          motion: .smooth,
          colorScheme: .light,
          reducesTransparency: true
        )
      )
      let dark = try #require(
        snapshot(
          progress: 0.40,
          style: style,
          palette: palette,
          motion: .smooth,
          colorScheme: .dark,
          reducesTransparency: true
        )
      )

      #expect(light.normalizedDifference(from: repeated) < 0.0001)
      #expect(light.normalizedDifference(from: dark) < 0.005)
      #expect(light.chromaticPixelCount > 100)
    }
  }

  @Test("Canvas waits for its precomputed frame set")
  func canvasWaitsForFrameSet() throws {
    let waiting = try #require(
      snapshot(progress: 0.50, variationSeed: nil)
    )
    let ready = try #require(
      snapshot(progress: 0.50, variationSeed: 0x504F_4F46)
    )

    #expect(waiting.statistics.alphaTotal == 0)
    #expect(ready.statistics.alphaTotal > 0)
  }

  @Test("A playback resolves one coherent variation seed")
  func playbackSeedResolution() {
    let randomSeed: UInt64 = 0x1234
    let configuration = PoofConfiguration()
    var randomSeedCalls = 0
    let frameSet = PoofPlayback.makeFrameSet(
      for: configuration,
      style: .snap
    ) {
      randomSeedCalls += 1
      return randomSeed
    }
    let expected = PoofSimulation.makeFrameSet(
      configuration: configuration,
      style: .snap,
      variationSeed: randomSeed
    )

    #expect(randomSeedCalls == 1)
    #expect(frameSet.style == .snap)
    #expect(frameSet.coversSource == false)
    #expect(frameSet.sourceCoverGlyphs(for: .square).isEmpty)
    for pose in PoofPose.allCases {
      #expect(frameSet.glyphs(for: pose) == expected.glyphs(for: pose))
    }

    let seededConfiguration = PoofConfiguration(seed: 0xCAFE_BABE)
    let seededFrameSet = PoofPlayback.makeFrameSet(
      for: seededConfiguration
    ) {
      randomSeedCalls += 1
      return randomSeed
    }
    let seededExpected = PoofSimulation.makeFrameSet(
      configuration: seededConfiguration,
      variationSeed: 0xCAFE_BABE
    )

    #expect(randomSeedCalls == 1)
    #expect(seededFrameSet.coversSource == false)
    for pose in PoofPose.allCases {
      #expect(
        seededFrameSet.glyphs(for: pose)
          == seededExpected.glyphs(for: pose)
      )
    }

    let coveredFrameSet = PoofPlayback.makeFrameSet(
      for: seededConfiguration,
      coversSource: true,
      sourceCoverAspect: .wide
    )

    #expect(coveredFrameSet.coversSource)
    #expect(coveredFrameSet.sourceCoverAspect == .wide)
    #expect(
      coveredFrameSet.sourceCoverGlyphs(for: .wide).count
        == PoofSourceCoverLayout.glyphCount
    )
    #expect(coveredFrameSet.sourceCoverGlyphs(for: .square).isEmpty)
    #expect(coveredFrameSet.sourceCoverGlyphs(for: .tall).isEmpty)
  }

  @Test("Reduce Motion removes spatial drawing")
  func reduceMotionIsBlank() throws {
    for style in allPoofStyles {
      for motion in [PoofMotion.stepped, .smooth] {
        let image = try #require(
          snapshot(
            progress: 0.50,
            style: style,
            motion: motion,
            reducesMotion: true
          )
        )

        #expect(image.statistics.alphaTotal == 0)
        #expect(image.statistics.bounds == nil)
      }
    }
  }

  @Test("Reduce Transparency removes haze and strengthens smoke")
  func reduceTransparency() throws {
    for style in allPoofStyles {
      for motion in [PoofMotion.stepped, .smooth] {
        let standard = try #require(
          snapshot(
            progress: 0.60,
            style: style,
            motion: motion
          )
        )
        let reduced = try #require(
          snapshot(
            progress: 0.60,
            style: style,
            motion: motion,
            reducesTransparency: true
          )
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
    }
  }

  @Test("Increased Contrast darkens edge detail")
  func increasedContrast() throws {
    for style in allPoofStyles {
      for motion in [PoofMotion.stepped, .smooth] {
        let standard = try #require(
          snapshot(
            progress: 0.40,
            style: style,
            motion: motion,
            contrast: .standard
          )
        )
        let increased = try #require(
          snapshot(
            progress: 0.40,
            style: style,
            motion: motion,
            contrast: .increased
          )
        )

        #expect(standard.pixels != increased.pixels)
        #expect(
          increased.statistics.averageLuminance
            < standard.statistics.averageLuminance
        )
      }
    }
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
    for style in allPoofStyles {
      let oneX = try #require(
        snapshot(
          progress: 0.50,
          style: style,
          width: 42,
          height: 42,
          renderScale: 1
        )
      )
      let threeX = try #require(
        snapshot(
          progress: 0.50,
          style: style,
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
  }

  @Test("Field scale adds padding without scaling the art")
  func fieldScaleOnlyAddsPadding() throws {
    for style in allPoofStyles {
      let compactField = try #require(
        snapshot(
          progress: 0.50,
          style: style,
          width: 63,
          height: 63,
          artScale: 1.5
        )
      )
      let wideField = try #require(
        snapshot(
          progress: 0.50,
          style: style,
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
  }

  @Test("Modern styles produce visibly distinct smoke")
  func stylesAreDistinct() throws {
    for progress in [0.30, 0.50, 0.70] {
      let snapshots = try allPoofStyles.map { style in
        try #require(
          snapshot(
            progress: progress,
            style: style,
            reducesTransparency: true
          )
        )
      }

      for firstIndex in snapshots.indices {
        for secondIndex in snapshots.indices
        where secondIndex > firstIndex {
          let first = snapshots[firstIndex]
          let second = snapshots[secondIndex]

          #expect(first.pixels != second.pixels)
          #expect(first.normalizedDifference(from: second) > 0.025)
        }
      }
    }
  }

  @Test("Standalone effects keep artwork inside their canvas")
  func standaloneEffectsAvoidClipping() throws {
    for style in allPoofStyles {
      for progress in [0.10, 0.30, 0.50, 0.70, 0.90] {
        for reducesTransparency in [false, true] {
          let image = try #require(
            snapshot(
              progress: progress,
              style: style,
              reducesTransparency: reducesTransparency,
              renderScale: 2
            )
          )
          let bounds = try #require(image.statistics.bounds)

          #expect(bounds.minimumX > 0)
          #expect(bounds.minimumY > 0)
          #expect(bounds.maximumX < image.width - 1)
          #expect(bounds.maximumY < image.height - 1)
        }
      }
    }
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

  @Test("The second pose is visibly smaller than its neighbors")
  func compactSecondPose() throws {
    let cloudImage = try #require(snapshot(progress: 0.1))
    let clusterImage = try #require(snapshot(progress: 0.3))
    let puffsImage = try #require(snapshot(progress: 0.5))
    let cloud = try #require(cloudImage.statistics.bounds)
    let clusters = try #require(clusterImage.statistics.bounds)
    let puffs = try #require(puffsImage.statistics.bounds)

    #expect((79...83).contains(cloud.width))
    #expect((72...76).contains(cloud.height))
    #expect((55...60).contains(clusters.width))
    #expect((51...56).contains(clusters.height))
    #expect(clusters.width <= puffs.width - 12)
    #expect(clusters.height <= puffs.height - 12)
    #expect(clusters.area * 4 < cloud.area * 3)
    #expect(clusters.area * 4 < puffs.area * 3)
  }

  @Test("Unchanged poses retain their legacy measurement envelopes")
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

        // The compact cluster pose is an intentional departure from the
        // measured legacy sequence and has dedicated size coverage above.
        if index != 1 {
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
        }

        measurements.append(measurement)
      }

      let openingMass = measurements[0].normalizedAlphaMass
      let measuredRatios = measurements.map {
        $0.normalizedAlphaMass / openingMass
      }

      for (index, ratio) in measuredRatios.enumerated() {
        guard index != 1 else {
          continue
        }

        #expect(
          abs(ratio - LegacyReference.alphaMassRatios[index])
            <= LegacyReference.alphaMassRatioTolerances[index]
        )
      }
    }
  }

  private func expectGradualSourceRemoval(
    _ frames: [PixelSnapshot]
  ) {
    #expect(frames.count == 6)

    guard frames.count == 6 else {
      return
    }

    let sourceCounts = frames.map(\.sourceBluePixelCount)
    let identityCount = sourceCounts[0]

    #expect(identityCount > 0)
    #expect(sourceCounts[1] > identityCount / 5)
    #expect(sourceCounts[1] < identityCount)
    #expect(sourceCounts[2] <= sourceCounts[1])
    #expect(sourceCounts[3] == 0)
    #expect(sourceCounts[4] == 0)
    #expect(sourceCounts[5] == 0)
  }

  private func sourceCoverDepthProfile(
    for edge: SourceCoverEdge,
    path: Path,
    rect: CGRect,
    maximumDepth: Double
  ) -> [Double] {
    let sampleCount = 41
    let step = 0.125

    return (0..<sampleCount).map { sample in
      let fraction =
        0.08 + 0.84 * Double(sample) / Double(sampleCount - 1)
      var farthest = 0.0
      var distance = 0.0

      while distance <= maximumDepth {
        if path.contains(
          edge.point(
            in: rect,
            fraction: fraction,
            outwardDistance: distance
          ),
          eoFill: false
        ) {
          farthest = distance
        }
        distance += step
      }

      return farthest
    }
  }

  private func combinedPath(
    for elements: [PoofArtwork.SourceCoverElement]
  ) -> Path {
    var path = Path()

    for element in elements {
      path.addPath(element.path)
    }

    return path
  }

  private func sourceEdgeCoverageFractions(
    of path: Path,
    in rect: CGRect
  ) -> [Double] {
    let sampleCount = 41

    return SourceCoverEdge.allCases.map { edge in
      let coveredCount = (0..<sampleCount).count { sample in
        let fraction =
          0.05
          + 0.90 * Double(sample) / Double(sampleCount - 1)
        return path.contains(
          edge.point(
            in: rect,
            fraction: fraction,
            outwardDistance: 0
          )
        )
      }

      return Double(coveredCount) / Double(sampleCount)
    }
  }

  private func pointDistance(
    _ first: CGPoint,
    _ second: CGPoint
  ) -> Double {
    hypot(first.x - second.x, first.y - second.y)
  }

  private func pathsOverlapAlongCenterLine(
    _ first: PoofArtwork.SourceCoverElement,
    _ second: PoofArtwork.SourceCoverElement
  ) -> Bool {
    let distance = pointDistance(first.center, second.center)
    let segmentCount = max(Int(ceil(distance / 0.25)), 1)

    return (0...segmentCount).contains { segment in
      let progress = Double(segment) / Double(segmentCount)
      let point = CGPoint(
        x: first.center.x + (second.center.x - first.center.x) * progress,
        y: first.center.y + (second.center.y - first.center.y) * progress
      )
      return first.path.contains(point) && second.path.contains(point)
    }
  }

  private func expectedClusterGrowth(
    at index: Int
  ) -> Double {
    if index < PoofSourceCoverLayout.rootGlyphCount {
      return PoofArtwork.sourceCoverClusterRootGrowth
    }
    if index < PoofSourceCoverLayout.baseGlyphCount {
      return PoofArtwork.sourceCoverClusterChildGrowth
    }
    if index
      < PoofSourceCoverLayout.baseGlyphCount
      + PoofSourceCoverLayout.repairGlyphCount
    {
      return PoofArtwork.sourceCoverClusterRepairGrowth
    }
    return PoofArtwork.sourceCoverClusterFringeGrowth
  }

  private func sampledContainmentRatio(
    of path: Path,
    inside container: Path,
    spacing: Double
  ) -> Double {
    let bounds = path.boundingRect
    var occupiedCount = 0
    var retainedCount = 0
    var y = bounds.minY

    while y <= bounds.maxY {
      var x = bounds.minX

      while x <= bounds.maxX {
        let point = CGPoint(x: x, y: y)

        if path.contains(point) {
          occupiedCount += 1
          retainedCount += container.contains(point) ? 1 : 0
        }

        x += spacing
      }

      y += spacing
    }

    guard occupiedCount > 0 else {
      return 1
    }

    return Double(retainedCount) / Double(occupiedCount)
  }

  private func opposingProfileDifference(
    _ first: [Double],
    _ second: [Double]
  ) -> Double {
    let forward =
      zip(first, second).reduce(0) {
        $0 + abs($1.0 - $1.1)
      } / Double(first.count)
    let reversed =
      zip(first, second.reversed()).reduce(0) {
        $0 + abs($1.0 - $1.1)
      } / Double(first.count)

    return min(forward, reversed)
  }

  private func snapshot(
    progress: Double,
    style: PoofStyle = .classic,
    palette: PoofPalette = .automatic,
    motion: PoofMotion = .stepped,
    colorScheme: ColorScheme = .light,
    contrast: ColorSchemeContrast = .standard,
    reducesMotion: Bool = false,
    reducesTransparency: Bool = false,
    particleCount: Int = 28,
    width: Double = 84,
    height: Double = 84,
    renderScale: Double = 1,
    artScale: Double = 1,
    variationSeed: UInt64? = 0x504F_4F46
  ) -> PixelSnapshot? {
    let configuration = PoofConfiguration(
      particleCount: particleCount,
      seed: 0x504F_4F46
    )
    let content = PoofCanvas(
      progress: progress,
      palette: PoofResolvedPalette(
        contrast: contrast,
        palette: palette,
        style: style
      ),
      motion: motion,
      reducesMotion: reducesMotion,
      reducesTransparency: reducesTransparency,
      artScale: artScale,
      frameSet: variationSeed.map { seed in
        PoofSimulation.makeFrameSet(
          configuration: configuration,
          style: style,
          variationSeed: seed
        )
      },
      occludesSource: false
    )
    .environment(\.colorScheme, colorScheme)
    .frame(width: width, height: height)
    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(width: width, height: height)
    renderer.scale = renderScale

    guard let image = renderer.cgImage else {
      return nil
    }

    return PixelSnapshot(image: image)
  }

  private func progressiveSmokeSnapshot(
    progress: Double,
    style: PoofStyle,
    renderScale: Double,
    motion: PoofMotion = .stepped,
    variationSeed: UInt64 = 0x504F_4F46
  ) -> PixelSnapshot? {
    let sourceSize = CGSize(width: 84, height: 84)
    let artSide = PoofLayout.artSide(for: sourceSize)
    let padding = artSide * 0.16
    let canvasSize = CGSize(
      width: sourceSize.width + padding * 2,
      height: sourceSize.height + padding * 2
    )
    let configuration = PoofConfiguration(seed: variationSeed)
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: configuration,
      style: style,
      variationSeed: variationSeed
    )
    let content = PoofCanvas(
      progress: progress,
      palette: PoofResolvedPalette(
        contrast: .standard,
        style: style
      ),
      motion: motion,
      reducesMotion: false,
      reducesTransparency: true,
      artScale: configuration.fieldScale,
      frameSet: frameSet,
      occludesSource: true,
      referenceArtSide: artSide,
      sourceSize: sourceSize
    )
    .frame(width: canvasSize.width, height: canvasSize.height)
    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(canvasSize)
    renderer.scale = renderScale

    guard let image = renderer.cgImage else {
      return nil
    }

    return PixelSnapshot(image: image)
  }

  private func contentRemovalSnapshots(
    progresses: [Double],
    style: PoofStyle = .classic,
    motion: PoofMotion = .stepped,
    colorScheme: ColorScheme = .light,
    reducesMotion: Bool = false,
    width: Double = 84,
    height: Double = 84,
    renderScale: Double = 1,
    fieldScale: Double = PoofConfiguration.standard.fieldScale,
    variationSeed: UInt64? = 0x504F_4F46
  ) -> [PixelSnapshot]? {
    guard progresses.isEmpty == false else {
      return []
    }

    let content = ContentRemovalStrip(
      progresses: progresses,
      style: style,
      motion: motion,
      reducesMotion: reducesMotion,
      width: width,
      height: height,
      fieldScale: fieldScale,
      variationSeed: variationSeed
    )
    .environment(\.colorScheme, colorScheme)
    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(
      width: width * Double(progresses.count),
      height: height
    )
    renderer.scale = renderScale

    guard
      let image = renderer.cgImage,
      image.width.isMultiple(of: progresses.count)
    else {
      return nil
    }

    let cellWidth = image.width / progresses.count

    return progresses.indices.compactMap { index in
      image.cropping(
        to: CGRect(
          x: index * cellWidth,
          y: 0,
          width: cellWidth,
          height: image.height
        )
      ).map(PixelSnapshot.init)
    }
  }

  private func progressiveTransitionSnapshots(
    progresses: [Double],
    style: PoofStyle = .classic,
    motion: PoofMotion = .stepped,
    colorScheme: ColorScheme = .light,
    contrast: ColorSchemeContrast = .standard,
    reducesTransparency: Bool = false,
    width: Double = 84,
    height: Double = 84,
    renderScale: Double = 1,
    variationSeed: UInt64 = 0x504F_4F46,
    sourceColor: Color = Color(
      .sRGB,
      red: 0.04,
      green: 0.24,
      blue: 1
    )
  ) -> [PixelSnapshot]? {
    guard progresses.isEmpty == false else {
      return []
    }

    let content = ProgressiveTransitionStrip(
      progresses: progresses,
      style: style,
      motion: motion,
      contrast: contrast,
      reducesTransparency: reducesTransparency,
      width: width,
      height: height,
      variationSeed: variationSeed,
      sourceColor: sourceColor
    )
    .environment(\.colorScheme, colorScheme)
    let renderer = ImageRenderer(content: content)
    renderer.proposedSize = ProposedViewSize(
      width: width * Double(progresses.count),
      height: height
    )
    renderer.scale = renderScale

    guard
      let image = renderer.cgImage,
      image.width.isMultiple(of: progresses.count)
    else {
      return nil
    }

    let cellWidth = image.width / progresses.count

    return progresses.indices.compactMap { index in
      image.cropping(
        to: CGRect(
          x: index * cellWidth,
          y: 0,
          width: cellWidth,
          height: image.height
        )
      ).map(PixelSnapshot.init)
    }
  }
}

private struct ContentRemovalStrip: View {
  let progresses: [Double]
  let style: PoofStyle
  let motion: PoofMotion
  let reducesMotion: Bool
  let width: Double
  let height: Double
  let fieldScale: Double
  let variationSeed: UInt64?

  var body: some View {
    let configuration = PoofConfiguration(
      fieldScale: fieldScale,
      seed: variationSeed
    )
    let frameSet = variationSeed.map { seed in
      PoofSimulation.makeFrameSet(
        configuration: configuration,
        style: style,
        variationSeed: seed
      )
    }

    HStack(spacing: 0) {
      ForEach(Array(progresses.enumerated()), id: \.offset) {
        _, progress in
        Rectangle()
          .fill(
            Color(
              .sRGB,
              red: 0.12,
              green: 0.42,
              blue: 0.92
            )
          )
          .frame(width: width, height: height)
          .modifier(
            PoofContentRemovalModifier(
              progress: progress,
              contentRemoval: .progressive,
              motion: motion,
              reducesMotion: reducesMotion,
              frameSet: frameSet
            )
          )
      }
    }
  }
}

private struct ProgressiveTransitionStrip: View {
  let progresses: [Double]
  let style: PoofStyle
  let motion: PoofMotion
  let contrast: ColorSchemeContrast
  let reducesTransparency: Bool
  let width: Double
  let height: Double
  let variationSeed: UInt64
  let sourceColor: Color

  var body: some View {
    let configuration = PoofConfiguration(seed: variationSeed)
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: configuration,
      style: style,
      variationSeed: variationSeed
    )

    HStack(spacing: 0) {
      ForEach(Array(progresses.enumerated()), id: \.offset) {
        _, progress in
        Rectangle()
          .fill(sourceColor)
          .frame(width: width, height: height)
          .modifier(
            PoofContentRemovalModifier(
              progress: progress,
              contentRemoval: .progressive,
              motion: motion,
              reducesMotion: false,
              frameSet: frameSet
            )
          )
          .overlay {
            GeometryReader { geometry in
              let artSide = PoofLayout.artSide(for: geometry.size)
              let canvasSize = PoofLayout.canvasSize(
                for: geometry.size,
                fieldScale: configuration.fieldScale,
                coversSource: true
              )

              PoofCanvas(
                progress: progress,
                palette: PoofResolvedPalette(
                  contrast: contrast,
                  style: style
                ),
                motion: motion,
                reducesMotion: false,
                reducesTransparency: reducesTransparency,
                artScale: configuration.fieldScale,
                frameSet: frameSet,
                occludesSource: true,
                referenceArtSide: artSide,
                sourceSize: geometry.size
              )
              .frame(width: canvasSize.width, height: canvasSize.height)
              .position(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
              )
            }
          }
          .frame(width: width, height: height)
          .clipped()
      }
    }
  }
}

private struct AlphaMask {
  let width: Int
  let height: Int
  let included: [Bool]
  let count: Int
  let centroid: CGPoint

  init(
    snapshot: PixelSnapshot,
    threshold: UInt8 = 128
  ) {
    width = snapshot.width
    height = snapshot.height
    var included = [Bool](
      repeating: false,
      count: snapshot.width * snapshot.height
    )
    var count = 0
    var weightedX = 0.0
    var weightedY = 0.0

    for pixelIndex in included.indices {
      let isIncluded =
        snapshot.pixels[pixelIndex * 4 + 3] >= threshold
      included[pixelIndex] = isIncluded

      if isIncluded {
        count += 1
        weightedX += Double(pixelIndex % snapshot.width)
        weightedY += Double(pixelIndex / snapshot.width)
      }
    }

    self.included = included
    self.count = count
    centroid =
      if count > 0 {
        CGPoint(
          x: weightedX / Double(count),
          y: weightedY / Double(count)
        )
      } else {
        .zero
      }
  }

  func intersectionCount(with other: AlphaMask) -> Int {
    guard
      width == other.width,
      height == other.height
    else {
      return 0
    }

    return zip(included, other.included).reduce(0) {
      $0 + ($1.0 && $1.1 ? 1 : 0)
    }
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

  func maximumColorDifference(from other: PixelSnapshot) -> Int {
    guard pixels.count == other.pixels.count else {
      return .max
    }

    return stride(from: 0, to: pixels.count, by: 4).reduce(0) {
      maximum,
      offset in
      max(maximum, colorDifference(at: offset, from: other))
    }
  }

  func colorDifferencePixelCount(
    from other: PixelSnapshot,
    tolerance: Int = 1
  ) -> Int {
    guard pixels.count == other.pixels.count else {
      return .max
    }

    return stride(from: 0, to: pixels.count, by: 4).reduce(0) {
      $0 + (colorDifference(at: $1, from: other) > tolerance ? 1 : 0)
    }
  }

  var chromaticPixelCount: Int {
    stride(from: 0, to: pixels.count, by: 4).reduce(0) {
      count,
      offset in
      let alpha = pixels[offset + 3]

      guard alpha >= 4 else {
        return count
      }

      let red = Int(pixels[offset])
      let green = Int(pixels[offset + 1])
      let blue = Int(pixels[offset + 2])
      let maximum = max(red, green, blue)
      let minimum = min(red, green, blue)
      return count + (maximum - minimum >= 4 ? 1 : 0)
    }
  }

  var sourceBluePixelCount: Int {
    stride(from: 0, to: pixels.count, by: 4).reduce(0) {
      $0 + (isSourceBluePixel(at: $1) ? 1 : 0)
    }
  }

  var sourceBlueConnectedComponentCount: Int {
    connectedComponentCount(minimumArea: 4) {
      isSourceBluePixel(at: $0)
    }
  }

  func alphaExcessPixelCount(
    over previous: PixelSnapshot,
    tolerance: UInt8 = 4
  ) -> Int {
    guard pixels.count == previous.pixels.count else {
      return .max
    }

    return stride(from: 3, to: pixels.count, by: 4).reduce(0) {
      count,
      offset in
      let excess =
        Int(pixels[offset])
        - Int(previous.pixels[offset])
      return count + (excess > Int(tolerance) ? 1 : 0)
    }
  }

  func sourceExposureReappearanceCount(
    comparedWith alternate: PixelSnapshot,
    over previous: PixelSnapshot,
    previousAlternate: PixelSnapshot,
    coveredThreshold: Int = 4,
    exposedThreshold: Int = 32
  ) -> Int {
    guard
      pixels.count == alternate.pixels.count,
      pixels.count == previous.pixels.count,
      pixels.count == previousAlternate.pixels.count
    else {
      return .max
    }

    return stride(from: 0, to: pixels.count, by: 4).reduce(0) {
      count,
      offset in
      let currentInfluence = colorDifference(
        at: offset,
        from: alternate
      )
      let previousInfluence = previous.colorDifference(
        at: offset,
        from: previousAlternate
      )

      return count
        + (previousInfluence <= coveredThreshold
          && currentInfluence >= exposedThreshold
          ? 1
          : 0)
    }
  }

  private func colorDifference(
    at offset: Int,
    from other: PixelSnapshot
  ) -> Int {
    (0..<3).reduce(0) { difference, channel in
      max(
        difference,
        abs(
          Int(pixels[offset + channel])
            - Int(other.pixels[offset + channel])
        )
      )
    }
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
    connectedComponentCount(minimumArea: minimumArea) { offset in
      let luminance =
        (2_126 * Int(pixels[offset])
          + 7_152 * Int(pixels[offset + 1])
          + 722 * Int(pixels[offset + 2])) / 10_000
      return luminance >= luminanceThreshold
    }
  }

  private func connectedComponentCount(
    minimumArea: Int,
    includes: (Int) -> Bool
  ) -> Int {
    var included = [Bool](repeating: false, count: width * height)

    for pixelIndex in included.indices {
      let offset = pixelIndex * 4
      included[pixelIndex] = includes(offset)
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

  private func isSourceBluePixel(at offset: Int) -> Bool {
    let alpha = Int(pixels[offset + 3])
    let red = Int(pixels[offset])
    let green = Int(pixels[offset + 1])
    let blue = Int(pixels[offset + 2])

    return alpha >= 4
      && blue - max(red, green) >= 96
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
