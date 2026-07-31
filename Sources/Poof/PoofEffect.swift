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
  private let style: PoofStyle
  private let configuration: PoofConfiguration
  private let palette: PoofPalette
  private let motion: PoofMotion

  /// Creates a poof at the supplied progress.
  ///
  /// Values at or below zero render no smoke. Values at or above one render
  /// no smoke after the fifth pose.
  ///
  /// - Parameters:
  ///   - progress: Absolute normalized playback progress.
  ///   - configuration: The poof's density, spread, overscan, and seed.
  ///   - palette: Fill colors for the smoke.
  ///   - motion: Stepped or smoothly interpolated pose changes.
  public init(
    progress: Double,
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic,
    motion: PoofMotion = .stepped
  ) {
    self.progress = progress
    style = .classic
    self.configuration = configuration
    self.palette = palette
    self.motion = motion
  }

  /// Creates a styled poof at the supplied progress.
  ///
  /// Values at or below zero render no smoke. Values at or above one render
  /// no smoke after the fifth pose.
  ///
  /// - Parameters:
  ///   - progress: Absolute normalized playback progress.
  ///   - style: The visual character of the poof.
  ///   - configuration: The poof's density, spread, overscan, and seed.
  ///   - palette: Fill colors for the smoke.
  ///   - motion: Stepped or smoothly interpolated pose changes.
  public init(
    progress: Double,
    style: PoofStyle,
    configuration: PoofConfiguration = .standard,
    palette: PoofPalette = .automatic,
    motion: PoofMotion = .stepped
  ) {
    self.progress = progress
    self.style = style
    self.configuration = configuration
    self.palette = palette
    self.motion = motion
  }

  public var body: some View {
    PoofPlayback(
      progress: progress,
      style: style,
      configuration: configuration,
      palette: PoofResolvedPalette(
        contrast: colorSchemeContrast,
        palette: palette,
        style: style
      ),
      motion: motion,
      reducesMotion: reducesMotion,
      reducesTransparency: reducesTransparency,
      artScale: 1,
      occludesSource: false
    )
  }
}

struct PoofPlayback: View {
  @State private var frameSet: PoofFrameSet? = nil

  let progress: Double
  let style: PoofStyle
  let configuration: PoofConfiguration
  let palette: PoofResolvedPalette
  let motion: PoofMotion
  let reducesMotion: Bool
  let reducesTransparency: Bool
  let artScale: Double
  let occludesSource: Bool

  var body: some View {
    let input = PoofPlaybackInput(
      style: style,
      configuration: configuration,
      coversSource: occludesSource,
      sourceCoverAspect: nil
    )

    PoofCanvas(
      progress: progress,
      palette: palette,
      motion: motion,
      reducesMotion: reducesMotion,
      reducesTransparency: reducesTransparency,
      artScale: artScale,
      frameSet: frameSet,
      occludesSource: occludesSource
    )
    .onChange(of: input, initial: true) { _, input in
      guard
        frameSet?.configuration != input.configuration
          || frameSet?.style != input.style
          || frameSet?.coversSource != input.coversSource
      else {
        return
      }

      // Cache every pose together so one seed governs the whole playback and
      // the Canvas never generates random values while drawing.
      frameSet = Self.makeFrameSet(
        for: input.configuration,
        style: input.style,
        coversSource: input.coversSource,
        sourceCoverAspect: input.sourceCoverAspect
      )
    }
  }

  static func makeFrameSet(
    for configuration: PoofConfiguration,
    style: PoofStyle = .classic,
    coversSource: Bool = false,
    sourceCoverAspect: PoofSourceCoverAspect? = nil,
    randomSeed: () -> UInt64 = {
      UInt64.random(in: 1...UInt64.max)
    }
  ) -> PoofFrameSet {
    PoofSimulation.makeFrameSet(
      configuration: configuration,
      style: style,
      coversSource: coversSource,
      sourceCoverAspect: sourceCoverAspect,
      variationSeed: configuration.seed
        ?? randomSeed()
    )
  }
}

struct PoofPlaybackInput: Equatable, Sendable {
  let style: PoofStyle
  let configuration: PoofConfiguration
  let coversSource: Bool
  let sourceCoverAspect: PoofSourceCoverAspect?
}

private struct PoofProgressiveTweenInput: Equatable {
  let sourceSize: CGSize
  let artSide: Double
  let frameSet: PoofFrameSet

