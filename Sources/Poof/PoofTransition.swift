import SwiftUI

/// How the transitioning view disappears beneath the smoke.
public enum PoofContentRemoval: Hashable, Sendable {
  /// Hides the source as soon as the poof begins.
  case immediate

  /// Keeps the source intact until dense smoke fully covers it.
  case progressive
}

/// A removal-only transition inspired by AppKit's former poof effect.
///
/// The transition keeps insertion quiet. When Reduce Motion is enabled, it
/// replaces the smoke poses with a fade.
public struct PoofTransition: Sendable, Transition {
  private let style: PoofStyle
  private let contentRemoval: PoofContentRemoval
  private let configuration: PoofConfiguration
  private let palette: PoofPalette
  private let motion: PoofMotion

  /// Creates a classic poof with immediate content removal.
  ///
  /// - Parameters:
  ///   - configuration: The poof's density, spread, overscan, and seed.
  ///   - palette: Fill colors for the smoke.
  ///   - motion: Stepped or smoothly interpolated pose changes.
  public init(
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic,
    motion: PoofMotion = .stepped
  ) {
    style = .classic
    contentRemoval = .immediate
    self.configuration = configuration
    self.palette = palette
    self.motion = motion
  }

  /// Creates a styled poof with immediate content removal.
  ///
  /// - Parameters:
  ///   - style: The visual character of the poof.
  ///   - configuration: The poof's density, spread, overscan, and seed.
  ///   - palette: Fill colors for the smoke.
  ///   - motion: Stepped or smoothly interpolated pose changes.
  public init(
    style: PoofStyle,
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic,
    motion: PoofMotion = .stepped
  ) {
    self.style = style
    contentRemoval = .immediate
    self.configuration = configuration
    self.palette = palette
    self.motion = motion
  }

  /// Creates a styled poof transition with a content-removal behavior.
  ///
  /// - Parameters:
  ///   - style: The visual character of the poof.
  ///   - contentRemoval: When the transitioning view disappears.
  ///   - configuration: The poof's density, spread, overscan, and seed.
  ///   - palette: Fill colors for the smoke.
  ///   - motion: Stepped or smoothly interpolated pose changes.
  public init(
    style: PoofStyle = .classic,
    contentRemoval: PoofContentRemoval,
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic,
    motion: PoofMotion = .stepped
  ) {
    self.style = style
    self.contentRemoval = contentRemoval
    self.configuration = configuration
    self.palette = palette
    self.motion = motion
  }

  public func body(
    content: Content,
    phase: TransitionPhase
  ) -> some View {
    let state = Self.state(for: phase)

    content.modifier(
      AdaptivePoofModifier(
        progress: state.progress,
        isRemoving: state.isRemoving,
        style: style,
        contentRemoval: contentRemoval,
        configuration: configuration,
        palette: palette,
        motion: motion
      )
    )
  }

  static func state(for phase: TransitionPhase) -> PoofTransitionState {
    let isRemoving = phase == .didDisappear
    return PoofTransitionState(
      progress: isRemoving ? 1 : 0,
      isRemoving: isRemoving
    )
  }
}

extension Transition where Self == PoofTransition {
  /// A classic removal-only poof with immediate content removal.
  public static func poof(
    _ configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic,
    motion: PoofMotion = .stepped
  ) -> Self {
    PoofTransition(
      configuration: configuration,
      palette: palette,
      motion: motion
    )
  }

  /// A styled removal-only poof with immediate content removal.
  public static func poof(
    style: PoofStyle,
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic,
    motion: PoofMotion = .stepped
  ) -> Self {
    PoofTransition(
      style: style,
      configuration: configuration,
      palette: palette,
      motion: motion
    )
  }

  /// A styled removal-only poof transition with content removal.
  public static func poof(
    style: PoofStyle = .classic,
    contentRemoval: PoofContentRemoval,
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic,
    motion: PoofMotion = .stepped
  ) -> Self {
    PoofTransition(
      style: style,
      contentRemoval: contentRemoval,
      configuration: configuration,
      palette: palette,
      motion: motion
    )
  }
}

extension Animation {
  /// The timing curve tuned for ``PoofTransition``.
  public static var poof: Animation {
    .linear(duration: PoofSimulation.duration)
  }
}

