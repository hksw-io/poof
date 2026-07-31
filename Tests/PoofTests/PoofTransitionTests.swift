import SwiftUI
import Testing

@testable import Poof

@MainActor
@Suite("Poof transition")
struct PoofTransitionTests {
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

  @Test("Progressive source retires at the fully covering pose")
  func progressiveSourceMask() {
    let rect = CGRect(x: 0, y: 0, width: 84, height: 84)
    let frameSet = PoofSimulation.makeFrameSet(
      configuration: PoofConfiguration(seed: 1),
      variationSeed: 1
    )

    #expect(
      !PoofArtwork.sourceMaskPath(for: .cloud, in: rect).isEmpty
    )
    #expect(
      !PoofArtwork.sourceMaskPath(for: .clusters, in: rect).isEmpty
    )

    for pose in [PoofPose.puffs, .wisps, .ringlets] {
      #expect(PoofArtwork.sourceMaskPath(for: pose, in: rect).isEmpty)
    }

    #expect(
      !PoofSourceMask(
        progress: 0.499_999,
        motion: .smooth,
        frameSet: frameSet
      ).path(in: rect).isEmpty
    )
    #expect(
      PoofSourceMask(
        progress: 0.5,
        motion: .smooth,
        frameSet: frameSet
      ).path(in: rect).isEmpty
    )
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
