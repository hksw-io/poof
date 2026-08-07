# Changelog

## 1.1.0 - 2026-08-08

- Adds `View.poof(at:size:style:configuration:palette:trigger:)` for independent
  poofs at local points. Rapid triggers can overlap without removing, disabling,
  or adding accessibility content to the source view.
- Keeps every playback on the original one-third-second clock. The deprecated
  `Animation.poof(duration:)` overload remains available for compatibility and
  uses the fixed timing.

## 1.0.0 - 2026-08-02

Poof brings a clean-room take on AppKit's former disappearing-item effect to
SwiftUI on OS 26 and later.

- Recreates the compact five-pose poof with original vector artwork: full
  cloud, four clusters, dense puffs, sparse wisps, then ringlets, swapped
  without interpolation at 15 frames per second.
- Adds the opt-in Bloom and Snap styles alongside the faithful Classic.
- Draws every style grayscale by default, with pastel and custom fill palettes
  available as opt-in choices.
- Supports progressive content removal that consumes the source where smoke
  reaches it rather than hiding it behind paint. Bites accumulate, so covered
  pixels carry forward and a bite is never given back.
- Chooses one coherent variation per playback, with fixed seeds for repeatable
  rendering, and derives every frame from absolute progress so a playback is
  scrubbable.
- Prepares progressive playback off the main thread, path booleans included, so
  a list of rows neither serializes on it nor pays for it during the render
  pass.
- Responds to Reduce Motion, Reduce Transparency, and Increased Contrast.
- Includes a macOS demo comparing all three styles at once, with surface,
  palette, appearance, pose, and duration controls.
- Builds as a Swift 6.3 package for iOS, macOS, tvOS, watchOS, and visionOS.
