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
    }

    @Test("Static poses remain separate from playback modes")
    func staticPoses() {
      #expect(DemoPreviewMode.animation.isPlayback)
      #expect(DemoPreviewMode.animation.progress == nil)
      #expect(DemoPreviewMode.allCases.compactMap(\.progress).count == 5)
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

    @Test("Demo exposes every palette and appearance option")
    func renderingOptions() {
      #expect(
        DemoPalette.allCases == [
          .automatic,
          .pastel,
        ]
      )
      #expect(DemoPalette.automatic.poofPalette == .automatic)
      #expect(DemoPalette.pastel.poofPalette == .pastel)
      #expect(DemoAppearance.allCases == [.system, .light, .dark])
      #expect(DemoAppearance.system.colorScheme == nil)
      #expect(DemoAppearance.light.colorScheme == .light)
      #expect(DemoAppearance.dark.colorScheme == .dark)
    }

    @MainActor
    @Test("The demo model gates poof and restore on what is on screen")
    func demoModelCommands() {
      let model = DemoModel()

      // The toolbar button and the menu command read the same state, so they
      // cannot disagree about which verb is available.
      #expect(model.isItemVisible)
      #expect(model.canPoof)
      #expect(!model.canRestore)

      // A static pose is not a playback, so neither verb applies.
      model.previewMode = .puffs
      #expect(!model.canPoof)
      #expect(!model.canRestore)

      // Restoring what is already present is a no-op, seed included.
      let seed = model.playbackSeed
      model.restore()
      #expect(model.playbackSeed == seed)
      #expect(model.isItemVisible)

      // Resetting does not advance the seed, which is what a settings change
      // needs.
      model.previewMode = .animation
      model.reset()
      #expect(model.playbackSeed == seed)
    }
  }

#endif