private struct AdaptivePoofModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reducesMotion
  @Environment(\.accessibilityReduceTransparency)
  private var reducesTransparency
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast
  @State private var frameSet: PoofFrameSet? = nil
  @State private var sourceCoverAspect: PoofSourceCoverAspect? = nil
  @State private var playbackSeed: UInt64? = nil

  let progress: Double
  let isRemoving: Bool
  let style: PoofStyle
  let contentRemoval: PoofContentRemoval
  let configuration: PoofConfiguration
  let palette: PoofPalette
  let motion: PoofMotion

  func body(content: Content) -> some View {
    let coversSource =
      contentRemoval == .progressive
      && !reducesMotion
    let input = PoofPlaybackInput(
      style: style,
      configuration: configuration,
      coversSource: coversSource,
      sourceCoverAspect:
        coversSource
        ? sourceCoverAspect
        : nil
    )

    content.modifier(
      PoofProgressModifier(
        progress: progress,
        contentRemoval: contentRemoval,
        configuration: configuration,
        palette: PoofResolvedPalette(
          contrast: colorSchemeContrast,
          palette: palette,
          style: style
        ),
        motion: motion,
        reducesMotion: reducesMotion,
        reducesTransparency: reducesTransparency,
        isRemoving: isRemoving,
        frameSet: frameSet
      )
    )
    .onChange(of: input, initial: true) { _, input in
      // The uncovered layout is cheap, and PoofEffect and ImageRenderer need
      // it before the first draw, so it stays synchronous.
      guard !input.coversSource, needsFrameSet(for: input) else {
        return
      }

      frameSet = makeFrameSet(for: input)
    }
    .task(id: input) {
      // The covered layout solves for coverage over the laid-out bounds. It
      // runs at appearance rather than at removal, because deferring it to the
      // poof would stall the first animated frame, but it runs off the main
      // thread so a list of rows does not serialize on it.
      guard
        input.coversSource,
        input.sourceCoverAspect != nil,
        needsFrameSet(for: input)
      else {
        return
      }

      let seed = resolvedPlaybackSeed(for: input.configuration)
      playbackSeed = seed
      let prepared = await Task.detached(priority: .userInitiated) {
        PoofSimulation.makeFrameSet(
          configuration: input.configuration,
          style: input.style,
          coversSource: input.coversSource,
          sourceCoverAspect: input.sourceCoverAspect,
          variationSeed: seed
        )
      }.value

      guard !Task.isCancelled else {
        return
      }

      frameSet = prepared
    }
    .onGeometryChange(for: PoofSourceCoverAspect.self) { proxy in
      PoofSourceCoverAspect(size: proxy.size)
    } action: { newAspect in
      sourceCoverAspect = newAspect
    }
  }

  private func needsFrameSet(for input: PoofPlaybackInput) -> Bool {
    frameSet?.configuration != input.configuration
      || frameSet?.style != input.style
      || frameSet?.coversSource != input.coversSource
      || frameSet?.sourceCoverAspect != input.sourceCoverAspect
  }

  private func makeFrameSet(
    for input: PoofPlaybackInput
  ) -> PoofFrameSet {
    let seed = resolvedPlaybackSeed(for: input.configuration)
    playbackSeed = seed

    return PoofSimulation.makeFrameSet(
      configuration: input.configuration,
      style: input.style,
      coversSource: input.coversSource,
      sourceCoverAspect: input.sourceCoverAspect,
      variationSeed: seed
    )
  }

  private func resolvedPlaybackSeed(
    for configuration: PoofConfiguration
  ) -> UInt64 {
    PoofPlaybackSeed.resolve(
      configuration: configuration,
      cached: playbackSeed
    )
  }
}

enum PoofPlaybackSeed {
  /// The seed one playback keeps for its whole life.
  ///
  /// A rebuild triggered by a resize must not re-roll the variation, or the
  /// poof silently becomes a different poof between one frame and the next.
  static func resolve(
    configuration: PoofConfiguration,
    cached: UInt64?,
    randomSeed: () -> UInt64 = { UInt64.random(in: 1...UInt64.max) }
  ) -> UInt64 {
    configuration.seed ?? cached ?? randomSeed()
  }
}

@Animatable
private struct PoofProgressModifier: ViewModifier {
  var progress: Double

  @AnimatableIgnored var contentRemoval: PoofContentRemoval
  @AnimatableIgnored var configuration: PoofConfiguration
  @AnimatableIgnored var palette: PoofResolvedPalette
  @AnimatableIgnored var motion: PoofMotion
  @AnimatableIgnored var reducesMotion: Bool
  @AnimatableIgnored var reducesTransparency: Bool
  @AnimatableIgnored var isRemoving: Bool
  @AnimatableIgnored var frameSet: PoofFrameSet?

