# Poof

Poof recreates AppKit’s retired disappearing-item animation as a native
SwiftUI transition for OS 26 and later. It is written in Swift 6, uses a
deterministic `Canvas` particle field, and has no dependency on the deprecated
`NSAnimationEffect` API.

## Requirements

- Xcode 26 or later
- Swift 6.3 or later
- iOS, macOS, tvOS, watchOS, or visionOS 26 or later

## Add the package

Add this internal repository to a Swift package:

```swift
.package(
  url: "https://github.com/hksw-io/poof.git",
  branch: "main"
)
```

Then add `Poof` to the target’s dependencies and import it where needed.

## Use the transition

```swift
import Poof
import SwiftUI

struct ExampleView: View {
  @State private var isVisible = true

  var body: some View {
    VStack {
      if isVisible {
        Image(systemName: "shippingbox.fill")
          .font(.largeTitle)
          .transition(.poof())
      }

      Button("Remove") {
        withAnimation(.poof) {
          isVisible = false
        }
      }
    }
  }
}
```

The transition affects removal only, so inserting the view again does not play
the effect backward. The animation curve is separate from the transition; use
`withAnimation(.poof)` for the intended 0.36-second timing.

Customize density, spread, field size, or the deterministic seed:

```swift
let configuration = PoofConfiguration(
  particleCount: 32,
  spread: 0.9,
  fieldScale: 2.2,
  seed: 42
)

content.transition(.poof(configuration))
```

For a manually controlled effect, scrub `PoofEffect` between zero and one:

```swift
PoofEffect(progress: progress)
  .frame(width: 42, height: 42)
```

## Accessibility and appearance

- Reduce Motion replaces particle travel with a short content fade.
- Reduce Transparency removes blur and keeps particles denser and more opaque.
- Increased Contrast uses stronger neutral values and disables blur.
- Light and dark appearances use separate grayscale palettes.
- The drawing is hidden from accessibility and never takes pointer events.
- The removed view stops accepting input and leaves the accessibility tree as
  its transition starts.

Poof does not add sound. An ancestor that clips its children can also clip the
particle field; allow drawing outside that ancestor when the full cloud should
remain visible.

## Performance

Particle descriptors are generated once for each configuration. Animation
frames use absolute progress and draw in one `Canvas` pass, with no timer,
per-frame random generation, or view per particle. Particle and field sizes are
bounded.

## Demo and checks

Run the macOS demo:

```sh
swift run PoofDemo
```

Run formatting checks, debug tests, and release tests:

```sh
make check
```
