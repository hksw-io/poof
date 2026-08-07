import SwiftUI

/// The part of a disappearing view the smoke has not eaten yet.
///
/// A poof used to hide its source rather than consume it: opaque puffs were
/// painted over the top, and the view was switched off underneath once they
/// covered it. The seam only held because the paint was forced fully opaque.
///
/// The erosion instead removes the source where smoke has arrived, so the view
/// is eaten away rather than covered up. Each pose contributes a set of bites,
/// and the bites accumulate: a hole stays open once opened, which is what makes
/// this read as damage rather than as a moving clip. It also makes the
/// carry-forward rule structural. The painted cover is allowed to lose a little
/// ground between poses, and a mask following the paint frame by frame would
/// expose pixels it had already covered.
///
/// Steps are resolved once per playback and stored in unit space, so drawing a
/// frame is a lookup and one transform, and a resize cannot invalidate them.
struct PoofSourceErosion: Equatable, Sendable {
  /// The painted puff overhangs its own bite by this much.
  ///
  /// Aligning the two exactly leaves the antialiased edge of the paint against
  /// the antialiased edge of the hole, and the two do not cancel: every puff
  /// picks up a hairline of background. Biting slightly inside the paint hides
  /// the seam and reads as smoke rolling over the edge of the hole.
  private static let biteScale = 0.92

  /// The visible region at each step, in the unit square.
  private let steps: [Path]

  /// The visible region of `rect` at this progress.
  func path(for progress: Double, in rect: CGRect) -> Path {
    guard !progress.isNaN, progress > 0 else {
      return Path(rect)
    }

    guard progress < 1, progress != .infinity else {
      return Path()
    }

    let index = min(
      Int(progress * Double(steps.count)),
      steps.count - 1
    )
    let step = steps[index]

    guard !step.isEmpty else {
      return Path()
    }

    return step.applying(
      CGAffineTransform(scaleX: rect.width, y: rect.height)
        .concatenating(
          CGAffineTransform(
            translationX: rect.minX,
            y: rect.minY
          )
        )
    )
  }

  /// Builds the erosion for one stepped playback.
  ///
  /// One step per pose. The stepped default holds a pose for a whole frame
  /// interval, so anything finer would be invisible, and the mask has to be
  /// constant across an interval for the hard-swap tests to mean anything.
  static func stepped(
    size: CGSize,
    frameSet: PoofFrameSet
  ) -> PoofSourceErosion? {
    guard
      size.width > 0,
      size.height > 0,
      size.width.isFinite,
      size.height.isFinite
    else {
      return nil
    }

    let rect = CGRect(origin: .zero, size: size)
    var eaten = Path()
    var steps: [Path] = []

    for pose in PoofPose.allCases {
      let elements = PoofArtwork.sourceCoverElements(
        for: pose,
        in: rect,
        frameSet: frameSet
      )

      // The dense pose is separately proven to tile the bounds, and every pose
      // after it draws no cover at all, so from there the source is simply
      // gone. Solving the union for those steps would only rediscover that.
      guard !elements.isEmpty, pose != .puffs else {
        steps.append(Path())
        continue
      }

      for element in elements {
        eaten.addPath(bite(for: element))
      }

      // Subtracting reads the accumulated bites under the non-zero rule, which
      // is their union. Even-odd would re-fill wherever two puffs overlap, and
      // the cover overlaps everywhere by design.
      let visible = Path(rect).subtracting(eaten, eoFill: false)

      steps.append(settled(normalized(visible, in: rect)))
    }

    return PoofSourceErosion(steps: steps)
  }

  /// The same region, with its boolean already solved.
  ///
  /// A `Path` boolean is lazy: `subtracting` only records the operation, and
  /// the solve runs when something first asks for a `CGPath`. Worse, the
  /// result is cached on the path that was asked, and ``path(for:in:)`` hands
  /// back a fresh `applying` copy every frame — so an unsettled step re-solves
  /// on the main thread for as long as it is on screen. Measured on a
  /// playback's worth of steps, that is seconds of main-thread time inside
  /// `NSHostingView.layout()`, enough to hang the window.
  ///
  /// Going through `CGPath` here runs the solve once, on whichever thread
  /// builds the erosion — which is off the main one by construction. It also
  /// settles `isEmpty`, which reads `false` on a lazily emptied path and is
  /// what ``path(for:in:)`` asks.
  private static func settled(_ path: Path) -> Path {
    Path(path.cgPath)
  }

  /// One puff's bite, held just inside the puff that paints over it.
  private static func bite(
    for element: PoofArtwork.SourceCoverElement
  ) -> Path {
    bite(path: element.path, center: element.center)
  }

  private static func bite(
    path: Path,
    center: CGPoint
  ) -> Path {
    path.applying(
      CGAffineTransform(
        translationX: -center.x,
        y: -center.y
      )
      .concatenating(
        CGAffineTransform(scaleX: biteScale, y: biteScale)
      )
      .concatenating(
        CGAffineTransform(
          translationX: center.x,
          y: center.y
        )
      )
    )
  }

  private static func normalized(
    _ path: Path,
    in rect: CGRect
  ) -> Path {
    path.applying(
      CGAffineTransform(
        translationX: -rect.minX,
        y: -rect.minY
      )
      .concatenating(
        CGAffineTransform(
          scaleX: 1 / rect.width,
          y: 1 / rect.height
        )
      )
    )
  }
}
