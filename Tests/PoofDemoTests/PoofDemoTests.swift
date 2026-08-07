#if os(macOS)
  import Foundation
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

    @Test("The playback clock clamps to the playback window")
    func playbackClock() {
      let start = Date(timeIntervalSinceReferenceDate: 100)

      // No playback yet reads as zero.
      #expect(
        DemoPlaybackClockModel.elapsed(
          since: nil,
          at: start,
          duration: 5
        ) == 0
      )
      // A skewed clock cannot count backward.
      #expect(
        DemoPlaybackClockModel.elapsed(
          since: start,
          at: start.addingTimeInterval(-1),
          duration: 5
        ) == 0
      )
      // Mid-playback is the plain interval.
      #expect(
        abs(
          DemoPlaybackClockModel.elapsed(
            since: start,
            at: start.addingTimeInterval(2.2),
            duration: 5
          ) - 2.2
        ) < 1e-9
      )
      // The readout freezes at the end instead of counting into the
      // silence after the poof.
      #expect(
        DemoPlaybackClockModel.elapsed(
          since: start,
          at: start.addingTimeInterval(9),
          duration: 5
        ) == 5
      )

      // The frozen reading is a property of the arithmetic, not of the clock
      // still ticking: long after the poof ends, the same values come back.
      // That is what lets the schedule pause when playback finishes.
      for multiple in [2.0, 20.0] {
        #expect(
          DemoPlaybackClockModel.elapsed(
            since: start,
            at: start.addingTimeInterval(5 * multiple),
            duration: 5
          ) == 5
        )
      }
      #expect(
        DemoPlaybackClockModel.progress(
          elapsed: DemoPlaybackClockModel.elapsed(
            since: start,
            at: start.addingTimeInterval(100),
            duration: 5
          ),
          duration: 5
        ) == 1
      )

      #expect(DemoPlaybackClockModel.progress(elapsed: 0, duration: 5) == 0)
      #expect(
        abs(
          DemoPlaybackClockModel.progress(elapsed: 2.2, duration: 5) - 0.44
        ) < 1e-9
      )
      #expect(DemoPlaybackClockModel.progress(elapsed: 9, duration: 5) == 1)
      #expect(DemoPlaybackClockModel.progress(elapsed: 1, duration: 0) == 0)
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

      // Resetting clears the clock without advancing the seed, which is what
      // a settings change needs.
      model.previewMode = .animation
      model.reset()
      #expect(model.playbackSeed == seed)
      #expect(model.playbackStart == nil)
      #expect(!model.isClockRunning)
    }
  }

#endif
