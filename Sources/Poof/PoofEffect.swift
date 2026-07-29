import SwiftUI

/// A five-pose smoke effect that can be scrubbed from zero to one.
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
  /// Values at or below zero render no smoke. Values at or above one render
  /// no smoke after the fifth pose.
  public init(
    progress: Double,
    configuration: PoofConfiguration = .standard
  ) {
    self.progress = progress
    self.configuration = configuration
  }

  public var body: some View {
    PoofPlayback(
      progress: progress,
      configuration: configuration,
      palette: PoofPalette(
        colorScheme: colorScheme,
        contrast: colorSchemeContrast
      ),
      reducesMotion: reducesMotion,
      reducesTransparency: reducesTransparency,
      artScale: 1
    )
  }
}

struct PoofPlayback: View {
  @State private var frameSet: PoofFrameSet? = nil

  let progress: Double
  let configuration: PoofConfiguration
  let palette: PoofPalette
  let reducesMotion: Bool
  let reducesTransparency: Bool
  let artScale: Double

  var body: some View {
    PoofCanvas(
      progress: progress,
      palette: palette,
      reducesMotion: reducesMotion,
      reducesTransparency: reducesTransparency,
      artScale: artScale,
      frameSet: frameSet
    )
    .onAppear {
      guard frameSet?.configuration != configuration else {
        return
      }

      frameSet = makeFrameSet(for: configuration)
    }
    .onChange(of: configuration) { _, newConfiguration in
      frameSet = makeFrameSet(for: newConfiguration)
    }
  }

  private func makeFrameSet(
    for configuration: PoofConfiguration
  ) -> PoofFrameSet {
    PoofSimulation.makeFrameSet(
      configuration: configuration,
      variationSeed: configuration.seed
        ?? UInt64.random(in: 1...UInt64.max)
    )
  }
}

@Animatable
struct PoofCanvas: View {
  var progress: Double

  @AnimatableIgnored var palette: PoofPalette
  @AnimatableIgnored var reducesMotion: Bool
  @AnimatableIgnored var reducesTransparency: Bool
  @AnimatableIgnored var artScale: Double
  @AnimatableIgnored var frameSet: PoofFrameSet?

