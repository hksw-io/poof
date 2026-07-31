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

    @Test("Playback duration spans the production and inspection timings")
    func playbackDuration() {
      let poseCount = DemoPreviewMode.allCases.compactMap(\.progress).count

      #expect(poseCount == 5)
      #expect(DemoPlaybackDuration.defaultValue == 1.0 / 3.0)
      #expect(DemoPlaybackDuration.range.lowerBound == 1.0 / 3.0)
      #expect(DemoPlaybackDuration.range.upperBound == 5)
      #expect(DemoPlaybackDuration.step == 1.0 / 6.0)
      #expect(
        DemoPreviewMode.animation.playbackAnimation(
          duration: DemoPlaybackDuration.defaultValue
        ) != nil
      )
    }

    @Test("Static poses remain separate from playback modes")
    func staticPoses() {
      #expect(DemoPreviewMode.animation.isPlayback)
      #expect(
        DemoPreviewMode.cloud.playbackAnimation(duration: 1) == nil
      )
      #expect(!DemoPreviewMode.cloud.isPlayback)
      #expect(!DemoPreviewMode.clusters.isPlayback)
      #expect(!DemoPreviewMode.puffs.isPlayback)
      #expect(!DemoPreviewMode.wisps.isPlayback)
      #expect(!DemoPreviewMode.ringlets.isPlayback)
    }

    @Test("Demo compares every remaining style")
    func styles() {
      #expect(
        DemoPoofStyle.allCases == [
          .classic,
          .bloom,
          .snap,
        ]
      )
      #expect(DemoPoofStyle.classic.poofStyle == .classic)
      #expect(DemoPoofStyle.bloom.poofStyle == .bloom)
      #expect(DemoPoofStyle.snap.poofStyle == .snap)
    }

    @Test("Demo exposes every palette and motion option")
    func renderingOptions() {
      #expect(
        DemoPalette.allCases == [
          .automatic,
          .pastel,
        ]
      )
      #expect(DemoPalette.automatic.poofPalette == .automatic)
      #expect(DemoPalette.pastel.poofPalette == .pastel)
      #expect(DemoMotion.allCases == [.stepped, .smooth])
      #expect(DemoMotion.stepped.poofMotion == .stepped)
      #expect(DemoMotion.smooth.poofMotion == .smooth)
    }
  }
#endif
