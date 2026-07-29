import SwiftUI

/// A five-pose smoke effect that can be scrubbed from zero to one.
///
/// Use this view when you need to position the effect yourself. For view
/// removal, ``PoofTransition`` supplies the usual SwiftUI transition API.
public struct PoofEffect: View {
  @Environment(\.accessibilityReduceMotion) private var reducesMotion
  @Environment(\.accessibilityReduceTransparency)
  private var reducesTransparency
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
      palette: PoofPalette(contrast: colorSchemeContrast),
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
    .onChange(of: configuration, initial: true) { _, configuration in
      guard frameSet?.configuration != configuration else {
        return
      }

      // Cache every pose together so one seed governs the whole playback and
      // the Canvas never generates random values while drawing.
      frameSet = Self.makeFrameSet(for: configuration)
    }
  }

  static func makeFrameSet(
    for configuration: PoofConfiguration,
    randomSeed: () -> UInt64 = {
      UInt64.random(in: 1...UInt64.max)
    }
  ) -> PoofFrameSet {
    PoofSimulation.makeFrameSet(
      configuration: configuration,
      variationSeed: configuration.seed
        ?? randomSeed()
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
        let path = contourPath(
          for: glyph,
          center: center,
          artSide: artSide
        )

        if !reducesTransparency {
          var glyphShadowContext = shadowContext
          glyphShadowContext.opacity = opacity
          let shadowPath = path.applying(
            CGAffineTransform(
              translationX: 0,
              y: artSide * 0.018
            )
          )

          if glyph.paint == .doubleStroke {
            glyphShadowContext.stroke(
              shadowPath,
              with: .color(palette.shadow),
              style: StrokeStyle(
                lineWidth: outlineWidth * 2.15,
                lineCap: .round,
                lineJoin: .round
              )
            )
          } else {
            glyphShadowContext.fill(
              shadowPath,
              with: .color(palette.shadow)
            )
          }
        }

        var glyphContext = context
        glyphContext.opacity = opacity
        switch glyph.paint {
        case .fillAndOutline, .fillOutlineAndInset:
          glyphContext.fill(
            path,
            with: .color(palette.fill(for: glyph.tone))
          )
          glyphContext.stroke(
            path,
            with: .color(palette.outline),
            lineWidth: outlineWidth
          )

          if glyph.paint == .fillOutlineAndInset {
            glyphContext.stroke(
              contourPath(
                for: glyph,
                center: center,
                artSide: artSide,
                scale: 0.46
              ),
              with: .color(palette.detail),
              style: StrokeStyle(
                lineWidth: detailWidth,
                lineCap: .round,
                lineJoin: .round
              )
            )
          }
        case .doubleStroke:
          glyphContext.stroke(
            path,
            with: .color(palette.outline),
            style: StrokeStyle(
              lineWidth: outlineWidth * 1.65,
              lineCap: .round,
              lineJoin: .round
            )
          )
          glyphContext.stroke(
            path,
            with: .color(palette.fill(for: glyph.tone)),
            style: StrokeStyle(
              lineWidth: outlineWidth * 0.72,
              lineCap: .round,
              lineJoin: .round
            )
          )
        }

        if pose == .clusters {
          glyphContext.stroke(
            curlDetailPath(
              for: glyph,
              center: center,
              artSide: artSide
            ),
            with: .color(palette.detail),
            style: StrokeStyle(
              lineWidth: detailWidth,
              lineCap: .round,
              lineJoin: .round
            )
          )
        } else if pose == .cloud, index == glyphs.count - 1 {
          glyphContext.stroke(
            transformedPath(
              contour: .curl,
              center: CGPoint(
                x: center.x,
                y: center.y - artSide * 0.035
              ),
              width: artSide * 0.52,
              height: artSide * 0.74,
              rotation: 0
            ),
            with: .color(palette.detail),
            style: StrokeStyle(
              lineWidth: detailWidth,
              lineCap: .round,
              lineJoin: .round
            )
          )
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func contourPath(
    for glyph: PoofGlyph,
    center: CGPoint,
    artSide: Double,
    scale: Double = 1
  ) -> Path {
    let glyphCenter = CGPoint(
      x: center.x + artSide * glyph.x,
      y: center.y + artSide * glyph.y
    )
    let curlHeightScale = glyph.contour == .curl ? 1.60 : 1

    return transformedPath(
      contour: glyph.contour,
      center: glyphCenter,
      width: artSide * glyph.width * scale,
      height: artSide * glyph.height * scale * curlHeightScale,
      rotation: glyph.rotation
    )
  }

  private func curlDetailPath(
    for glyph: PoofGlyph,
    center: CGPoint,
    artSide: Double
  ) -> Path {
    let glyphCenter = CGPoint(
      x: center.x + artSide * glyph.x,
      y: center.y + artSide * glyph.y
    )

    return transformedPath(
      contour: .curl,
      center: glyphCenter,
      width: artSide * glyph.width * 0.49,
      height: artSide * glyph.height * 0.65,
      rotation: indexRotation(for: glyph)
    )
  }

  private func indexRotation(for glyph: PoofGlyph) -> Double {
    glyph.x < 0 ? 0.08 : -0.08
  }

  private func transformedPath(
    contour: PoofContour,
    center: CGPoint,
    width: Double,
    height: Double,
    rotation: Double
  ) -> Path {
    Self.unitPath(for: contour)
      .applying(
        CGAffineTransform(
          scaleX: width,
          y: height
        )
      )
      .applying(
        CGAffineTransform(rotationAngle: rotation)
      )
      .applying(
        CGAffineTransform(
          translationX: center.x,
          y: center.y
        )
      )
  }

  private static func unitPath(for contour: PoofContour) -> Path {
    switch contour {
    case .puff4:
      puff4Path
    case .puff5:
      puff5Path
    case .ring:
      ringPath
    case .curl:
      curlPath
    case .fleck:
      fleckPath
    }
  }

  private static let puff4Path: Path = {
    var path = Path()
    path.move(to: CGPoint(x: 0, y: -0.31))
    path.addCurve(
      to: CGPoint(x: 0.31, y: 0),
      control1: CGPoint(x: 0.17, y: -0.48),
      control2: CGPoint(x: 0.45, y: -0.32)
    )
    path.addCurve(
      to: CGPoint(x: 0, y: 0.33),
      control1: CGPoint(x: 0.48, y: 0.16),
      control2: CGPoint(x: 0.31, y: 0.47)
    )
    path.addCurve(
      to: CGPoint(x: -0.32, y: 0),
      control1: CGPoint(x: -0.17, y: 0.48),
      control2: CGPoint(x: -0.47, y: 0.31)
    )
    path.addCurve(
      to: CGPoint(x: 0, y: -0.31),
      control1: CGPoint(x: -0.48, y: -0.16),
      control2: CGPoint(x: -0.31, y: -0.46)
    )
    path.closeSubpath()
    return path
  }()

  private static let puff5Path: Path = {
    var path = Path()
    path.move(to: CGPoint(x: 0, y: -0.32))
    path.addCurve(
      to: CGPoint(x: 0.314, y: -0.102),
      control1: CGPoint(x: 0.184, y: -0.454),
      control2: CGPoint(x: 0.375, y: -0.315)
    )
    path.addCurve(
      to: CGPoint(x: 0.188, y: 0.259),
      control1: CGPoint(x: 0.507, y: 0.053),
      control2: CGPoint(x: 0.442, y: 0.255)
    )
    path.addCurve(
      to: CGPoint(x: -0.200, y: 0.275),
      control1: CGPoint(x: 0.100, y: 0.469),
      control2: CGPoint(x: -0.100, y: 0.469)
    )
    path.addCurve(
      to: CGPoint(x: -0.295, y: -0.096),
      control1: CGPoint(x: -0.433, y: 0.250),
      control2: CGPoint(x: -0.497, y: 0.052)
    )
    path.addCurve(
      to: CGPoint(x: 0, y: -0.32),
      control1: CGPoint(x: -0.364, y: -0.328),
      control2: CGPoint(x: -0.199, y: -0.448)
    )
    path.closeSubpath()
    return path
  }()

  private static let ringPath: Path = {
    var path = Path()
    path.move(to: CGPoint(x: 0.48, y: -0.03))
    path.addCurve(
      to: CGPoint(x: 0.02, y: 0.43),
      control1: CGPoint(x: 0.47, y: 0.25),
      control2: CGPoint(x: 0.29, y: 0.45)
    )
    path.addCurve(
      to: CGPoint(x: -0.46, y: 0.02),
      control1: CGPoint(x: -0.25, y: 0.44),
      control2: CGPoint(x: -0.47, y: 0.27)
    )
    path.addCurve(
      to: CGPoint(x: -0.02, y: -0.42),
      control1: CGPoint(x: -0.46, y: -0.24),
      control2: CGPoint(x: -0.27, y: -0.43)
    )
    path.addCurve(
      to: CGPoint(x: 0.48, y: -0.03),
      control1: CGPoint(x: 0.27, y: -0.42),
      control2: CGPoint(x: 0.49, y: -0.28)
    )
    path.closeSubpath()
    return path
  }()

  private static let curlPath: Path = {
    var path = Path()
    path.move(to: CGPoint(x: -0.45, y: 0.12))
    path.addCurve(
      to: CGPoint(x: -0.15, y: 0.08),
      control1: CGPoint(x: -0.37, y: -0.18),
      control2: CGPoint(x: -0.23, y: -0.18)
    )
    path.addCurve(
      to: CGPoint(x: 0.15, y: 0.08),
      control1: CGPoint(x: -0.07, y: -0.19),
      control2: CGPoint(x: 0.07, y: -0.19)
    )
    path.addCurve(
      to: CGPoint(x: 0.45, y: 0.12),
      control1: CGPoint(x: 0.23, y: -0.17),
      control2: CGPoint(x: 0.37, y: -0.16)
    )
    return path
  }()

  private static let fleckPath: Path = {
    var path = Path()
    path.move(to: CGPoint(x: -0.43, y: -0.08))
    path.addCurve(
      to: CGPoint(x: -0.06, y: -0.31),
      control1: CGPoint(x: -0.33, y: -0.26),
      control2: CGPoint(x: -0.19, y: -0.33)
    )
    path.addCurve(
      to: CGPoint(x: 0.44, y: -0.01),
      control1: CGPoint(x: 0.18, y: -0.30),
      control2: CGPoint(x: 0.39, y: -0.19)
    )
    path.addCurve(
      to: CGPoint(x: 0.12, y: 0.29),
      control1: CGPoint(x: 0.47, y: 0.16),
      control2: CGPoint(x: 0.31, y: 0.29)
    )
    path.addCurve(
      to: CGPoint(x: -0.43, y: -0.08),
      control1: CGPoint(x: -0.08, y: 0.30),
      control2: CGPoint(x: -0.39, y: 0.17)
    )
    path.closeSubpath()
    return path
  }()
}

struct PoofPalette: Sendable {
  let light: Color
  let middle: Color
  let dark: Color
  let outline: Color
  let detail: Color
  let shadow: Color

  init(contrast: ColorSchemeContrast) {
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
