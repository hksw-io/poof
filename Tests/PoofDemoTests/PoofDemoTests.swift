#if os(macOS)
  import Testing

  @testable import PoofDemo

  @Suite("Poof demo")
  struct PoofDemoTests {
    @Test("Demo surfaces exercise equal and wide bounds")
    func demoSurfaces() {
      #expect(
        DemoSurface.allCases == [
          .roundedSquare,
          .circle,
          .capsule,
          .star,
        ]
      )
      #expect(
        DemoSurface.circle.size == DemoSurface.roundedSquare.size
      )
      #expect(
        DemoSurface.star.size == DemoSurface.roundedSquare.size
      )
      #expect(
        DemoSurface.roundedSquare.size.width == 88
          && DemoSurface.roundedSquare.size.height == 88
      )
      #expect(
        DemoSurface.capsule.size.width == 132
          && DemoSurface.capsule.size.height == 48
      )
      #expect(
        DemoSurface.capsule.size.width
          / DemoSurface.capsule.size.height
          > 1.4
      )
      #expect(
        DemoSurface.allCases.map(\.id) == DemoSurface.allCases
      )
    }

    @Test("Slow motion duration is five seconds")
    func slowMotionDuration() {
      let poseCount = DemoPreviewMode.allCases.compactMap(\.progress).count

      #expect(DemoPreviewMode.slowMotion.isPlayback)
      #expect(DemoPreviewMode.slowMotion.progress == nil)
      #expect(poseCount == 5)
      #expect(DemoPreviewMode.slowPoseDuration == 1)
      #expect(DemoPreviewMode.slowPlaybackDuration == 5)
      #expect(
        DemoPreviewMode.slowPlaybackDuration
          == DemoPreviewMode.slowPoseDuration * Double(poseCount)
      )
    }

    @Test("Static poses remain separate from playback modes")
    func staticPoses() {
      #expect(DemoPreviewMode.animation.isPlayback)
      #expect(!DemoPreviewMode.cloud.isPlayback)
      #expect(!DemoPreviewMode.clusters.isPlayback)
      #expect(!DemoPreviewMode.puffs.isPlayback)
      #expect(!DemoPreviewMode.wisps.isPlayback)
      #expect(!DemoPreviewMode.ringlets.isPlayback)
    }
  }
#endif
