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

  /// Creates a classic poof with immediate content removal.
  public init(configuration: PoofConfiguration = .standard) {
    style = .classic
    contentRemoval = .immediate
    self.configuration = configuration
  }

  /// Creates a styled poof with immediate content removal.
  public init(
    style: PoofStyle,
    configuration: PoofConfiguration = .standard
  ) {
    self.style = style
    contentRemoval = .immediate
    self.configuration = configuration
  }

  /// Creates a styled poof transition with a content-removal behavior.
  public init(
    style: PoofStyle = .classic,
    contentRemoval: PoofContentRemoval,
    configuration: PoofConfiguration = .standard
  ) {
    self.style = style
    self.contentRemoval = contentRemoval
    self.configuration = configuration
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
        configuration: configuration
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
    _ configuration: PoofConfiguration = .standard
  ) -> Self {
    PoofTransition(configuration: configuration)
  }

  /// A styled removal-only poof with immediate content removal.
  public static func poof(
    style: PoofStyle,
    configuration: PoofConfiguration = .standard
  ) -> Self {
    PoofTransition(style: style, configuration: configuration)
  }

  /// A styled removal-only poof transition with content removal.
  public static func poof(
    style: PoofStyle = .classic,
    contentRemoval: PoofContentRemoval,
    configuration: PoofConfiguration = .standard
  ) -> Self {
    PoofTransition(
      style: style,
      contentRemoval: contentRemoval,
      configuration: configuration
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

  let progress: Double
  let isRemoving: Bool
  let style: PoofStyle
  let contentRemoval: PoofContentRemoval
  let configuration: PoofConfiguration

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
        palette: PoofPalette(contrast: colorSchemeContrast),
        reducesMotion: reducesMotion,
        reducesTransparency: reducesTransparency,
        isRemoving: isRemoving,
        frameSet: frameSet
      )
    )
    .onChange(of: input, initial: true) { _, input in
      guard !input.coversSource || input.sourceCoverAspect != nil else {
        return
      }

      guard
        frameSet?.configuration != input.configuration
          || frameSet?.style != input.style
          || frameSet?.coversSource != input.coversSource
          || frameSet?.sourceCoverAspect != input.sourceCoverAspect
      else {
        return
      }

      frameSet = PoofPlayback.makeFrameSet(
        for: input.configuration,
        style: input.style,
        coversSource: input.coversSource,
        sourceCoverAspect: input.sourceCoverAspect
      )
    }
    .onGeometryChange(for: PoofSourceCoverAspect.self) { proxy in
      PoofSourceCoverAspect(size: proxy.size)
    } action: { newAspect in
      sourceCoverAspect = newAspect
    }
  }
}

@Animatable
private struct PoofProgressModifier: ViewModifier {
  var progress: Double

  @AnimatableIgnored var contentRemoval: PoofContentRemoval
  @AnimatableIgnored var configuration: PoofConfiguration
  @AnimatableIgnored var palette: PoofPalette
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
            progress: progress,
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
  let frameSet: PoofFrameSet?

  func path(in rect: CGRect) -> Path {
    guard progress.isNaN == false, progress > 0 else {
      return Path(rect)
    }

    guard progress < 1, progress != .infinity else {
      return Path()
    }

    guard
      frameSet != nil,
      let pose = PoofSimulation.pose(for: progress)
    else {
      // Keep the source present if the precomputed playback is not ready yet.
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
