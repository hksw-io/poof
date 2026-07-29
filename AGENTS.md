# AGENTS.md

## Scope

This repository contains a Swift package named `Poof`, a small macOS demo, and
tests. Keep the library usable on iOS, macOS, tvOS, watchOS, and visionOS 26 or
later.

## Design rules

- Require Swift 6.3 or later, use Swift 6 language mode, and keep types
  strict-concurrency safe.
- Use current SwiftUI APIs. Do not add deprecated AppKit animation APIs,
  private frameworks, UIKit effects, Core Animation emitters, or timers.
- Preserve the clean-room five-pose sequence: full cloud, four clusters, dense
  puffs, sparse wisps, then ringlets. Swap poses without interpolation at 15
  frames per second; one playback lasts exactly one-third of a second.
- Keep `PoofSimulation` based on absolute normalized progress. Progress and the
  playback seed must fully determine the selected pose and its glyphs.
- Choose optional variation once per playback and apply it coherently to every
  pose. An explicit seed must produce repeatable output. Do not add per-frame
  random generation, `hashValue` seeds, or mutable global state.
- Generate breakup descriptors outside frame drawing. Keep glyph count capped
  at 64 and use one `Canvas`, not one SwiftUI view per glyph.
- Treat `fieldScale` as transparent overscan only. It must not change glyph
  positions, dimensions, line widths, or shadow size. Keep the transition
  reference dimension capped at 160 points unless measurements and tests
  justify a change.
- Keep insertion quiet. The poof is a removal effect.
- Preserve the accessibility paths: Reduce Motion draws no spatial poses;
  Reduce Transparency removes the blurred shadow; Increased Contrast uses
  stronger outlines and detail marks.
- Use the same grayscale artwork in light and dark appearance: white fills,
  dark outlines, and neutral details.
- Keep the drawing canvas hidden from accessibility and hit testing. A view
  being removed must not remain interactive or exposed to accessibility.
- Do not call private APIs, extract system artwork, copy system sounds, or add
  sound playback. Recreate only measured public behavior with original vector
  paths.

## Source map

- `Sources/Poof/PoofConfiguration.swift`: public density, reach, padding, and
  playback seed settings.
- `Sources/Poof/PoofSimulation.swift`: pose selection, seeded breakup
  descriptors, and glyph variation.
- `Sources/Poof/PoofEffect.swift`: grayscale vector paths and `Canvas`
  renderer.
- `Sources/Poof/PoofTransition.swift`: public transition, 15 fps timing, and
  bounded overscan layout.
- `Sources/PoofDemo`: interactive macOS sample.
- `Tests/PoofTests`: simulation, layout, rendering, and transition tests.
- `Tools/PoofMediaGenerator`: third-party-free generator for the assets in
  `Documentation/Media`, including its own pixel-stability tests.

## Working agreement

- Run `make check` before committing.
- Use `make format` after editing Swift.
- Run `make media` after changing the renderer or README media. The generator
  must render the public `PoofEffect` API with a fixed seed.
- Add documentation comments for public API changes.
- Add or update tests for behavior changes. Rendering changes need coverage for
  all five pose boundaries, hard swaps, light and dark appearance,
  accessibility settings, endpoints, and more than one render scale.
- Test that changing `fieldScale` changes padding without scaling the artwork.
  Test seeded repeatability and coherent unseeded playback variation separately.
- Use Conventional Commits, such as `feat:`, `fix:`, `test:`, `docs:`, and
  `chore:`.
- Keep generated build output out of git.
