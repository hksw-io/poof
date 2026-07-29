import SwiftUI

/// A deterministic smoke field that can be scrubbed from zero to one.
///
/// Use this view when you need to position the effect yourself. For view
/// removal, ``PoofTransition`` supplies the usual SwiftUI transition API.
public struct PoofEffect: View {
  @Environment(\.accessibilityReduceMotion) private var reducesMotion
  @Environment(\.accessibilityReduceTransparency)
  private var reducesTransparency
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast

  private let progress: Double
  private let configuration: PoofConfiguration

  /// Creates a poof at the supplied progress.
  ///
  /// Values below zero render the first frame. Values above one render the
  /// last frame.
  public init(
    progress: Double,
    configuration: PoofConfiguration = .standard
  ) {
    self.progress = progress
    self.configuration = configuration
  }

  public var body: some View {
    PoofCanvas(
      progress: progress,
      configuration: configuration,
      palette: PoofPalette(
        colorScheme: colorScheme,
        contrast: colorSchemeContrast
      ),
      reducesMotion: reducesMotion,
      reducesTransparency: reducesTransparency,
      usesBlur: !reducesTransparency && colorSchemeContrast != .increased
    )
  }
}

@Animatable
struct PoofCanvas: View {
  var progress: Double

  @AnimatableIgnored var configuration: PoofConfiguration
  @AnimatableIgnored var palette: PoofPalette
  @AnimatableIgnored var reducesMotion: Bool
  @AnimatableIgnored var reducesTransparency: Bool
  @AnimatableIgnored var usesBlur: Bool

  var body: some View {
    Canvas(
      opaque: false,
      colorMode: .linear,
      rendersAsynchronously: false
    ) { context, size in
      guard !reducesMotion, size.width > 0, size.height > 0 else {
        return
      }

      let referenceDimension = min(size.width, size.height)
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      var smokeContext = context

      if usesBlur {
        smokeContext.addFilter(
          .blur(radius: max(0.55, referenceDimension * 0.006))
        )
      }

      for particle in configuration.particles {
        let state = PoofSimulation.state(
          for: particle,
          progress: progress,
          reducesTransparency: reducesTransparency
        )

        guard state.opacity > 0.001 else {
          continue
        }

        let width = size.width * state.width
        let height = size.height * state.height
        let rect = CGRect(
          x: center.x + size.width * state.x - width / 2,
          y: center.y + size.height * state.y - height / 2,
          width: width,
          height: height
        )
        var particleContext =
          particle.isMote || !usesBlur ? context : smokeContext
        particleContext.opacity = state.opacity
        particleContext.fill(
          Path(ellipseIn: rect),
          with: .color(palette.color(for: state.tone))
        )
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct PoofPalette: Sendable {
  let light: Color
  let middle: Color
  let dark: Color

  init(colorScheme: ColorScheme, contrast: ColorSchemeContrast) {
    let hasIncreasedContrast = contrast == .increased

    switch colorScheme {
    case .dark:
      light = Color(
        white: hasIncreasedContrast ? 1.00 : 0.94,
        opacity: 1
      )
      middle = Color(
        white: hasIncreasedContrast ? 0.76 : 0.68,
        opacity: 1
      )
      dark = Color(
        white: hasIncreasedContrast ? 0.43 : 0.36,
        opacity: 1
      )
    case .light:
      light = Color(
        white: hasIncreasedContrast ? 0.73 : 0.80,
        opacity: 1
      )
      middle = Color(
        white: hasIncreasedContrast ? 0.40 : 0.49,
        opacity: 1
      )
      dark = Color(
        white: hasIncreasedContrast ? 0.08 : 0.16,
        opacity: 1
      )
    @unknown default:
      light = Color(white: 0.80, opacity: 1)
      middle = Color(white: 0.49, opacity: 1)
      dark = Color(white: 0.16, opacity: 1)
    }
  }

  func color(for tone: PoofParticle.Tone) -> Color {
    switch tone {
    case .light:
      light
    case .middle:
      middle
    case .dark:
      dark
    }
  }
}
