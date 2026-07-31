import SwiftUI
import Testing

@testable import Poof

@MainActor
@Suite("Poof transition")
struct PoofTransitionTests {
  @Test("A playback keeps one seed across rebuilds")
  func playbackSeedSurvivesRebuilds() {
    var rolls = 0
    let randomSeed: () -> UInt64 = {
      rolls += 1
      return 0xABCD
    }
    let unseeded = PoofConfiguration()

    let first = PoofPlaybackSeed.resolve(
      configuration: unseeded,
      cached: nil,
      randomSeed: randomSeed
    )
    // A resize rebuilds the layout. Re-rolling here would swap the poof for a
    // different one between two frames of the same playback.
    let second = PoofPlaybackSeed.resolve(
      configuration: unseeded,
      cached: first,
      randomSeed: randomSeed
    )

    #expect(rolls == 1)
    #expect(first == second)

    let seeded = PoofConfiguration(seed: 0x504F_4F46)

    #expect(
      PoofPlaybackSeed.resolve(
        configuration: seeded,
        cached: nil,
        randomSeed: randomSeed
      ) == 0x504F_4F46
    )
    // An explicit seed outranks whatever a previous playback cached.
    #expect(
      PoofPlaybackSeed.resolve(
        configuration: seeded,
        cached: 0x1234,
        randomSeed: randomSeed
      ) == 0x504F_4F46
    )
    #expect(rolls == 1)
  }

  @Test("Stepped playback draws one progress per pose interval")
  func steppedDrawnProgressCollapsesToPoses() {
    let interiorSamples = stride(from: 0.01, through: 0.99, by: 0.01)
    var drawn = Set<Double>()

    for progress in interiorSamples {
      let value = PoofSimulation.drawnProgress(
        for: progress,
        motion: .stepped
      )

      drawn.insert(value)
      // Collapsing must not move a frame into a neighboring pose.
      #expect(
        PoofSimulation.pose(for: value)
          == PoofSimulation.pose(for: progress)
      )
    }

    #expect(drawn.count == PoofPose.allCases.count)

    // Smooth playback needs every value it is given.
    for progress in interiorSamples {
      #expect(
        PoofSimulation.drawnProgress(for: progress, motion: .smooth)
          == progress
      )
    }

    // Endpoints pass through so they stay transparent.
    for endpoint in [0.0, 1.0, -1.0, 2.0] {
      #expect(
        PoofSimulation.drawnProgress(for: endpoint, motion: .stepped)
          == endpoint
      )
    }
  }

  @Test("Insertion stays quiet")
  func insertion() {
    let state = PoofTransition.state(for: .willAppear)

    #expect(state.progress == 0)
    #expect(!state.isRemoving)
  }

  @Test("Identity keeps the source visible")
  func identity() {
    let state = PoofTransition.state(for: .identity)

    #expect(state.progress == 0)
    #expect(!state.isRemoving)
  }

  @Test("Removal starts the poof and retires source interaction")
  func removal() {
    let state = PoofTransition.state(for: .didDisappear)

    #expect(state.progress == 1)
    #expect(state.isRemoving)
  }

  @Test("Core configuration and transition values are Sendable")
  func sendableTypes() {
    requireSendable(PoofConfiguration.self)
    requireSendable(PoofStyle.self)
    requireSendable(PoofPalette.self)
    requireSendable(PoofMotion.self)
    requireSendable(PoofContentRemoval.self)
    requireSendable(PoofTransition.self)
  }

  @Test("Styled transition remains available without changing classic API")
  func styledTransitionAPI() {
    let classic = PoofTransition()
    let bloom = PoofTransition(style: .bloom)
    let progressive = PoofTransition(contentRemoval: .progressive)
    let smoothPastelSnap = PoofTransition(
      style: .snap,
      contentRemoval: .progressive,
      palette: .pastel,
      motion: .smooth
    )

    requireSendable(type(of: classic))
    requireSendable(type(of: bloom))
    requireSendable(type(of: progressive))
    requireSendable(type(of: smoothPastelSnap))
  }

  @Test("Immediate and progressive removal preserve their source semantics")
  func contentVisibility() {
    #expect(
      PoofContentVisibility.opacity(
        progress: 0,
        contentRemoval: .immediate,
        reducesMotion: false
      ) == 1
    )
    #expect(
      PoofContentVisibility.opacity(
        progress: .leastNonzeroMagnitude,
        contentRemoval: .immediate,
        reducesMotion: false
      ) == 0
    )
    let progressivePoses: [(Double, Double)] = [
      (0.10, 1),
      (0.30, 1),
      (0.50, 1),
      (0.70, 1),
      (0.90, 1),
    ]

    for (progress, expectedOpacity) in progressivePoses {
      #expect(
        PoofContentVisibility.opacity(
          progress: progress,
          contentRemoval: .progressive,
          reducesMotion: false
        ) == expectedOpacity
      )
    }
  }

  @Test("Progressive removal eats the source from the smoke outward")
  func progressiveSourceErosion() throws {
    let size = CGSize(width: 84, height: 84)
    let rect = CGRect(origin: .zero, size: size)
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(seed: 1),
      variationSeed: 1
    )
    let erosion = try #require(
      PoofSourceErosion.stepped(size: size, frameSet: frameSet)
    )

    func visibleArea(atProgress progress: Double) -> Int {
      let path = erosion.path(for: progress, in: rect)
      var count = 0

      for row in stride(from: 0.5, to: size.height, by: 1) {
        for column in stride(from: 0.5, to: size.width, by: 1) {
          if path.contains(CGPoint(x: column, y: row)) {
            count += 1
          }
        }
      }

      return count
    }

    let whole = Int(size.width * size.height)
    let cloud = visibleArea(atProgress: 0.10)
    let clusters = visibleArea(atProgress: 0.30)

    // The source survives where smoke has not reached, which is what makes
    // this consumption rather than a lid dropped over the top.
    #expect(cloud > 0)
    #expect(cloud < whole)
    // A bite once taken is never given back.
    #expect(clusters < cloud)
    // The dense pose is proven to tile the bounds, so nothing is left.
    #expect(visibleArea(atProgress: 0.50) == 0)
    #expect(visibleArea(atProgress: 0.90) == 0)

    #expect(erosion.path(for: 0, in: rect) == Path(rect))
    #expect(erosion.path(for: 1, in: rect).isEmpty)
  }

  @Test("Reduce Motion replaces spatial removal with a bounded fade")
  func reduceMotionVisibility() {
    for contentRemoval in [
      PoofContentRemoval.immediate,
      .progressive,
    ] {
      #expect(
        PoofContentVisibility.opacity(
          progress: -.infinity,
          contentRemoval: contentRemoval,
          reducesMotion: true
        ) == 1
      )
      #expect(
        PoofContentVisibility.opacity(
          progress: 0.25,
          contentRemoval: contentRemoval,
          reducesMotion: true
        ) == 0.75
      )
      #expect(
        PoofContentVisibility.opacity(
          progress: .infinity,
          contentRemoval: contentRemoval,
          reducesMotion: true
        ) == 0
      )
    }
  }

  @Test("Source-mask pose swaps disable interpolation")
  func sourceMaskPoseSwaps() {
    var transaction = Transaction(animation: .linear(duration: 1))

    #expect(transaction.animation != nil)
    #expect(!transaction.disablesAnimations)

    PoofSourceRemoval.snap(&transaction)

    #expect(transaction.animation == nil)
    #expect(transaction.disablesAnimations)
  }

  @Test("Source mask has no interpolatable state")
  func sourceMaskIsDiscrete() {
    requireDiscreteShape(PoofSourceMask.self)
  }

  private func requireDiscreteShape<S: Shape>(_: S.Type)
  where S.AnimatableData == EmptyAnimatableData {}

  private func requireSendable<T: Sendable>(_: T.Type) {}
}
