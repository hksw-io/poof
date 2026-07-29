import SwiftUI

/// A removal-only transition inspired by AppKit's former poof effect.
///
/// The transition keeps insertion quiet. When Reduce Motion is enabled, it
/// replaces particle travel with a fade.
public struct PoofTransition: Sendable, Transition {
  private let configuration: PoofConfiguration

  /// Creates a poof transition.
  public init(configuration: PoofConfiguration = .standard) {
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
  /// A removal-only poof transition.
  public static func poof(
    _ configuration: PoofConfiguration = .standard
  ) -> Self {
    PoofTransition(configuration: configuration)
  }
}

extension Animation {
  /// The timing curve tuned for ``PoofTransition``.
  public static var poof: Animation {
    .easeOut(duration: 0.36)
  }
}

private struct AdaptivePoofModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reducesMotion
  @Environment(\.accessibilityReduceTransparency)
  private var reducesTransparency
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast

  let progress: Double
  let isRemoving: Bool
  let configuration: PoofConfiguration

  func body(content: Content) -> some View {
    content.modifier(
      PoofProgressModifier(
        progress: progress,
        configuration: configuration,
        palette: PoofPalette(
          colorScheme: colorScheme,
          contrast: colorSchemeContrast
        ),
        reducesMotion: reducesMotion,
        reducesTransparency: reducesTransparency,
        usesBlur: !reducesTransparency && colorSchemeContrast != .increased,
        isRemoving: isRemoving
      )
    )
  }
}

@Animatable
private struct PoofProgressModifier: ViewModifier {
  var progress: Double

  @AnimatableIgnored var configuration: PoofConfiguration
  @AnimatableIgnored var palette: PoofPalette
  @AnimatableIgnored var reducesMotion: Bool
  @AnimatableIgnored var reducesTransparency: Bool
  @AnimatableIgnored var usesBlur: Bool
  @AnimatableIgnored var isRemoving: Bool

  func body(content: Content) -> some View {
    content
      .allowsHitTesting(!isRemoving)
      .accessibilityHidden(isRemoving)
      .opacity(contentOpacity)
      .overlay {
        GeometryReader { geometry in
          let side = PoofLayout.fieldSide(
            for: geometry.size,
            fieldScale: configuration.fieldScale
          )

          PoofCanvas(
            progress: progress,
            configuration: configuration,
            palette: palette,
            reducesMotion: reducesMotion,
            reducesTransparency: reducesTransparency,
            usesBlur: usesBlur
          )
          .frame(width: side, height: side)
          .position(
            x: geometry.size.width / 2,
            y: geometry.size.height / 2
          )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
  }

  private var contentOpacity: Double {
    if reducesMotion {
      return 1 - min(max(progress, 0), 1)
    }

    return 1
      - PoofSimulation.smoothstep(
        edge0: 0,
        edge1: 0.16,
        value: progress
      )
  }
}

enum PoofLayout {
  static func fieldSide(
    for size: CGSize,
    fieldScale: Double
  ) -> CGFloat {
    let width = size.width.isFinite ? max(size.width, 0) : 0
    let height = size.height.isFinite ? max(size.height, 0) : 0
    let geometricMean = (width * height).squareRoot()
    let referenceDimension = min(max(geometricMean, 42), 160)
    return referenceDimension * CGFloat(fieldScale)
  }
}

struct PoofTransitionState: Equatable, Sendable {
  let progress: Double
  let isRemoving: Bool
}
