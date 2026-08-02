import SwiftUI
import Testing

@testable import Poof

@MainActor
@Suite("Poof transition")
struct PoofTransitionTests {
  @Test("Poof timing is the five-pose clock unless overridden")
  func poofAnimationTiming() {
    #expect(Animation.poof == .linear(duration: PoofSimulation.duration))
    #expect(Animation.poof(duration: 0.5) == .linear(duration: 0.5))
    // Clamped, so a stray value cannot stall or blink the effect.
    #expect(Animation.poof(duration: 0) == .linear(duration: 0.15))
    #expect(Animation.poof(duration: 99) == .linear(duration: 1.5))
    #expect(
      Animation.poof(duration: .nan)
        == .linear(duration: PoofSimulation.duration)
    )
    // The clock is the recreation's own and must not have moved.
    #expect(PoofSimulation.duration == 1.0 / 3.0)
  }

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

  @Test("Playback draws one progress per pose interval")
  func steppedDrawnProgressCollapsesToPoses() {
    let interiorSamples = stride(from: 0.01, through: 0.99, by: 0.01)
    var drawn = Set<Double>()

    for progress in interiorSamples {
      let value = PoofSimulation.drawnProgress(for: progress)

      drawn.insert(value)
      // Collapsing must not move a frame into a neighboring pose.
      #expect(
        PoofSimulation.pose(for: value)
          == PoofSimulation.pose(for: progress)
      )
    }

    #expect(drawn.count == PoofPose.allCases.count)

    // Endpoints pass through so they stay transparent.
    for endpoint in [0.0, 1.0, -1.0, 2.0] {
      #expect(
        PoofSimulation.drawnProgress(for: endpoint) == endpoint
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
    requireSendable(PoofContentRemoval.self)
    requireSendable(PoofTransition.self)
  }

  @Test("Styled transition remains available without changing classic API")
  func styledTransitionAPI() {
    let classic = PoofTransition()
    let bloom = PoofTransition(style: .bloom)
    let progressive = PoofTransition(contentRemoval: .progressive)
    let pastelSnap = PoofTransition(
      style: .snap,
      contentRemoval: .progressive,
      palette: .pastel
    )

    requireSendable(type(of: classic))
    requireSendable(type(of: bloom))
    requireSendable(type(of: progressive))
    requireSendable(type(of: pastelSnap))
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

  @Test("Erosion steps carry a solved boolean, not a pending one")
  func erosionStepsAreSettled() throws {
    let rect = CGRect(x: 0, y: 0, width: 84, height: 84)

    // A `Path` boolean is lazy, and an unsolved one lies about being empty:
    // this subtracts a rect from itself and still reports content. Whatever
    // asks for the geometry first pays for the solve, and in a mask that is
    // the main thread, every frame.
    let pending = Path(rect).subtracting(Path(rect), eoFill: false)

    #expect(!pending.isEmpty)
    #expect(Path(pending.cgPath).isEmpty)

    // Going through CGPath settles it without moving it.
    let bitten = Path(rect).subtracting(
      Path(ellipseIn: rect.insetBy(dx: 20, dy: 20)),
      eoFill: false
    )
    let settled = Path(bitten.cgPath)

    #expect(!settled.isEmpty)
    #expect(settled.boundingRect.equalTo(bitten.boundingRect))

    for row in stride(from: 0.5, to: rect.height, by: 3) {
      for column in stride(from: 0.5, to: rect.width, by: 3) {
        let point = CGPoint(x: column, y: row)

        #expect(settled.contains(point) == bitten.contains(point))
      }
    }

    // What the factory builds is settled, so a step that has eaten everything
    // reports it — which is what `engulfProgress` and the retirement guard
    // both read.
    let size = CGSize(width: 84, height: 84)
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(seed: 7),
      variationSeed: 7
    )
    let erosion = try #require(
      PoofSourceErosion.stepped(size: size, frameSet: frameSet)
    )

    #expect(erosion.engulfProgress > 0)
    #expect(erosion.engulfProgress <= 0.6)
    #expect(erosion.path(for: erosion.engulfProgress, in: rect).isEmpty)
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