  var body: some View {
    Canvas(
      opaque: false,
      colorMode: .nonLinear,
      rendersAsynchronously: false
    ) { context, size in
      guard
        !reducesMotion,
        size.width > 0,
        size.height > 0,
        let frameSet,
        let pose = PoofSimulation.pose(for: progress)
      else {
        return
      }

      let scale =
        artScale.isFinite
        ? max(artScale, 1)
        : 1
      let artSide = min(size.width, size.height) / scale
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let outlineWidth = max(0.5, artSide * 0.014)
      let detailWidth = max(0.4, artSide * 0.011)
      let glyphs = frameSet.glyphs(for: pose)
      var shadowContext = context

      if !reducesTransparency {
        shadowContext.addFilter(
          .blur(radius: max(0.35, artSide * 0.017))
        )
      }

      for (index, glyph) in glyphs.enumerated() {
        let opacity =
          reducesTransparency
          ? max(glyph.opacity, 0.88)
          : glyph.opacity
        let path = scallopedPath(
          for: glyph,
          center: center,
          artSide: artSide
        )

        if !reducesTransparency {
          var glyphShadowContext = shadowContext
          glyphShadowContext.opacity = opacity
          glyphShadowContext.fill(
            path.applying(
              CGAffineTransform(
                translationX: 0,
                y: artSide * 0.018
              )
            ),
            with: .color(palette.shadow)
          )
        }

        var glyphContext = context
        glyphContext.opacity = opacity
        if pose == .ringlets, index.isMultiple(of: 3) {
          glyphContext.stroke(
            path,
            with: .color(palette.outline),
            lineWidth: outlineWidth * 1.65
          )
          glyphContext.stroke(
            path,
            with: .color(palette.fill(for: glyph.tone)),
            lineWidth: outlineWidth * 0.72
          )
        } else {
          glyphContext.fill(
            path,
            with: .color(palette.fill(for: glyph.tone))
          )
          glyphContext.stroke(
            path,
            with: .color(palette.outline),
            lineWidth: outlineWidth
          )
        }

        if pose == .clusters {
          glyphContext.stroke(
            puffDetailPath(
              for: glyph,
              center: center,
              artSide: artSide
            ),
            with: .color(palette.detail),
            lineWidth: detailWidth
          )
        } else if pose == .cloud, index == glyphs.count - 1 {
          glyphContext.stroke(
            cloudDetailPath(center: center, artSide: artSide),
            with: .color(palette.detail),
            lineWidth: detailWidth
          )
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func scallopedPath(
    for glyph: PoofGlyph,
    center: CGPoint,
    artSide: Double
  ) -> Path {
    let sampleCount = max(glyph.lobeCount * 8, 24)
    let glyphCenter = CGPoint(
      x: center.x + artSide * glyph.x,
      y: center.y + artSide * glyph.y
    )
    var points: [CGPoint] = []
    points.reserveCapacity(sampleCount)

    for sample in 0..<sampleCount {
      let angle =
        Double(sample) / Double(sampleCount)
        * 2 * Double.pi
      let lobeAmplitude =
        glyph.lobeCount <= 6
        ? 0.06
        : 0.045
      let radius =
        0.48
        + lobeAmplitude
        * cos(Double(glyph.lobeCount) * angle + glyph.phase)
        + 0.012 * cos(3 * angle - 0.4)
      points.append(
        CGPoint(
          x: glyphCenter.x
            + artSide * glyph.width * radius * cos(angle),
          y: glyphCenter.y
            + artSide * glyph.height * radius * sin(angle)
        )
      )
    }

    guard let first = points.first, let last = points.last else {
      return Path()
    }

    var path = Path()
    path.move(
      to: CGPoint(
        x: (last.x + first.x) / 2,
        y: (last.y + first.y) / 2
      )
    )

    for index in points.indices {
      let point = points[index]
      let next = points[(index + 1) % points.count]
      path.addQuadCurve(
        to: CGPoint(
          x: (point.x + next.x) / 2,
          y: (point.y + next.y) / 2
        ),
        control: point
      )
    }

    path.closeSubpath()
    return path
  }

  private func puffDetailPath(
    for glyph: PoofGlyph,
    center: CGPoint,
    artSide: Double
  ) -> Path {
    let glyphCenter = CGPoint(
      x: center.x + artSide * glyph.x,
      y: center.y + artSide * glyph.y
    )
    let width = artSide * glyph.width
    let height = artSide * glyph.height
    var path = Path()
    path.move(
      to: CGPoint(
        x: glyphCenter.x - width * 0.22,
        y: glyphCenter.y
      )
    )
    path.addQuadCurve(
      to: CGPoint(
        x: glyphCenter.x,
        y: glyphCenter.y - height * 0.025
      ),
      control: CGPoint(
        x: glyphCenter.x - width * 0.11,
        y: glyphCenter.y - height * 0.19
      )
    )
    path.addQuadCurve(
      to: CGPoint(
        x: glyphCenter.x + width * 0.22,
        y: glyphCenter.y
      ),
      control: CGPoint(
        x: glyphCenter.x + width * 0.11,
        y: glyphCenter.y - height * 0.19
      )
    )
    return path
  }

  private func cloudDetailPath(
    center: CGPoint,
    artSide: Double
  ) -> Path {
    var path = Path()
    path.move(
      to: CGPoint(
        x: center.x - artSide * 0.22,
        y: center.y - artSide * 0.03
      )
    )
    path.addQuadCurve(
      to: CGPoint(
        x: center.x - artSide * 0.075,
        y: center.y - artSide * 0.055
      ),
      control: CGPoint(
        x: center.x - artSide * 0.15,
        y: center.y - artSide * 0.14
      )
    )
    path.addQuadCurve(
      to: CGPoint(
        x: center.x + artSide * 0.075,
        y: center.y - artSide * 0.055
      ),
      control: CGPoint(
        x: center.x,
        y: center.y - artSide * 0.15
      )
    )
    path.addQuadCurve(
      to: CGPoint(
        x: center.x + artSide * 0.22,
        y: center.y - artSide * 0.03
      ),
      control: CGPoint(
        x: center.x + artSide * 0.15,
        y: center.y - artSide * 0.14
      )
    )
    return path
  }
}

struct PoofPalette: Sendable {
  let light: Color
  let middle: Color
  let dark: Color
  let outline: Color
  let detail: Color
  let shadow: Color

  init(
    colorScheme _: ColorScheme,
    contrast: ColorSchemeContrast
  ) {
    let hasIncreasedContrast = contrast == .increased

    light = Color(white: 1, opacity: 1)
    middle = Color(white: 0.95, opacity: 1)
    dark = Color(white: 0.86, opacity: 1)
    outline = Color(
      white: 0,
      opacity: hasIncreasedContrast ? 0.62 : 0.42
    )
    detail = Color(
      white: 0,
      opacity: hasIncreasedContrast ? 0.50 : 0.32
    )
    shadow = Color(
      white: 0,
      opacity: hasIncreasedContrast ? 0.30 : 0.22
    )
  }

  func fill(for tone: PoofTone) -> Color {
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
