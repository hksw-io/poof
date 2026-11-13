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
  puffs, sparse wisps, then ringlets. Poses swap without interpolation at 15
  frames per second, and a playback lasts exactly one-third of a second.
- Keep `PoofSimulation` based on absolute normalized progress. Progress and the
  playback seed must fully determine the selected pose and its glyphs. Nothing
  integrates and nothing carries state between frames.
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
- Progressive removal consumes the source where smoke reaches it rather than
  hiding it behind opaque paint. Bites accumulate, so covered pixels carry
  forward by construction and a bite is never given back. The source is gone
  only once the dense pose covers its bounds.
- Settle path booleans where they are built. `Path.subtracting` is lazy and
  `applying` discards the cached solve, so a mask left unsettled re-runs the
  boolean on the main thread every frame. Take erosion steps through `CGPath`
  in the preparation task.
- Preserve the accessibility paths: Reduce Motion draws no spatial poses;
  Reduce Transparency removes the blurred shadow; Increased Contrast uses
  stronger outlines and detail marks.
- Keep Classic and Snap grayscale. Bloom may use stable pastel fills. Use the
  same palette in light and dark appearance, with dark outlines and neutral
  details.
- Draw Classic with puffs only. Every frame of the original is a bumpy
  multi-lobe puff; rings, curls, and flecks belong to Bloom and Snap. Size
  carries the dissipation.
- Fit the artwork to the canvas it is given. The originals run off their own
  tile; this recreation does not, so ink that reaches past the geometry is
  budgeted rather than assumed.
- Keep the drawing canvas hidden from accessibility and hit testing. A view
  being removed must not remain interactive or exposed to accessibility.
- Do not call private APIs, extract system artwork, copy system sounds, or add
  sound playback. Recreate only measured public behavior with original vector
  paths.

## Source map

- `Sources/Poof/PoofConfiguration.swift`: public density, reach, padding, and
  playback seed settings.
- `Sources/Poof/PoofStyle.swift`: public opt-in visual styles.
- `Sources/Poof/PoofPalette.swift`: public fill palettes.
- `Sources/Poof/PoofNoise.swift`: counter-based seeded noise shared by the
  simulation and the erosion.
- `Sources/Poof/PoofErosion.swift`: the cumulative bites progressive removal
  takes out of the source, stepped along the painted poses.
- `Sources/Poof/PoofSimulation.swift`: pose selection, seeded breakup
  descriptors, and glyph variation.
- `Sources/Poof/PoofEffect.swift`: vector paths, palette, and `Canvas`
  renderer.
- `Sources/Poof/PoofTransition.swift`: public transition, 15 fps timing, and
  bounded overscan layout.
- `Sources/PoofDemo`: interactive macOS sample.
- `Tests/PoofDemoTests`: demo playback-mode tests.
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
- `spreadWidensBreakup` is a known flaky exact-pixel test under parallel load.
  Rerun it in isolation before treating a failure as real.
- Test that changing `fieldScale` changes padding without scaling the artwork.
  Test seeded repeatability and coherent unseeded playback variation separately.
- Use Conventional Commits, such as `feat:`, `fix:`, `test:`, `docs:`, and
  `chore:`.
- Keep generated build output out of git.
- A minor release may contain a breaking change, marked **Breaking** in
  `CHANGELOG.md`, so consumers pin exact versions.
