# Changelog

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
