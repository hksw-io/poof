# Changelog

## Unreleased

### Changed

- Draws classic smoke with puffs only. Every frame of the effect this package
  recreates is built from bumpy multi-lobe puffs, so rings, curls, and flecks
  now belong to Bloom and Snap, and size carries the dissipation instead.
- Restores the measured second pose, reverting the compaction added in 1.1.0.
  The original contracts in width and mass but is fractionally taller at the
  second frame, and the rendering envelope now covers all five poses rather
  than exempting that one.
- Matches the measured ink weight: darker outlines and detail marks, and a
  drop shadow that sits lower, spreads further, and reads as a shadow.
  Increased Contrast moves further still so it remains a visible affordance.
- Replaces tweened smooth motion with a continuous plume. Each puff now
  follows its own trajectory rather than being interpolated between the five
  authored poses, so the motion no longer reads as five phases blended.
- Consumes the source under progressive removal instead of hiding it. Smoke
  eats the view where it arrives, and a bite once taken is never given back.

### Added

- Adds `Animation.poof(motion:)` and `Animation.poof(duration:)`. Smooth
  playback runs slightly longer by default, because continuous dissipation
  reads as clipped at a third of a second. Bare `.poof` is unchanged.

### Fixed

- Fixes the measured size calibration and shape selection keying on the glyph
  slot rather than the descriptor it was fitted against, which let the sparse
  pose out-weigh the dense one at particle counts other than the default.
- Stops `contentRemoval: .progressive` masking a view to its layout rect while
  it is at rest, which clipped shadows, glows, and overflow for the view's
  whole life on screen.
- Keeps progressive smoke at the scale the cover reached instead of collapsing
  it in a single frame at the third pose swap.
- Keeps one playback seed across layout changes, so a resize no longer swaps
  the poof for a different one mid-animation.
- Prepares progressive playback off the main thread and roughly four times
  faster, so a list of rows no longer serializes on it.
- Fixes the media generator failing to resolve outside a directory named
  `poof`, which broke `make check` for release tarballs.

## 1.1.0 - 2026-07-31

### Breaking changes

- Removes the Drift style.

### Added

- Makes every style grayscale by default, with pastel and custom fill palettes
  available as opt-in choices.
- Adds opt-in smooth motion with persistent puff tracks, continuous paths, and
  staggered scale-only entry and exit.
- Adds shared palette, motion, surface, appearance, pose, and duration controls
  to the macOS demo.

### Changed

- Makes the second pose clearly smaller than the dense-puff pose in standalone
  and progressive playback.
- Keeps new progressive puffs attached to the prior smoke as they expand.

## 1.0.0 - 2026-07-30

Poof 1.0.0 brings a clean-room take on AppKit's former disappearing-item
effect to SwiftUI on OS 26 and later.

- Recreates the compact five-pose poof with original vector artwork.
- Adds the opt-in Bloom, Snap, and Drift styles.
- Supports progressive content removal that adapts to the source bounds.
- Chooses one coherent variation per playback, with fixed seeds for repeatable
  rendering.
- Responds to Reduce Motion, Reduce Transparency, and Increased Contrast.
- Includes a macOS demo with normal, slow, and pose-by-pose previews.
- Builds as a Swift 6.3 package for iOS, macOS, tvOS, watchOS, and visionOS.
