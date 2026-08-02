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

  /// Creates a classic poof with immediate content removal.
  ///
  /// - Parameters:
  ///   - configuration: The poof's density, spread, overscan, and seed.
  ///   - palette: Fill colors for the smoke.
  public init(
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic
  ) {
    style = .classic
    contentRemoval = .immediate
    self.configuration = configuration
    self.palette = palette
  }

  /// Creates a styled poof with immediate content removal.
  ///
  /// - Parameters:
  ///   - style: The visual character of the poof.
  ///   - configuration: The poof's density, spread, overscan, and seed.
  ///   - palette: Fill colors for the smoke.
  public init(
    style: PoofStyle,
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic
  ) {
    self.style = style
    contentRemoval = .immediate
    self.configuration = configuration
    self.palette = palette
  }

  /// Creates a styled poof transition with a content-removal behavior.
  ///
  /// - Parameters:
  ///   - style: The visual character of the poof.
  ///   - contentRemoval: When the transitioning view disappears.
  ///   - configuration: The poof's density, spread, overscan, and seed.
  ///   - palette: Fill colors for the smoke.
  public init(
    style: PoofStyle = .classic,
    contentRemoval: PoofContentRemoval,
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic
  ) {
    self.style = style
    self.contentRemoval = contentRemoval
    self.configuration = configuration
    self.palette = palette
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
        palette: palette
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
    palette: PoofPalette = .automatic
  ) -> Self {
    PoofTransition(
      configuration: configuration,
      palette: palette
    )
  }

  /// A styled removal-only poof with immediate content removal.
  public static func poof(
    style: PoofStyle,
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic
  ) -> Self {
    PoofTransition(
      style: style,
      configuration: configuration,
      palette: palette
    )
  }

  /// A styled removal-only poof transition with content removal.
  public static func poof(
    style: PoofStyle = .classic,
    contentRemoval: PoofContentRemoval,
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic
  ) -> Self {
    PoofTransition(
      style: style,
      contentRemoval: contentRemoval,
      configuration: configuration,
      palette: palette
    )
  }
}

extension Animation {
  /// The timing curve tuned for ``PoofTransition``.
  ///
  /// This is the sequence's own clock: five poses at fifteen frames a second,
  /// one third of a second in total.
  public static var poof: Animation {
    .linear(duration: PoofSimulation.duration)
  }

  /// The poof timing curve over an explicit duration.
  ///
  /// The duration is clamped to `0.15...1.5` seconds.
  public static func poof(duration: Double) -> Animation {
    .linear(
      duration: duration.isFinite
        ? min(max(duration, 0.15), 1.5)
        : PoofSimulation.duration
    )
  }
}