  static func == (
    lhs: PoofProgressiveTweenInput,
    rhs: PoofProgressiveTweenInput
  ) -> Bool {
    lhs.sourceSize == rhs.sourceSize
      && lhs.artSide == rhs.artSide
      && lhs.frameSet.configuration == rhs.frameSet.configuration
      && lhs.frameSet.style == rhs.frameSet.style
      && lhs.frameSet.variationSeed == rhs.frameSet.variationSeed
      && lhs.frameSet.sourceCoverAspect
        == rhs.frameSet.sourceCoverAspect
  }
}

private struct PoofProgressiveTweenPlan: Sendable {
  private let plan: PoofSmoothPlan

  init(input: PoofProgressiveTweenInput) {
    let rect = CGRect(origin: .zero, size: input.sourceSize)
    let poseAnchors = PoofPose.allCases.map {
      PoofArtwork.progressiveGlyphs(
        for: $0,
        in: rect,
        artSide: input.artSide,
        frameSet: input.frameSet
      )
    }
    plan = PoofSmoothPlan(
      poseAnchors: poseAnchors,
      variationSeed: input.frameSet.variationSeed,
      // Keep source-cover lineage intact, then spatially track breakup.
      preservingLineageThrough: PoofPose.puffs.rawValue
    )
  }

  func blends(for sample: PoofPoseSample) -> [PoofGlyphBlend] {
    plan.blends(for: sample)
  }
}

@Animatable
struct PoofCanvas: View {
  var progress: Double

  @AnimatableIgnored var palette: PoofResolvedPalette
  @AnimatableIgnored var motion: PoofMotion = .stepped
  @AnimatableIgnored var reducesMotion: Bool
  @AnimatableIgnored var reducesTransparency: Bool
  @AnimatableIgnored var artScale: Double
  @AnimatableIgnored var frameSet: PoofFrameSet?
  @AnimatableIgnored var occludesSource: Bool
  @AnimatableIgnored var referenceArtSide: Double? = nil
  @AnimatableIgnored var sourceSize: CGSize? = nil

  var body: some View {
    PreparedPoofCanvas(
      progress: progress,
      palette: palette,
      motion: motion,
      reducesMotion: reducesMotion,
      reducesTransparency: reducesTransparency,
      artScale: artScale,
      frameSet: frameSet,
      occludesSource: occludesSource,
      referenceArtSide: referenceArtSide,
      sourceSize: sourceSize
    )
  }
}

private struct PreparedPoofCanvas: View {
  @State private var progressiveTweenInput: PoofProgressiveTweenInput?
  @State private var progressiveTweenPlan: PoofProgressiveTweenPlan?

  let progress: Double
  let palette: PoofResolvedPalette
  let motion: PoofMotion
  let reducesMotion: Bool
  let reducesTransparency: Bool
  let artScale: Double
  let frameSet: PoofFrameSet?
  let occludesSource: Bool
  let referenceArtSide: Double?
  let sourceSize: CGSize?