  func body(content: Content) -> some View {
    content
      .modifier(
        PoofContentRemovalModifier(
          progress: progress,
          contentRemoval: contentRemoval,
          motion: motion,
          reducesMotion: reducesMotion,
          frameSet: frameSet
        )
      )
      .allowsHitTesting(!isRemoving)
      .accessibilityHidden(isRemoving)
      .overlay {
        GeometryReader { geometry in
          let artSide = PoofLayout.artSide(for: geometry.size)
          let canvasSize = PoofLayout.canvasSize(
            for: geometry.size,
            fieldScale: configuration.fieldScale,
            coversSource: contentRemoval == .progressive
          )

          PoofCanvas(
            progress: PoofSimulation.drawnProgress(
              for: progress,
              motion: motion
            ),
            palette: palette,
            motion: motion,
            reducesMotion: reducesMotion,
            reducesTransparency: reducesTransparency,
            artScale: configuration.fieldScale,
            frameSet: frameSet,
            occludesSource: contentRemoval == .progressive,
            referenceArtSide: artSide,
            sourceSize: geometry.size
          )
          .frame(width: canvasSize.width, height: canvasSize.height)
          .position(
            x: geometry.size.width / 2,
            y: geometry.size.height / 2
          )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
  }
}

struct PoofContentRemovalModifier: ViewModifier {
  let progress: Double
  let contentRemoval: PoofContentRemoval
  let motion: PoofMotion
  let reducesMotion: Bool
  let frameSet: PoofFrameSet?

  @ViewBuilder
  func body(content: Content) -> some View {
    let opacity = PoofContentVisibility.opacity(
      progress: progress,
      contentRemoval: contentRemoval,
      reducesMotion: reducesMotion
    )

    if contentRemoval == .progressive {
      let maskProgress = reducesMotion ? 0 : progress
      let resolvedOpacity =
        frameSet == nil && !reducesMotion
        ? 1
        : opacity

      content
        .mask {
          PoofSourceMask(
            progress: maskProgress,
            motion: motion,
            frameSet: frameSet
          )
          .fill(.black)
          .opacity(resolvedOpacity)
          .transaction { transaction in
            guard !reducesMotion else {
              return
            }

            PoofSourceRemoval.snap(&transaction)
          }
          .allowsHitTesting(false)
          .accessibilityHidden(true)
        }
    } else {
      content
        .opacity(opacity)
    }
  }
}

struct PoofSourceMask: Shape {
  let progress: Double
  let motion: PoofMotion
  let frameSet: PoofFrameSet?

  func path(in rect: CGRect) -> Path {
    guard progress.isNaN == false, progress > 0 else {
      return Path(rect)
    }

    guard progress < 1, progress != .infinity else {
      return Path()
    }

    guard
      frameSet != nil
    else {
      // Keep the source present if the precomputed playback is not ready yet.
      return Path(rect)
    }

    if motion == .smooth {
      return progress < 0.5 ? Path(rect) : Path()
    }

    guard let pose = PoofSimulation.pose(for: progress) else {
      return Path(rect)
    }

    return PoofArtwork.sourceMaskPath(
      for: pose,
      in: rect
    )
  }
}

enum PoofSourceRemoval {
  static func snap(_ transaction: inout Transaction) {
    transaction.animation = nil
    transaction.disablesAnimations = true
  }
}

enum PoofContentVisibility {
  static func opacity(
    progress: Double,
    contentRemoval: PoofContentRemoval,
    reducesMotion: Bool
  ) -> Double {
    let progress =
      if progress.isNaN || progress == -.infinity {
        0.0
      } else if progress == .infinity {
        1.0
      } else {
        min(max(progress, 0), 1)
      }

    if reducesMotion {
      return 1 - progress
    }

    switch contentRemoval {
    case .immediate:
      return progress > 0 ? 0 : 1
    case .progressive:
      // Spatial removal belongs to PoofSourceMask. Keeping the source opaque
      // avoids a whole-surface fade where smoke has not reached.
      return progress < 1 ? 1 : 0
    }
  }
}

enum PoofLayout {
  private static let sourceCoverMarginRatio = 0.25

  static func artSide(for size: CGSize) -> CGFloat {
    let width = size.width.isFinite ? max(size.width, 0) : 0
    let height = size.height.isFinite ? max(size.height, 0) : 0
    let geometricMean = (width * height).squareRoot()
    return min(max(geometricMean, 42), 160)
  }

  static func fieldSide(
    for size: CGSize,
    fieldScale: Double
  ) -> CGFloat {
    artSide(for: size) * CGFloat(fieldScale)
  }

  static func canvasSize(
    for size: CGSize,
    fieldScale: Double,
    coversSource: Bool
  ) -> CGSize {
    let fieldSide = fieldSide(for: size, fieldScale: fieldScale)

    guard coversSource else {
      return CGSize(width: fieldSide, height: fieldSide)
    }

    let width = size.width.isFinite ? max(size.width, 0) : 0
    let height = size.height.isFinite ? max(size.height, 0) : 0
    let margin = artSide(for: size) * sourceCoverMarginRatio

    return CGSize(
      width: max(fieldSide, width + margin * 2),
      height: max(fieldSide, height + margin * 2)
    )
  }
}

struct PoofTransitionState: Equatable, Sendable {
  let progress: Double
  let isRemoving: Bool
}