private struct AdaptivePoofModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reducesMotion
  @Environment(\.accessibilityReduceTransparency)
  private var reducesTransparency
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast
  @State private var frameSet: PoofFrameSet? = nil
  @State private var sourceSize: CGSize? = nil
  @State private var erosion: PoofSourceErosion? = nil
  @State private var preparedInput: PoofPreparationInput? = nil
  @State private var playbackSeed: UInt64? = nil

  let progress: Double
  let isRemoving: Bool
  let style: PoofStyle
  let contentRemoval: PoofContentRemoval
  let configuration: PoofConfiguration
  let palette: PoofPalette

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
        ? sourceSize.map(PoofSourceCoverAspect.init(size:))
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
        reducesMotion: reducesMotion,
        reducesTransparency: reducesTransparency,
        isRemoving: isRemoving,
        frameSet: frameSet,
        erosion: erosion
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
    .task(
      id: PoofPreparationInput(
        playback: input,
        sourceSize: sourceSize
      )
    ) {
      // The covered layout solves for coverage over the laid-out bounds, and
      // the erosion solves what the smoke eats out of them. Both run at
      // appearance rather than at removal, because deferring them to the poof
      // would stall its first frame, and both run off the main thread so a
      // list of rows does not serialize on them.
      let preparation = PoofPreparationInput(
        playback: input,
        sourceSize: sourceSize
      )

      guard
        input.coversSource,
        input.sourceCoverAspect != nil,
        let size = sourceSize,
        preparedInput != preparation
      else {
        return
      }

      let seed = resolvedPlaybackSeed(for: input.configuration)
      playbackSeed = seed
      preparedInput = preparation
      let prepared = await Task.detached(priority: .userInitiated) {
        let frameSet = PoofSimulation.makeFrameSet(
          configuration: input.configuration,
          style: input.style,
          coversSource: input.coversSource,
          sourceCoverAspect: input.sourceCoverAspect,
          variationSeed: seed
        )
        // The erosion bites along the painted poses. Solving it here settles
        // its path booleans on this thread rather than on the main one.
        let erosion = PoofSourceErosion.stepped(
          size: size,
          frameSet: frameSet
        )

        return (frameSet, erosion)
      }.value

      guard !Task.isCancelled else {
        return
      }

      frameSet = prepared.0
      erosion = prepared.1
    }
    .onGeometryChange(for: CGSize.self) { proxy in
      proxy.size
    } action: { newSize in
      sourceSize = newSize
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

/// Everything a covered playback is prepared against.
///
/// The erosion is solved for exact bounds rather than an aspect class, so a
/// resize inside one class still has to rebuild it.
struct PoofPreparationInput: Equatable, Sendable {
  let playback: PoofPlaybackInput
  let sourceSize: CGSize?
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
  @AnimatableIgnored var reducesMotion: Bool
  @AnimatableIgnored var reducesTransparency: Bool
  @AnimatableIgnored var isRemoving: Bool
  @AnimatableIgnored var frameSet: PoofFrameSet?
  @AnimatableIgnored var erosion: PoofSourceErosion?

  func body(content: Content) -> some View {
    content
      .modifier(
        PoofContentRemovalModifier(
          progress: progress,
          contentRemoval: contentRemoval,
          reducesMotion: reducesMotion,
          frameSet: frameSet,
          erosion: erosion
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
            progress: PoofSimulation.drawnProgress(for: progress),
            palette: palette,
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
  let reducesMotion: Bool
  let frameSet: PoofFrameSet?
  var erosion: PoofSourceErosion? = nil

  @ViewBuilder
  func body(content: Content) -> some View {
    let opacity = PoofContentVisibility.opacity(
      progress: progress,
      contentRemoval: contentRemoval,
      reducesMotion: reducesMotion
    )

    if contentRemoval == .progressive,
      PoofSourceRemoval.isActive(progress: progress)
    {
      let maskProgress = reducesMotion ? 0 : progress
      let resolvedOpacity =
        frameSet == nil && !reducesMotion
        ? 1
        : opacity

      content
        .mask {
          PoofSourceMask(
            progress: maskProgress,
            erosion: frameSet == nil ? nil : erosion
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
    } else if contentRemoval == .progressive {
      // At rest the mask would clip the view to its layout rect for as long as
      // it is on screen, taking shadows, glows, and any overflow with it.
      // SwiftUI evaluates a transition's body in the identity phase, so this
      // is every view that merely carries the transition.
      content
    } else {
      content
        .opacity(opacity)
    }
  }
}

struct PoofSourceMask: Shape {
  let progress: Double
  let erosion: PoofSourceErosion?

  func path(in rect: CGRect) -> Path {
    guard progress.isNaN == false, progress > 0 else {
      return Path(rect)
    }

    guard progress < 1, progress != .infinity else {
      return Path()
    }

    guard let erosion else {
      // Keep the source present if the precomputed playback is not ready yet.
      return Path(rect)
    }

    return erosion.path(for: progress, in: rect)
  }
}

enum PoofSourceRemoval {
  static func snap(_ transaction: inout Transaction) {
    transaction.animation = nil
    transaction.disablesAnimations = true
  }

  /// Whether a removal is under way at this progress.
  ///
  /// Every non-removal transition phase reports zero, so this is what
  /// separates a view that is disappearing from one that merely carries the
  /// transition.
  static func isActive(progress: Double) -> Bool {
    guard !progress.isNaN, progress != -.infinity else {
      return false
    }

    return progress > 0
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
