# Poof

Poof brings AppKit’s retired disappearing-item animation to SwiftUI on OS 26
and later. A clean-room `Canvas` renderer draws grayscale vector artwork based
on the original effect’s visible behavior. It does not call the deprecated
`NSAnimationEffect` API or ship copied system assets.

The animation uses five hard-swapped poses at 15 frames per second: a full
scalloped cloud, four clustered puffs, a dense breakup, sparse wisps, and final
ringlets. One playback takes one-third of a second.

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
`withAnimation(.poof)` for the intended linear, one-third-second timing.

Customize the later breakup poses, their reach, and the surrounding drawing
room:

```swift
let configuration = PoofConfiguration(
  particleCount: 28,
  spread: 0.86,
  fieldScale: 2.2,
  seed: 42
)

content.transition(.poof(configuration))
```

Without a seed, Poof chooses a slight variation once per playback and carries
it coherently through all five poses. Pass an explicit seed when tests,
previews, or synchronized UI need repeatable artwork. `fieldScale` adds
transparent padding around the drawing; it never enlarges the poof itself.

For a manually controlled effect, scrub `PoofEffect` between zero and one.
Values at either endpoint draw nothing:

```swift
PoofEffect(progress: progress)
  .frame(width: 42, height: 42)
```

## Accessibility and appearance

- Reduce Motion skips the five spatial poses and fades the content.
- Reduce Transparency removes the soft shadow and keeps small shapes legible.
- Increased Contrast strengthens the outline and internal marks.
- The same white-fill, dark-outline artwork works in light and dark appearance.
- The drawing is hidden from accessibility and never takes pointer events.
- The removed view stops accepting input and leaves the accessibility tree as
  its transition starts.

Poof does not play a sound. An ancestor that clips its children can also clip
the drawing field; allow drawing outside that ancestor when the full cloud
should remain visible.

## Performance

Poof generates seeded glyph descriptors once at playback start. Every render
selects one pose from absolute progress and draws it in one `Canvas`; there is
no timer, per-frame random work, or SwiftUI view per glyph. Glyph count and
field size stay bounded.

## Demo and checks

Run the macOS demo:

```sh
make run
```

Run formatting checks, debug tests, and release tests:

```sh
make check
```