  var body: some View {
    let sample =
      motion == .smooth
      ? PoofSimulation.smoothSample(for: progress)
      : nil
    let pose =
      sample == nil
      ? PoofSimulation.pose(for: progress)
      : nil
    let newProgressiveTweenInput: PoofProgressiveTweenInput? =
      if motion == .smooth,
        occludesSource,
        let sourceSize,
        let referenceArtSide,
        let frameSet
      {
        PoofProgressiveTweenInput(
          sourceSize: sourceSize,
          artSide: referenceArtSide,
          frameSet: frameSet
        )
      } else {
        nil
      }
    let resolvedProgressiveTweenPlan: PoofProgressiveTweenPlan? =
      if newProgressiveTweenInput == progressiveTweenInput {
        progressiveTweenPlan
      } else {
        newProgressiveTweenInput.map(
          PoofProgressiveTweenPlan.init(input:)
        )
      }
    // Resolve interpolation before Canvas drawing so its callback only turns
    // bounded, deterministic descriptors into paths.
    let smoothGlyphBlends: [PoofGlyphBlend]? =
      if let sample, let frameSet {
        if let resolvedProgressiveTweenPlan {
          resolvedProgressiveTweenPlan.blends(for: sample)
        } else {
          PoofArtwork.renderedGlyphBlends(
            for: sample,
            occludesSource: occludesSource,
            frameSet: frameSet
          )
        }
      } else {
        nil
      }
    // Stepped progressive playback hands the breakup poses on at the scale the
    // cover reached, resolved here so the Canvas callback only draws.
    let progressiveBreakupBlends: [PoofGlyphBlend]? =
      if sample == nil,
        occludesSource,
        let pose,
        let frameSet,
        let sourceSize,
        let referenceArtSide
      {
        PoofArtwork.progressiveBreakupBlends(
          for: pose,
          in: CGRect(origin: .zero, size: sourceSize),
          artSide: referenceArtSide,
          frameSet: frameSet
        )
      } else {
        nil
      }

    Canvas(
      opaque: false,
      colorMode: .nonLinear,
      rendersAsynchronously: false
    ) { context, size in
      guard
        !reducesMotion,
        size.width > 0,
        size.height > 0,
        let frameSet
      else {
        return
      }

      guard sample != nil || pose != nil else {
        return
      }

      let scale =
        artScale.isFinite
        ? max(artScale, 1)
        : 1
      let artSide =
        referenceArtSide
        ?? min(size.width, size.height) / scale
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let outlineWidth = max(0.5, artSide * 0.014)
      let detailWidth = max(0.4, artSide * 0.011)
      let detailStrokeStyle = StrokeStyle(
        lineWidth: detailWidth,
        lineCap: .round,
        lineJoin: .round
      )
      let sourceRect = sourceSize.map { sourceSize in
        CGRect(
          x: center.x - sourceSize.width / 2,
          y: center.y - sourceSize.height / 2,
          width: sourceSize.width,
          height: sourceSize.height
        )
      }
      let usesSmoothProgressive =
        sample != nil
        && occludesSource
        && sourceRect != nil
      let smoothCoverScale =
        if usesSmoothProgressive, let sample {
          sourceCoverScale(for: sample)
        } else {
          0.0
        }
      let coverOutlineWidth = max(0.4, outlineWidth * 0.72)
      let coverFillStrokeWidth =
        PoofArtwork.sourceCoverFillStrokeWidth(
          artSide: artSide
        )
      let glyphBlends: [PoofGlyphBlend] =
        if sample != nil {
          smoothGlyphBlends ?? []
        } else if let progressiveBreakupBlends {
          progressiveBreakupBlends
        } else if let pose {
          PoofArtwork.renderedGlyphBlends(
            for: pose,
            occludesSource: occludesSource,
            frameSet: frameSet
          )
        } else {
          []
        }
      let clusterDetailWeight =
        if !occludesSource, sample == nil, pose == .clusters {
          1.0
        } else {
          0.0
        }
      let cloudDetailWeight =
        if !occludesSource, sample == nil, pose == .cloud {
          1.0
        } else {
          0.0
        }
      var shadowContext = context

      if occludesSource,
        sample == nil,
        let pose,
        pose == .cloud || pose == .clusters || pose == .puffs,
        let sourceRect
      {
        let elements =
          PoofArtwork.sourceCoverElements(
            for: pose,
            in: sourceRect,
            frameSet: frameSet
          )
          .sorted {
            $0.drawPriority > $1.drawPriority
          }
        for element in elements {
          let fill = palette.fill(
            for: element.tone,
            index: element.paletteIndex
          )

          context.fill(
            element.path,
            with: .color(fill)
          )
          // Fill beneath the outline's antialiased edge so source color
          // cannot tint the final fringe.
          context.stroke(
            element.path,
            with: .color(fill),
            lineWidth: coverFillStrokeWidth * element.scale
          )
          context.stroke(
            element.path,
            with: .color(palette.outline),
            lineWidth: coverOutlineWidth
          )
        }
      }

      if !reducesTransparency {
        shadowContext.translateBy(x: 0, y: artSide * 0.018)
        shadowContext.addFilter(
          .blur(radius: max(0.35, artSide * 0.017))
        )
      }

      for (index, blend) in glyphBlends.enumerated() {
        let glyph = blend.glyph
        let glyphScale = blend.scale
        let scaledDetailStrokeStyle = StrokeStyle(
          lineWidth: detailWidth * glyphScale,
          lineCap: .round,
          lineJoin: .round
        )
        let scaledShadowStrokeStyle = StrokeStyle(
          lineWidth: outlineWidth * 2.15 * glyphScale,
          lineCap: .round,
          lineJoin: .round
        )
        let scaledOuterStrokeStyle = StrokeStyle(
          lineWidth: outlineWidth * 1.65 * glyphScale,
          lineCap: .round,
          lineJoin: .round
        )
        let scaledInnerStrokeStyle = StrokeStyle(
          lineWidth: outlineWidth * 0.72 * glyphScale,
          lineCap: .round,
          lineJoin: .round
        )
        let opacity =
          if reducesTransparency, motion == .stepped {
            max(glyph.opacity, 0.88)
          } else if reducesTransparency {
            min(glyph.opacity * 1.12, 1)
          } else {
            glyph.opacity
          }
        let path = PoofArtwork.contourPath(
          for: glyph,
          center: center,
          artSide: artSide
        )
        let fill = palette.fill(for: blend)

        if !reducesTransparency {
          var glyphShadowContext = shadowContext
          glyphShadowContext.opacity = opacity

          if glyphShadowContext.opacity > 0,
            glyph.paint == .doubleStroke
          {
            glyphShadowContext.stroke(
              path,
              with: .color(palette.shadow),
              style: scaledShadowStrokeStyle
            )
          } else if glyphShadowContext.opacity > 0 {
            glyphShadowContext.fill(
              path,
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
            with: .color(fill)
          )
          if usesSmoothProgressive, smoothCoverScale > 0 {
            var underpaintContext = context
            underpaintContext.opacity = opacity
            underpaintContext.stroke(
              path,
              with: .color(fill),
              lineWidth:
                coverFillStrokeWidth
                * smoothCoverScale
                * glyphScale
            )
          }
          glyphContext.stroke(
            path,
            with: .color(palette.outline),
            lineWidth: outlineWidth * glyphScale
          )

          if glyph.paint == .fillOutlineAndInset {
            glyphContext.stroke(
              PoofArtwork.contourPath(
                for: glyph,
                center: center,
                artSide: artSide,
                scale: 0.46
              ),
              with: .color(palette.detail),
              style: scaledDetailStrokeStyle
            )
          }
        case .doubleStroke:
          glyphContext.stroke(
            path,
            with: .color(palette.outline),
            style: scaledOuterStrokeStyle
          )
          glyphContext.stroke(
            path,
            with: .color(fill),
            style: scaledInnerStrokeStyle
          )
        }

        if clusterDetailWeight > 0 {
          glyphContext.opacity = opacity * clusterDetailWeight
          glyphContext.stroke(
            PoofArtwork.curlDetailPath(
              for: glyph,
              center: center,
              artSide: artSide
            ),
            with: .color(palette.detail),
            style: scaledDetailStrokeStyle
          )
        }

        if cloudDetailWeight > 0,
          index == glyphBlends.count - 1
        {
          var detailContext = context
          detailContext.opacity = opacity * cloudDetailWeight
          detailContext.stroke(
            PoofArtwork.transformedPath(
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
            style: detailStrokeStyle
          )
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onChange(
      of: newProgressiveTweenInput,
      initial: true
    ) { _, input in
      progressiveTweenInput = input
      progressiveTweenPlan = input.map(
        PoofProgressiveTweenPlan.init(input:)
      )
    }
  }

  private func sourceCoverScale(
    for sample: PoofPoseSample
  ) -> Double {
    // Keep the opaque seam-closing stroke at full width until dense puffs have
    // covered the source, then shrink it away with the departing smoke.
    if sample.segment < PoofPose.puffs.rawValue + 1 {
      return 1
    }

    guard sample.start == .puffs, sample.end == .wisps else {
      return 0
    }

    let amount = min(max(sample.amount, 0), 1)
    let amountCubed = amount * amount * amount
    let smootherAmount =
      amountCubed
      * (amount * (amount * 6 - 15) + 10)
    return 1 - smootherAmount
  }
}

enum PoofArtwork {
  struct SourceCoverElement {
    let path: Path
    let center: CGPoint
    let scale: Double
    let drawPriority: Double
    let tone: PoofTone
    let paletteIndex: Int
  }

  private struct SourceCoverGeometry {
    let path: Path
    let center: CGPoint
  }

  static let maximumRenderedElementCount = 64
  // A stable lineage grows from a compact root cloud into the base branches.
  // Repair and fringe puffs begin as small buds, then fill out in the final.
  static let sourceCoverCloudGrowth = 1.00
  static let sourceCoverCloudReach = 0.38
  static let sourceCoverClusterRootReach = 0.64
  static let sourceCoverClusterRootGrowth = 1.00
  static let sourceCoverClusterChildGrowth = 0.95
  static let sourceCoverClusterRepairGrowth = 0.80
  static let sourceCoverClusterFringeGrowth = 0.80
  static let sourceCoverBranchGrowth = 0.70
  static let sourceCoverMaximumOverhangRatio = 0.22

  static func sourceCoverFillStrokeWidth(
    artSide: Double
  ) -> Double {
    let outlineWidth = max(0.5, artSide * 0.014)
    let coverOutlineWidth = max(0.4, outlineWidth * 0.72)
    // A wider opaque underpaint closes source-edge seams; the dark contour is
    // drawn immediately afterward to keep neighboring puffs legible. This
    // width is also what makes the dense pose provably tile the source, which
    // is what lets the erosion retire it outright. Narrowing it breaks that
    // proof: coverage already fails at 4.0.
    return coverOutlineWidth * 4.5
  }

  /// How far the breakup poses must be stretched to leave off where the
  /// progressive cover ended.
  struct ProgressiveBreakupScale: Equatable, Sendable {
    static let identity = ProgressiveBreakupScale(
      positionX: 1,
      positionY: 1,
      size: 1
    )

    let positionX: Double
    let positionY: Double
    let size: Double
  }

  /// Bridges the progressive cover's source space to the authored art space.
  ///
  /// The cover is a similarity map onto the laid-out bounds, while the breakup
  /// poses are drawn against `artSide`, which is clamped to 42...160. Without a
  /// bridge the smoke jumps between the two at the third pose swap, and the
  /// jump grows without bound once the source passes the clamp.
  ///
  /// Positions scale per axis so a wide row keeps a wide dispersal, while size
  /// follows the tighter axis so a long thin source keeps normally
  /// proportioned puffs instead of one stretched blob.
  static func progressiveBreakupScale(
    in rect: CGRect,
    artSide: Double,
    frameSet: PoofFrameSet
  ) -> ProgressiveBreakupScale {
    let coverGlyphs = sourceCoverGlyphLayers(
      for: .puffs,
      in: rect,
      artSide: artSide,
      frameSet: frameSet
    )
    .map(\.glyph)
    let authoredGlyphs = frameSet.glyphs(for: .puffs)

    guard
      !coverGlyphs.isEmpty,
      !authoredGlyphs.isEmpty
    else {
      return .identity
    }

    let cover = normalizedExtent(of: coverGlyphs)
    let authored = normalizedExtent(of: authoredGlyphs)

    guard
      authored.x > 0,
      authored.y > 0,
      cover.x.isFinite,
      cover.y.isFinite
    else {
      return .identity
    }

    let positionX = min(max(cover.x / authored.x, 0.25), 64)
    let positionY = min(max(cover.y / authored.y, 0.25), 64)

    return ProgressiveBreakupScale(
      positionX: positionX,
      positionY: positionY,
      size: min(max(min(positionX, positionY), 0.5), 4)
    )
  }

  private static func normalizedExtent(
    of glyphs: [PoofGlyph]
  ) -> (x: Double, y: Double) {
    var x = 0.0
    var y = 0.0

    for glyph in glyphs {
      x = max(x, abs(glyph.x) + glyph.width / 2)
      y = max(y, abs(glyph.y) + glyph.height / 2)
    }

    return (x, y)
  }

  /// The breakup blends for progressive playback, carried on from the scale
  /// the cover reached. One scale serves both breakup poses so the authored
  /// contraction between them survives untouched.
  static func progressiveBreakupBlends(
    for pose: PoofPose,
    in rect: CGRect,
    artSide: Double,
    frameSet: PoofFrameSet
  ) -> [PoofGlyphBlend] {
    switch pose {
    case .cloud, .clusters, .puffs:
      return []
    case .wisps, .ringlets:
      break
    }

    let scale = progressiveBreakupScale(
      in: rect,
      artSide: artSide,
      frameSet: frameSet
    )

    return frameSet.glyphs(for: pose)
      .prefix(maximumRenderedElementCount)
      .enumerated()
      .map { index, glyph in
        .single(
          PoofGlyph(
            x: glyph.x * scale.positionX,
            y: glyph.y * scale.positionY,
            width: glyph.width * scale.size,
            height: glyph.height * scale.size,
            opacity: glyph.opacity,
            contour: glyph.contour,
            paint: glyph.paint,
            rotation: glyph.rotation,
            tone: glyph.tone
          ),
          paletteIndex: index
        )
      }
  }

  static func renderedGlyphs(
    for pose: PoofPose,
    occludesSource: Bool,
    frameSet: PoofFrameSet
  ) -> [PoofGlyph] {
    let poseGlyphs = frameSet.glyphs(for: pose)

    guard occludesSource else {
      return Array(
        poseGlyphs.prefix(maximumRenderedElementCount)
      )
    }

    switch pose {
    case .cloud, .clusters, .puffs:
      // The progressive cover is the artwork for its first three poses. Its
      // persistent small puffs would otherwise compete with the legacy layer's
      // intentionally different cloud, cluster, and dense compositions.
      return []
    case .wisps, .ringlets:
      return Array(
        poseGlyphs.prefix(maximumRenderedElementCount)
      )
    }
  }

  static func renderedGlyphBlends(
    for pose: PoofPose,
    occludesSource: Bool,
    frameSet: PoofFrameSet
  ) -> [PoofGlyphBlend] {
    renderedGlyphs(
      for: pose,
      occludesSource: occludesSource,
      frameSet: frameSet
    ).enumerated().map {
      .single($0.element, paletteIndex: $0.offset)
    }
  }

  static func renderedGlyphBlends(
    for sample: PoofPoseSample,
    occludesSource: Bool,
    frameSet: PoofFrameSet
  ) -> [PoofGlyphBlend] {
    guard !occludesSource else {
      // Progressive playback uses source-adaptive glyphs prepared from the
      // laid-out source bounds.
      return []
    }

    return Array(
      frameSet.blends(for: sample).prefix(maximumRenderedElementCount)
    )
  }

  static func sourceCoverPath(
    for pose: PoofPose,
    in rect: CGRect,
    frameSet: PoofFrameSet
  ) -> Path? {
    let elements = sourceCoverElements(
      for: pose,
      in: rect,
      frameSet: frameSet
    )

    guard elements.isEmpty == false else {
      return nil
    }

    var path = Path()

    for element in elements {
      path.addPath(element.path)
    }

    return path
  }

  static func sourceCoverElements(
    for pose: PoofPose,
    in rect: CGRect,
    frameSet: PoofFrameSet
  ) -> [SourceCoverElement] {
    guard pose == .cloud || pose == .clusters || pose == .puffs else {
      return []
    }

    let aspect = PoofSourceCoverAspect(size: rect.size)
    let allGlyphs = frameSet.sourceCoverGlyphs(for: aspect)
    let visibleCount =
      switch pose {
      case .cloud:
        PoofSourceCoverLayout.cloudGlyphCount
      case .clusters:
        PoofSourceCoverLayout.openingGlyphCount
      case .puffs:
        PoofSourceCoverLayout.glyphCount
      case .wisps, .ringlets:
        0
      }
    let glyphs = Array(allGlyphs.prefix(visibleCount))
    let finalGeometry = allGlyphs.map { glyph in
      boundedSourceCoverGeometry(
        for: glyph,
        in: rect
      )
    }

    if pose == .puffs {
      return zip(glyphs, finalGeometry.prefix(visibleCount)).map {
        glyph,
        geometry in
        SourceCoverElement(
          path: geometry.path,
          center: geometry.center,
          scale: 1,
          drawPriority: glyph.width * glyph.height,
          tone: glyph.tone,
          paletteIndex: glyph.paletteIndex
        )
      }
    }

    let centers: [CGPoint] =
      pose == .cloud
      ? finalGeometry.prefix(visibleCount).map {
        CGPoint(
          x: rect.midX + ($0.center.x - rect.midX) * sourceCoverCloudReach,
          y: rect.midY + ($0.center.y - rect.midY) * sourceCoverCloudReach
        )
      }
      : sourceCoverCenters(
        glyphs: glyphs,
        finalCenters: finalGeometry.map(\.center),
        rect: rect,
        rootReach: sourceCoverClusterRootReach,
        branchGrowth: sourceCoverBranchGrowth
      )

    return glyphs.enumerated().map { index, glyph in
      let center = centers[index]
      let growth =
        pose == .cloud
        ? sourceCoverCloudGrowth
        : sourceCoverClusterGrowth(at: index)

      return SourceCoverElement(
        path: transformedPath(
          contour: glyph.contour,
          center: center,
          width: rect.width * glyph.width * growth,
          height: rect.height * glyph.height * growth,
          rotation: glyph.rotation
        ),
        center: center,
        scale: growth,
        drawPriority: glyph.width * glyph.height,
        tone: glyph.tone,
        paletteIndex: glyph.paletteIndex
      )
    }
  }

  static func progressiveGlyphs(
    for pose: PoofPose?,
    in rect: CGRect,
    artSide: Double,
    frameSet: PoofFrameSet
  ) -> [PoofGlyphLayer] {
    guard let pose else {
      return []
    }

    switch pose {
    case .cloud, .clusters, .puffs:
      return sourceCoverGlyphLayers(
        for: pose,
        in: rect,
        artSide: artSide,
        frameSet: frameSet
      )
    case .wisps, .ringlets:
      return frameSet.glyphs(for: pose).enumerated().map {
        PoofGlyphLayer(
          glyph: $0.element,
          paletteIndex: $0.offset
        )
      }
    }
  }

  private static func sourceCoverGlyphLayers(
    for pose: PoofPose,
    in rect: CGRect,
    artSide: Double,
    frameSet: PoofFrameSet
  ) -> [PoofGlyphLayer] {
    let aspect = PoofSourceCoverAspect(size: rect.size)
    let allGlyphs = frameSet.sourceCoverGlyphs(for: aspect)
    let visibleCount =
      switch pose {
      case .cloud:
        PoofSourceCoverLayout.cloudGlyphCount
      case .clusters:
        PoofSourceCoverLayout.openingGlyphCount
      case .puffs:
        PoofSourceCoverLayout.glyphCount
      case .wisps, .ringlets:
        0
      }
    let glyphs = Array(allGlyphs.prefix(visibleCount))
    let finalCenters = allGlyphs.map {
      CGPoint(
        x: rect.midX + rect.width * $0.x,
        y: rect.midY + rect.height * $0.y
      )
    }
    let centers: [CGPoint] =
      switch pose {
      case .cloud:
        finalCenters.prefix(visibleCount).map {
          CGPoint(
            x: rect.midX + ($0.x - rect.midX) * sourceCoverCloudReach,
            y: rect.midY + ($0.y - rect.midY) * sourceCoverCloudReach
          )
        }
      case .clusters:
        sourceCoverCenters(
          glyphs: glyphs,
          finalCenters: finalCenters,
          rect: rect,
          rootReach: sourceCoverClusterRootReach,
          branchGrowth: sourceCoverBranchGrowth
        )
      case .puffs:
        Array(finalCenters.prefix(visibleCount))
      case .wisps, .ringlets:
        []
      }

    return glyphs.enumerated().map { index, glyph in
      let growth =
        switch pose {
        case .cloud:
          sourceCoverCloudGrowth
        case .clusters:
          sourceCoverClusterGrowth(at: index)
        case .puffs:
          1.0
        case .wisps, .ringlets:
          0.0
        }

      return PoofGlyphLayer(
        glyph: PoofGlyph(
          x: (centers[index].x - rect.midX) / artSide,
          y: (centers[index].y - rect.midY) / artSide,
          width: rect.width * glyph.width * growth / artSide,
          height: rect.height * glyph.height * growth / artSide,
          contour: glyph.contour,
          rotation: glyph.rotation,
          tone: glyph.tone
        ),
        paletteIndex: glyph.paletteIndex
      )
    }
  }

  private static func sourceCoverCenters(
    glyphs: [PoofSourceCoverGlyph],
    finalCenters: [CGPoint],
    rect: CGRect,
    rootReach: Double,
    branchGrowth: Double
  ) -> [CGPoint] {
    var centers: [CGPoint] = []
    centers.reserveCapacity(glyphs.count)

    for (index, glyph) in glyphs.enumerated() {
      let finalCenter = finalCenters[index]

      guard let parentIndex = glyph.lineageParentIndex else {
        centers.append(
          CGPoint(
            x:
              rect.midX
              + (finalCenter.x - rect.midX) * rootReach,
            y:
              rect.midY
              + (finalCenter.y - rect.midY) * rootReach
          )
        )
        continue
      }

      let parentCenter = centers[parentIndex]
      // Each bud advances from its visible parent toward its own destination,
      // preserving the branch across the hard pose swap.
      centers.append(
        CGPoint(
          x:
            parentCenter.x
            + (finalCenter.x - parentCenter.x)
              * branchGrowth,
          y:
            parentCenter.y
            + (finalCenter.y - parentCenter.y)
            * branchGrowth
        )
      )
    }

    return centers
  }

  private static func sourceCoverClusterGrowth(
    at index: Int
  ) -> Double {
    if index < PoofSourceCoverLayout.rootGlyphCount {
      sourceCoverClusterRootGrowth
    } else if index < PoofSourceCoverLayout.baseGlyphCount {
      sourceCoverClusterChildGrowth
    } else if index
      < PoofSourceCoverLayout.baseGlyphCount
      + PoofSourceCoverLayout.repairGlyphCount
    {
      sourceCoverClusterRepairGrowth
    } else {
      sourceCoverClusterFringeGrowth
    }
  }

  private static func boundedSourceCoverGeometry(
    for glyph: PoofSourceCoverGlyph,
    in rect: CGRect
  ) -> SourceCoverGeometry {
    let center = CGPoint(
      x: rect.midX + rect.width * glyph.x,
      y: rect.midY + rect.height * glyph.y
    )
    let path = transformedPath(
      contour: glyph.contour,
      center: center,
      width: rect.width * glyph.width,
      height: rect.height * glyph.height,
      rotation: glyph.rotation
    )
    let overhang =
      PoofLayout.artSide(for: rect.size)
      * sourceCoverMaximumOverhangRatio
    let allowedBounds = rect.insetBy(dx: -overhang, dy: -overhang)
    let bounds = path.boundingRect
    var translationX = 0.0
    var translationY = 0.0

    if bounds.minX < allowedBounds.minX {
      translationX = allowedBounds.minX - bounds.minX
    }
    if bounds.maxX + translationX > allowedBounds.maxX {
      translationX += allowedBounds.maxX - bounds.maxX - translationX
    }
    if bounds.minY < allowedBounds.minY {
      translationY = allowedBounds.minY - bounds.minY
    }
    if bounds.maxY + translationY > allowedBounds.maxY {
      translationY += allowedBounds.maxY - bounds.maxY - translationY
    }

    guard translationX != 0 || translationY != 0 else {
      return SourceCoverGeometry(path: path, center: center)
    }

    let translation = CGAffineTransform(
      translationX: translationX,
      y: translationY
    )
    return SourceCoverGeometry(
      path: path.applying(translation),
      center: center.applying(translation)
    )
  }

  static func contourPath(
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

  static func curlDetailPath(
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
      rotation: curlDetailRotation(for: glyph)
    )
  }

  private static func curlDetailRotation(for glyph: PoofGlyph) -> Double {
    glyph.x < 0 ? 0.08 : -0.08
  }

  static func transformedPath(
    contour: PoofContour,
    center: CGPoint,
    width: Double,
    height: Double,
    rotation: Double
  ) -> Path {
    // Compose scale, rotation, and translation into one matrix. Chaining
    // `applying` walks and reallocates the element list once per step, and
    // this is the hottest per-glyph call in the renderer.
    Self.unitPath(for: contour)
      .applying(
        CGAffineTransform(scaleX: width, y: height)
          .concatenating(
            CGAffineTransform(rotationAngle: rotation)
          )
          .concatenating(
            CGAffineTransform(
              translationX: center.x,
              y: center.y
            )
          )
      )
  }

  // Canvas transforms these cached unit-space contours for every glyph.
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

struct PoofResolvedPalette: Sendable {
  let light: Color
  let middle: Color
  let dark: Color
  let outline: Color
  let detail: Color
  let shadow: Color
  private let colors: [Color]

  init(
    contrast: ColorSchemeContrast,
    palette: PoofPalette = .automatic,
    style: PoofStyle = .classic
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
    colors = palette.colors(for: style)
  }

  func fill(
    for tone: PoofTone,
    index: Int
  ) -> Color {
    if colors.isEmpty == false {
      return colors[(index + tone.rawValue) % colors.count]
    }

    return switch tone {
    case .light:
      light
    case .middle:
      middle
    case .dark:
      dark
    }
  }

  func fill(for blend: PoofGlyphBlend) -> Color {
    fill(
      for: blend.glyph.tone,
      index: blend.paletteIndex
    )
  }
}
