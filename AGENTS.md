# AGENTS.md

## Scope

This repository contains a Swift package named `Poof`, a small macOS demo, and
tests. Keep the library usable on iOS, macOS, tvOS, watchOS, and visionOS 26 or
later.

## Design rules

- Use Swift 6 language mode and strict concurrency-safe types.
- Use current SwiftUI APIs. Do not add deprecated AppKit animation APIs,
  private frameworks, UIKit effects, Core Animation emitters, or timers.
- Keep `PoofSimulation` deterministic and based on absolute normalized
  progress. The same configuration and progress must produce the same frame.
- Generate particle descriptors when a configuration is created. Do not add
  per-frame random generation, mutable global state, or one SwiftUI view per
  particle.
- Keep particle count capped at 64 and the transition field reference dimension
  capped at 160 points unless measurements and tests justify a change.
- Keep insertion quiet. The poof is a removal effect.
- Preserve the accessibility paths: Reduce Motion uses no spatial particle
  drawing; Reduce Transparency uses no blur; Increased Contrast uses the
  stronger palette and no blur.
- Keep the particle canvas hidden from accessibility and hit testing. A view
  being removed must not remain interactive or exposed to accessibility.
- Do not copy private system assets, sounds, or implementation details.

## Source map

- `Sources/Poof/PoofConfiguration.swift`: public settings and precomputed
  particle descriptors.
- `Sources/Poof/PoofSimulation.swift`: deterministic particle generation and
  frame math.
- `Sources/Poof/PoofEffect.swift`: adaptive palette and `Canvas` renderer.
- `Sources/Poof/PoofTransition.swift`: public transition, animation timing, and
  bounded layout.
- `Sources/PoofDemo`: interactive macOS sample.
- `Tests/PoofTests`: simulation, layout, rendering, and transition tests.

## Working agreement

- Run `make check` before committing.
- Use `make format` after editing Swift.
- Add documentation comments for public API changes.
- Add or update tests for behavior changes. Rendering changes need coverage for
  light and dark appearance, accessibility settings, endpoints, and more than
  one render scale when applicable.
- Use Conventional Commits, such as `feat:`, `fix:`, `test:`, `docs:`, and
  `chore:`.
- Keep generated build output out of git.
