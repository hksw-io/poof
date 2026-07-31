import Foundation

enum PoofPose: Int, CaseIterable, Sendable {
  case cloud
  case clusters
  case puffs
  case wisps
  case ringlets
}

enum PoofTone: Int, Hashable, Sendable {
  case light
  case middle
  case dark
}

enum PoofContour: UInt8, CaseIterable, Hashable, Sendable {
  case puff4
  case puff5
  case ring
  case curl
  case fleck
}

enum PoofPaint: UInt8, CaseIterable, Hashable, Sendable {
  case fillAndOutline
  case fillOutlineAndInset
  case doubleStroke
}

struct PoofGlyph: Equatable, Sendable {
  let x: Double
  let y: Double
  let width: Double
  let height: Double
  let opacity: Double
  let contour: PoofContour
  let paint: PoofPaint
  let rotation: Double
  let tone: PoofTone

  init(
    x: Double,
    y: Double,
    width: Double,
    height: Double,
    opacity: Double = 1,
    contour: PoofContour = .puff4,
    paint: PoofPaint = .fillAndOutline,
    rotation: Double = 0,
    tone: PoofTone = .light
  ) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.opacity = opacity
    self.contour = contour
    self.paint = paint
    self.rotation = rotation
    self.tone = tone
  }
}

struct PoofGlyphLayer: Equatable, Sendable {
  let glyph: PoofGlyph
  let paletteIndex: Int
}

struct PoofGlyphBlend: Equatable, Sendable {
  let glyph: PoofGlyph
  let scale: Double
  let paletteIndex: Int

  static func single(
    _ glyph: PoofGlyph,
    paletteIndex: Int,
    scale: Double = 1
  ) -> PoofGlyphBlend {
    PoofGlyphBlend(
      glyph: glyph,
      scale: scale,
      paletteIndex: paletteIndex
    )
  }
}

enum PoofSourceCoverAspect: CaseIterable, Hashable, Sendable {
  case square
  case wide
  case tall

  init(size: CGSize) {
    if size.width > size.height * 1.4 {
      self = .wide
    } else if size.height > size.width * 1.4 {
      self = .tall
    } else {
      self = .square
    }
  }
}

struct PoofSourceCoverGlyph: Equatable, Sendable {
  let x: Double
  let y: Double
  let width: Double
  let height: Double
  let rotation: Double
  let contour: PoofContour
  let tone: PoofTone
  let paletteIndex: Int
  let clusterIndex: Int
  let lineageParentIndex: Int?
}

struct PoofSourceCoverLayout: Equatable, Sendable {
  static let glyphCount = 64
  static let rootGlyphCount = 12
  static let repairGlyphCount = 10
  static let fringeGlyphCount = 12
  static let baseGlyphCount =
    glyphCount - repairGlyphCount - fringeGlyphCount
  static let cloudGlyphCount = rootGlyphCount
  static let openingGlyphCount = baseGlyphCount + repairGlyphCount

  private let square: [PoofSourceCoverGlyph]
  private let wide: [PoofSourceCoverGlyph]
  private let tall: [PoofSourceCoverGlyph]

  init(
    square: [PoofSourceCoverGlyph],
    wide: [PoofSourceCoverGlyph],
    tall: [PoofSourceCoverGlyph]
  ) {
    self.square = square
    self.wide = wide
    self.tall = tall
  }

  func glyphs(for aspect: PoofSourceCoverAspect) -> [PoofSourceCoverGlyph] {
    switch aspect {
    case .square:
      square
    case .wide:
      wide
    case .tall:
      tall
    }
  }
}

struct PoofFrameSet: Sendable {
  let configuration: PoofConfiguration
  let style: PoofStyle
  let variationSeed: UInt64
  private let poses: [[PoofGlyph]]
  private let plume: PoofPlume
  private let sourceCoverLayout: PoofSourceCoverLayout?
  let sourceCoverAspect: PoofSourceCoverAspect?

  var coversSource: Bool {
    sourceCoverLayout != nil
  }

  init(
    configuration: PoofConfiguration,
    style: PoofStyle,
    variationSeed: UInt64,
    poses: [[PoofGlyph]],
    sourceCoverLayout: PoofSourceCoverLayout?,
    sourceCoverAspect: PoofSourceCoverAspect?
  ) {
    self.configuration = configuration
    self.style = style
    self.variationSeed = variationSeed
    self.poses = poses
    // The authored poses seed where puffs start and how big they begin; the
    // motion between them belongs to the plume, not to a tween.
    plume = PoofPlume.make(
      configuration: configuration,
      style: style,
      profile: sourceCoverLayout == nil ? .standalone : .progressive,
      origins: PoofPlume.origins(from: poses),
      variationSeed: variationSeed
    )
    self.sourceCoverLayout = sourceCoverLayout
    self.sourceCoverAspect = sourceCoverAspect
  }

  func glyphs(for pose: PoofPose) -> [PoofGlyph] {
    poses[pose.rawValue]
  }

  /// The smoke alive at this progress under smooth motion.
  func blends(at progress: Double) -> [PoofGlyphBlend] {
    plume.blends(at: progress)
  }

  var plumeEngulfProgress: Double {
    plume.engulfProgress
  }

  /// The glyphs generated for an aspect, with no substitution.
  ///
  /// Playback should use ``sourceCoverGlyphs(for:)``. This answers what was
  /// actually built, which is what proves the single-aspect generation path.
  func storedSourceCoverGlyphs(
    for aspect: PoofSourceCoverAspect
  ) -> [PoofSourceCoverGlyph] {
    sourceCoverLayout?.glyphs(for: aspect) ?? []
  }

  func sourceCoverGlyphs(
    for aspect: PoofSourceCoverAspect
  ) -> [PoofSourceCoverGlyph] {
    guard let sourceCoverLayout else {
      return []
    }

    let glyphs = sourceCoverLayout.glyphs(for: aspect)

    guard glyphs.isEmpty else {
      return glyphs
    }

    // A layout built for one aspect class is asked for another when the source
    // is resized across the 1.4 ratio. Answer with the aspect that was built
    // rather than nothing, so the frame in flight before the rebuild lands
    // still draws smoke.
    guard let sourceCoverAspect else {
      return []
    }

    return sourceCoverLayout.glyphs(for: sourceCoverAspect)
  }
}

enum PoofSimulation {
  static let frameDuration = 1.0 / 15.0
  static let duration = frameDuration * Double(PoofPose.allCases.count)
  /// Continuous smoke needs a moment longer to finish thinning out.
  static let smoothDuration = 0.45

  static func duration(for motion: PoofMotion) -> Double {
    switch motion {
    case .stepped:
      duration
    case .smooth:
      smoothDuration
    }
  }

  private static let referenceSpread = 0.82
  // Stable index angles keep each Snap glyph on one ray across breakup poses.
  private static let goldenAngle = 2.399_963_229_728_653
  // Extra glyph placement needs a stable base before playback variation.
  private static let fallbackLayoutSeed: UInt64 = 0x504F_4F46
  static let sourceCoverGeometryProfileCount = 64

  static func makeFrameSet(
    configuration: PoofConfiguration,
    style: PoofStyle = .classic,
    coversSource: Bool = true,
    sourceCoverAspect: PoofSourceCoverAspect? = nil,
    variationSeed: UInt64
  ) -> PoofFrameSet {
    let poses = PoofPose.allCases.map { pose in
      (0..<glyphCount(for: pose, configuration: configuration))
        .compactMap { index in
          glyph(
            at: index,
            pose: pose,
            configuration: configuration,
            style: style,
            variationSeed: variationSeed
          )
        }
    }
    let sourceCoverClusters =
      (0..<glyphCount(
        for: .clusters,
        configuration: configuration
      )).compactMap { index in
        sourceCoverClusterGlyph(
          at: index,
          configuration: configuration,
          style: style,
          variationSeed: variationSeed
        )
      }

    return PoofFrameSet(
      configuration: configuration,
      style: style,
      variationSeed: variationSeed,
      poses: poses,
      sourceCoverLayout:
        coversSource
        ? sourceCoverLayout(
          seed: variationSeed,
          clusterGlyphs: sourceCoverClusters,
          aspect: sourceCoverAspect
        )
        : nil,
      sourceCoverAspect: coversSource ? sourceCoverAspect : nil
    )
  }

  /// The progress a frame is actually drawn at.
  ///
  /// Stepped playback holds one pose for a whole frame interval, so collapsing
  /// progress onto the interval keeps SwiftUI from re-rendering the canvas at
  /// display refresh for output that cannot change until the next swap. The
  /// endpoints pass through untouched so they stay transparent.
  static func drawnProgress(
    for progress: Double,
    motion: PoofMotion
  ) -> Double {
    guard motion == .stepped else {
      return progress
    }

    let normalized = normalized(progress)

    guard normalized > 0, normalized < 1 else {
      return progress
    }

    let poseCount = Double(PoofPose.allCases.count)
    let index = min(
      Double(Int(normalized * poseCount)),
      poseCount - 1
    )

    return (index + 0.5) / poseCount
  }

  static func pose(for progress: Double) -> PoofPose? {
    let progress = normalized(progress)

    guard progress > 0, progress < 1 else {
      return nil
    }

    let index = min(
      Int(progress * Double(PoofPose.allCases.count)),
      PoofPose.allCases.count - 1
    )
    return PoofPose(rawValue: index)
  }

  static func glyphCount(
    for pose: PoofPose,
    configuration: PoofConfiguration
  ) -> Int {
    switch pose {
    case .cloud:
      7
    case .clusters:
      4
    case .puffs:
      configuration.particleCount
    case .wisps:
      breakupCount(
        referenceCount: wispReferences.count,
        configuration: configuration
      )
    case .ringlets:
      breakupCount(
        referenceCount: ringletReferences.count,
        configuration: configuration
      )
    }
  }

  static func glyph(
    at index: Int,
    pose: PoofPose,
    configuration: PoofConfiguration,
    style: PoofStyle = .classic,
    variationSeed: UInt64
  ) -> PoofGlyph? {
    let glyph: PoofGlyph?

    switch pose {
    case .cloud:
      glyph = cloudGlyph(at: index)
    case .clusters:
      glyph = clusterGlyph(at: index)
    case .puffs, .wisps, .ringlets:
      glyph = breakupGlyph(
        at: index,
        pose: pose,
        configuration: configuration
      )
    }

    guard let glyph else {
      return nil
    }

    // Appearance follows the descriptor a glyph was drawn from, while
    // variation follows the glyph slot. Two slots may share a descriptor, and
    // they must look alike but not land on top of each other.
    let descriptorIndex = descriptorIndex(
      at: index,
      pose: pose,
      configuration: configuration
    )
    let variedGlyph = varied(
      styled(
        matchedReferenceGeometry(
          glyph,
          pose: pose,
          index: descriptorIndex,
          style: style
        ),
        pose: pose,
        index: descriptorIndex,
        style: style
      ),
      pose: pose,
      index: index,
      seed: variationSeed
    )

    if style == .classic {
      return variedGlyph
    }

    return boundedGlyph(variedGlyph, limit: drawingLimit(for: style))
  }

  private static func sourceCoverClusterGlyph(
    at index: Int,
    configuration: PoofConfiguration,
    style: PoofStyle,
    variationSeed: UInt64
  ) -> PoofGlyph? {
    guard let glyph = clusterGlyph(at: index) else {
      return nil
    }

    let matchedGlyph = PoofGlyph(
      x: glyph.x * 1.02 - 0.005,
      y: glyph.y * 1.02 + 0.018,
      width: glyph.width * 1.28,
      height: glyph.height * 1.28,
      opacity: glyph.opacity,
      contour: glyph.contour,
      paint: glyph.paint,
      rotation: glyph.rotation,
      tone: glyph.tone
    )
    let variedGlyph = varied(
      styled(
        matchedGlyph,
        pose: .clusters,
        index: index,
        style: style
      ),
      pose: .clusters,
      index: index,
      seed: variationSeed
    )

    return boundedGlyph(variedGlyph, limit: drawingLimit(for: style))
  }

  // MARK: - Opening layouts

  private static func cloudGlyph(at index: Int) -> PoofGlyph? {
    switch index {
    case 0:
      PoofGlyph(
        x: 0,
        y: -0.25,
        width: 0.36,
        height: 0.25,
        rotation: 0.18
      )
    case 1:
      PoofGlyph(
        x: -0.27,
        y: -0.10,
        width: 0.38,
        height: 0.34,
        rotation: 1.12
      )
    case 2:
      PoofGlyph(
        x: 0.27,
        y: -0.10,
        width: 0.38,
        height: 0.34,
        rotation: 2.06
      )
    case 3:
      PoofGlyph(
        x: -0.23,
        y: 0.14,
        width: 0.36,
        height: 0.34,
        rotation: 2.84
      )
    case 4:
      PoofGlyph(
        x: 0.23,
        y: 0.14,
        width: 0.36,
        height: 0.34,
        rotation: 3.62
      )
    case 5:
      PoofGlyph(
        x: 0,
        y: 0.24,
        width: 0.50,
        height: 0.32,
        rotation: 4.40
      )
    case 6:
      PoofGlyph(
        x: 0,
        y: -0.015,
        width: 0.68,
        height: 0.51,
        rotation: 5.18
      )
    default:
      nil
    }
  }

  private static func clusterGlyph(at index: Int) -> PoofGlyph? {
    switch index {
    case 0:
      PoofGlyph(
        x: -0.24,
        y: -0.20,
        width: 0.40,
        height: 0.36,
        rotation: 0.20
      )
    case 1:
      PoofGlyph(
        x: 0.21,
        y: -0.22,
        width: 0.41,
        height: 0.40,
        rotation: 1.04
      )
    case 2:
      PoofGlyph(
        x: -0.21,
        y: 0.18,
        width: 0.42,
        height: 0.38,
        rotation: 1.86,
        tone: .middle
      )
    case 3:
      PoofGlyph(
        x: 0.22,
        y: 0.17,
        width: 0.41,
        height: 0.38,
        rotation: 2.68
      )
    default:
      nil
    }
  }

  // MARK: - Breakup layouts

  private static func breakupCount(
    referenceCount: Int,
    configuration: PoofConfiguration
  ) -> Int {
    min(
      configuration.particleCount,
      max(
        1,
        Int(
          (Double(configuration.particleCount)
            * Double(referenceCount)
            / Double(puffReferences.count)).rounded()
        )
      )
    )
  }

  static func breakupReferences(for pose: PoofPose) -> [PoofGlyph] {
    switch pose {
    case .puffs:
      puffReferences
    case .wisps:
      wispReferences
    case .ringlets:
      ringletReferences
    case .cloud, .clusters:
      []
    }
  }

  /// The measured descriptor a glyph slot is drawn from.
  ///
  /// The breakup poses stretch or repeat their descriptor tables to match
  /// ``PoofConfiguration/particleCount``, so a slot only equals its descriptor
  /// at the default count. Contour, paint, and the measured size calibration
  /// key on this value so they stay attached to the descriptor they were
  /// authored against. Poses without descriptors answer with the slot itself.
  static func descriptorIndex(
    at index: Int,
    pose: PoofPose,
    configuration: PoofConfiguration
  ) -> Int {
    let referenceCount = breakupReferences(for: pose).count
    let count = glyphCount(for: pose, configuration: configuration)

    guard referenceCount > 0, count > 0 else {
      return index
    }

    guard count <= referenceCount else {
      return index % referenceCount
    }

    return min(
      Int(
        (Double(index) + 0.5)
          * Double(referenceCount)
          / Double(count)
      ),
      referenceCount - 1
    )
  }

  private static func breakupGlyph(
    at index: Int,
    pose: PoofPose,
    configuration: PoofConfiguration
  ) -> PoofGlyph? {
    let references = breakupReferences(for: pose)
    let count = glyphCount(for: pose, configuration: configuration)

    guard
      references.isEmpty == false,
      (0..<count).contains(index)
    else {
      return nil
    }

    let reference = references[
      descriptorIndex(
        at: index,
        pose: pose,
        configuration: configuration
      )
    ]
    let spreadScale = configuration.spread / referenceSpread

    guard index >= references.count else {
      return PoofGlyph(
        x: reference.x * spreadScale,
        y: reference.y * spreadScale,
        width: reference.width,
        height: reference.height,
        opacity: reference.opacity,
        contour: reference.contour,
        paint: reference.paint,
        rotation: reference.rotation,
        tone: reference.tone
      )
    }

    let seed = configuration.seed ?? fallbackLayoutSeed
    let key =
      UInt64(pose.rawValue + 1) &* 0x1_0000
      &+ UInt64(index + 1) &* 0x100
    let sizeScale = 1 + noise(seed: seed, key: key &+ 3) * 0.08

    return PoofGlyph(
      x: min(
        max(
          reference.x * spreadScale
            + noise(seed: seed, key: key &+ 1) * 0.025,
          -0.58
        ),
        0.58
      ),
      y: min(
        max(
          reference.y * spreadScale
            + noise(seed: seed, key: key &+ 2) * 0.025,
          -0.58
        ),
        0.58
      ),
      width: reference.width * sizeScale,
      height: reference.height * sizeScale,
      opacity: reference.opacity,
      contour: reference.contour,
      paint: reference.paint,
      rotation: reference.rotation
        + noise(seed: seed, key: key &+ 4) * 0.16,
      tone: reference.tone
    )
  }

  // These ordered, normalized descriptors encode the measured breakup
  // layouts. Their indices also select contour and paint styles below.
  private static let puffReferences: [PoofGlyph] = [
    PoofGlyph(
      x: -0.143,
      y: -0.393,
      width: 0.075,
      height: 0.075,
      rotation: 0.2
    ),
    PoofGlyph(
      x: 0.117,
      y: -0.371,
      width: 0.085,
      height: 0.075,
      rotation: 1.1
    ),
    PoofGlyph(
      x: -0.013,
      y: -0.294,
      width: 0.125,
      height: 0.105,
      rotation: 2.0
    ),
    PoofGlyph(
      x: 0.215,
      y: -0.239,
      width: 0.135,
      height: 0.155,
      rotation: 2.8,
      tone: .middle
    ),
    PoofGlyph(
      x: 0.354,
      y: -0.153,
      width: 0.055,
      height: 0.065,
      rotation: 3.7
    ),
    PoofGlyph(
      x: -0.340,
      y: -0.062,
      width: 0.095,
      height: 0.085,
      rotation: 4.6
    ),
    PoofGlyph(
      x: 0.330,
      y: 0.060,
      width: 0.085,
      height: 0.120,
      rotation: 5.4,
      tone: .middle
    ),
    PoofGlyph(
      x: 0.330,
      y: 0.200,
      width: 0.075,
      height: 0.100,
      rotation: 0.7
    ),
    PoofGlyph(
      x: -0.249,
      y: 0.228,
      width: 0.115,
      height: 0.095,
      rotation: 1.6
    ),
    PoofGlyph(
      x: 0.142,
      y: 0.314,
      width: 0.095,
      height: 0.085,
      rotation: 2.5
    ),
    PoofGlyph(
      x: -0.155,
      y: 0.346,
      width: 0.085,
      height: 0.075,
      rotation: 3.4
    ),
    PoofGlyph(
      x: -0.190,
      y: -0.160,
      width: 0.150,
      height: 0.140,
      rotation: 4.3
    ),
    PoofGlyph(
      x: -0.070,
      y: -0.190,
      width: 0.160,
      height: 0.135,
      rotation: 5.2
    ),
    PoofGlyph(
      x: 0.070,
      y: -0.180,
      width: 0.145,
      height: 0.150,
      rotation: 0.4,
      tone: .middle
    ),
    PoofGlyph(
      x: 0.180,
      y: -0.140,
      width: 0.145,
      height: 0.135,
      rotation: 1.3
    ),
    PoofGlyph(
      x: -0.220,
      y: -0.040,
      width: 0.145,
      height: 0.150,
      rotation: 2.2
    ),
    PoofGlyph(
      x: -0.100,
      y: -0.070,
      width: 0.170,
      height: 0.160,
      rotation: 3.1,
      tone: .middle
    ),
    PoofGlyph(
      x: 0.030,
      y: -0.070,
      width: 0.165,
      height: 0.145,
      rotation: 4.0
    ),
    PoofGlyph(
      x: 0.160,
      y: -0.020,
      width: 0.150,
      height: 0.145,
      rotation: 4.9
    ),
    PoofGlyph(
      x: -0.190,
      y: 0.090,
      width: 0.145,
      height: 0.135,
      rotation: 5.8
    ),
    PoofGlyph(
      x: -0.060,
      y: 0.050,
      width: 0.175,
      height: 0.165,
      rotation: 0.9
    ),
    PoofGlyph(
      x: 0.070,
      y: 0.070,
      width: 0.160,
      height: 0.155,
      rotation: 1.8,
      tone: .middle
    ),
    PoofGlyph(
      x: 0.190,
      y: 0.100,
      width: 0.145,
      height: 0.135,
      rotation: 2.7
    ),
    PoofGlyph(
      x: -0.150,
      y: 0.190,
      width: 0.145,
      height: 0.140,
      rotation: 3.6
    ),
    PoofGlyph(
      x: -0.020,
      y: 0.170,
      width: 0.165,
      height: 0.155,
      rotation: 4.5
    ),
    PoofGlyph(
      x: 0.110,
      y: 0.200,
      width: 0.145,
      height: 0.140,
      rotation: 5.4
    ),
    PoofGlyph(
      x: 0.020,
      y: -0.010,
      width: 0.180,
      height: 0.170,
      rotation: 0.6,
      tone: .dark
    ),
    PoofGlyph(
      x: -0.020,
      y: 0.275,
      width: 0.125,
      height: 0.105,
      rotation: 1.5
    ),
  ]

  private static let wispReferences: [PoofGlyph] = [
    PoofGlyph(
      x: -0.199,
      y: -0.359,
      width: 0.045,
      height: 0.055,
      rotation: 0.1
    ),
    PoofGlyph(
      x: 0.114,
      y: -0.320,
      width: 0.055,
      height: 0.045,
      rotation: 1.0
    ),
    PoofGlyph(
      x: -0.056,
      y: -0.280,
      width: 0.110,
      height: 0.075,
      rotation: 1.9,
      tone: .middle
    ),
    PoofGlyph(
      x: 0.170,
      y: -0.243,
      width: 0.065,
      height: 0.075,
      rotation: 2.8
    ),
    PoofGlyph(
      x: 0.253,
      y: -0.159,
      width: 0.060,
      height: 0.060,
      rotation: 3.7
    ),
    PoofGlyph(
      x: -0.245,
      y: -0.148,
      width: 0.140,
      height: 0.155,
      rotation: 4.6
    ),
    PoofGlyph(
      x: 0.159,
      y: -0.074,
      width: 0.115,
      height: 0.115,
      rotation: 5.5,
      tone: .middle
    ),
    PoofGlyph(
      x: -0.021,
      y: -0.066,
      width: 0.140,
      height: 0.140,
      rotation: 0.7
    ),
    PoofGlyph(
      x: -0.298,
      y: -0.014,
      width: 0.040,
      height: 0.040,
      rotation: 1.6
    ),
    PoofGlyph(
      x: 0.073,
      y: 0.055,
      width: 0.140,
      height: 0.115,
      rotation: 2.5
    ),
    PoofGlyph(
      x: 0.301,
      y: 0.057,
      width: 0.040,
      height: 0.040,
      rotation: 3.4
    ),
    PoofGlyph(
      x: 0.230,
      y: 0.092,
      width: 0.050,
      height: 0.050,
      rotation: 4.3
    ),
    PoofGlyph(
      x: -0.177,
      y: 0.102,
      width: 0.180,
      height: 0.115,
      rotation: 5.2,
      tone: .middle
    ),
    PoofGlyph(
      x: 0.220,
      y: 0.233,
      width: 0.140,
      height: 0.160,
      rotation: 0.4
    ),
    PoofGlyph(
      x: -0.151,
      y: 0.246,
      width: 0.075,
      height: 0.055,
      rotation: 1.3
    ),
    PoofGlyph(
      x: 0.054,
      y: 0.246,
      width: 0.095,
      height: 0.095,
      rotation: 2.2
    ),
    PoofGlyph(
      x: -0.092,
      y: 0.338,
      width: 0.040,
      height: 0.030,
      rotation: 3.1
    ),
    PoofGlyph(
      x: 0.115,
      y: 0.356,
      width: 0.040,
      height: 0.040,
      rotation: 4.0
    ),
  ]

  private static let ringletReferences: [PoofGlyph] = [
    PoofGlyph(
      x: -0.048,
      y: -0.291,
      width: 0.045,
      height: 0.035,
      opacity: 0.96,
      rotation: 0.3
    ),
    PoofGlyph(
      x: 0.206,
      y: -0.260,
      width: 0.035,
      height: 0.045,
      opacity: 0.96,
      rotation: 1.2
    ),
    PoofGlyph(
      x: -0.261,
      y: -0.192,
      width: 0.045,
      height: 0.045,
      opacity: 0.96,
      rotation: 2.1
    ),
    PoofGlyph(
      x: 0.123,
      y: -0.109,
      width: 0.120,
      height: 0.075,
      opacity: 0.96,
      rotation: 3.0
    ),
    PoofGlyph(
      x: -0.171,
      y: -0.104,
      width: 0.095,
      height: 0.095,
      opacity: 0.96,
      rotation: 3.9
    ),
    PoofGlyph(
      x: -0.034,
      y: -0.056,
      width: 0.095,
      height: 0.055,
      opacity: 0.96,
      rotation: 4.8
    ),
    PoofGlyph(
      x: -0.006,
      y: 0.025,
      width: 0.075,
      height: 0.065,
      opacity: 0.96,
      rotation: 5.7,
      tone: .middle
    ),
    PoofGlyph(
      x: -0.237,
      y: 0.083,
      width: 0.045,
      height: 0.045,
      opacity: 0.96,
      rotation: 0.9
    ),
    PoofGlyph(
      x: 0.047,
      y: 0.134,
      width: 0.045,
      height: 0.045,
      opacity: 0.96,
      rotation: 1.8
    ),
    PoofGlyph(
      x: -0.153,
      y: 0.149,
      width: 0.095,
      height: 0.085,
      opacity: 0.96,
      rotation: 2.7
    ),
    PoofGlyph(
      x: 0.267,
      y: 0.215,
      width: 0.035,
      height: 0.045,
      opacity: 0.96,
      rotation: 3.6
    ),
    PoofGlyph(
      x: -0.192,
      y: 0.245,
      width: 0.045,
      height: 0.035,
      opacity: 0.96,
      rotation: 4.5
    ),
    PoofGlyph(
      x: 0.009,
      y: 0.275,
      width: 0.055,
      height: 0.065,
      opacity: 0.96,
      rotation: 5.4
    ),
  ]

  // MARK: - Styling and variation

  private static func styled(
    _ glyph: PoofGlyph,
    pose: PoofPose,
    index descriptorIndex: Int,
    style: PoofStyle
  ) -> PoofGlyph {
    // Keyed on the descriptor index so a given measured descriptor keeps its
    // contour and paint whatever `particleCount` is in play.
    let index = descriptorIndex
    // Every frame of the original is bumpy multi-lobe puffs: no rings, no
    // polygons, no stroked squiggles. Classic smoke is puffs the whole way
    // down and lets size carry the dissipation. The expressive styles below
    // overwrite both of these, so this selection is classic's alone.
    let contour: PoofContour =
      descriptorIndex.isMultiple(of: 2) ? .puff4 : .puff5
    let paint: PoofPaint = .fillAndOutline

    let classicGlyph = PoofGlyph(
      x: glyph.x,
      y: glyph.y,
      width: glyph.width,
      height: glyph.height,
      opacity: glyph.opacity,
      contour: contour,
      paint: paint,
      rotation: glyph.rotation,
      tone: glyph.tone
    )

    switch style {
    case .classic:
      return classicGlyph
    case .bloom:
      return bloomGlyph(classicGlyph, pose: pose, index: index)
    case .snap:
      return snapGlyph(classicGlyph, pose: pose, index: index)
    }
  }

  private static func bloomGlyph(
    _ glyph: PoofGlyph,
    pose: PoofPose,
    index: Int
  ) -> PoofGlyph {
    let positionScale: Double
    let sizeScale: Double

    switch pose {
    case .cloud:
      positionScale = 0.72
      sizeScale = 1.18
    case .clusters:
      positionScale = 0.72
      sizeScale = 1.15
    case .puffs:
      positionScale = 0.88
      sizeScale = 1.44
    case .wisps:
      positionScale = 0.80
      sizeScale = 1.50
    case .ringlets:
      positionScale = 0.72
      sizeScale = 1.58
    }

    let averageSize = (glyph.width + glyph.height) / 2
    let contour: PoofContour
    let paint: PoofPaint

    switch pose {
    case .cloud, .clusters:
      contour = .puff5
      paint = .fillAndOutline
    case .puffs:
      contour =
        index.isMultiple(of: 7)
        ? .ring
        : .puff5
      paint =
        contour == .ring
        ? .fillOutlineAndInset
        : .fillAndOutline
    case .wisps:
      contour = index.isMultiple(of: 3) ? .ring : .puff5
      paint =
        contour == .ring
        ? .fillOutlineAndInset
        : .fillAndOutline
    case .ringlets:
      contour = index.isMultiple(of: 3) ? .curl : .ring
      paint = .doubleStroke
    }

    return PoofGlyph(
      x: glyph.x * positionScale,
      y: glyph.y * positionScale - 0.008,
      width: averageSize * sizeScale,
      height: averageSize * sizeScale,
      opacity: glyph.opacity,
      contour: contour,
      paint: paint,
      rotation: 0,
      tone: index.isMultiple(of: 7) ? .middle : .light
    )
  }

  private static func snapGlyph(
    _ glyph: PoofGlyph,
    pose: PoofPose,
    index: Int
  ) -> PoofGlyph {
    switch pose {
    case .cloud, .clusters:
      let positionScale = pose == .cloud ? 0.55 : 0.68
      let sizeScale = pose == .cloud ? 0.78 : 0.68

      return PoofGlyph(
        x: glyph.x * positionScale,
        y: glyph.y * positionScale,
        width: glyph.width * sizeScale,
        height: glyph.height * sizeScale,
        opacity: glyph.opacity,
        contour: .puff4,
        paint: .fillAndOutline,
        rotation: glyph.rotation,
        tone: index.isMultiple(of: 5) ? .middle : .light
      )
    case .puffs, .wisps, .ringlets:
      let angle = Double(index) * goldenAngle
      let baseRadius = hypot(glyph.x, glyph.y)
      let radius: Double
      let width: Double
      let height: Double

      switch pose {
      case .puffs:
        radius = 0.16 + baseRadius * 0.55
        width = max(glyph.width * 0.72, 0.10)
        height = max(glyph.height * 0.45, 0.045)
      case .wisps:
        radius = 0.29 + baseRadius * 0.48
        width = max(glyph.width * 0.62, 0.082)
        height = max(glyph.height * 0.34, 0.032)
      case .ringlets:
        radius = 0.41 + baseRadius * 0.36
        width = max(glyph.width * 0.52, 0.062)
        height = max(glyph.height * 0.28, 0.024)
      case .cloud, .clusters:
        preconditionFailure("Opening poses return before breakup geometry")
      }

      let contour: PoofContour
      let paint: PoofPaint

      switch (pose, index % 4) {
      case (.puffs, 0), (.puffs, 1):
        contour = index.isMultiple(of: 2) ? .puff4 : .puff5
        paint = .fillAndOutline
      case (.puffs, 2), (.wisps, 0), (.ringlets, 0):
        contour = .fleck
        paint = .fillAndOutline
      case (_, 3), (.wisps, 1), (.ringlets, 1):
        contour = .ring
        paint = .doubleStroke
      default:
        contour = .curl
        paint = .doubleStroke
      }

      return PoofGlyph(
        x: cos(angle) * radius,
        y: sin(angle) * radius,
        width: width,
        height: height,
        opacity: glyph.opacity,
        contour: contour,
        paint: paint,
        rotation: angle,
        tone: index.isMultiple(of: 5) ? .middle : .light
      )
    }
  }

  /// How far a glyph's center plus its extent may reach.
  ///
  /// Derived from the ink itself, so darkening or enlarging the shadow cannot
  /// silently start clipping the artwork.
  private static func drawingLimit(for style: PoofStyle) -> Double {
    switch style {
    case .classic:
      // Classic's positions come from the measured descriptors and are
      // calibrated against the originals; the bound below works on a rotated
      // bounding box, which overstates a puff's reach enough to pull that
      // calibration in. It is left alone.
      .infinity
    case .bloom, .snap:
      0.5 - PoofArtwork.inkOverreach
    }
  }

  private static func boundedGlyph(
    _ glyph: PoofGlyph,
    limit drawingLimit: Double
  ) -> PoofGlyph {
    let renderedHeight =
      glyph.height * (glyph.contour == .curl ? 1.60 : 1)
    let cosine = abs(cos(glyph.rotation))
    let sine = abs(sin(glyph.rotation))
    let halfWidth = glyph.width / 2
    let halfHeight = renderedHeight / 2
    let extentX = halfWidth * cosine + halfHeight * sine
    let extentY = halfWidth * sine + halfHeight * cosine
    let centerLimitX = max(0, drawingLimit - extentX)
    let centerLimitY = max(0, drawingLimit - extentY)
    let scaleX =
      glyph.x == 0 ? 1 : centerLimitX / abs(glyph.x)
    let scaleY =
      glyph.y == 0 ? 1 : centerLimitY / abs(glyph.y)
    let positionScale = min(1, scaleX, scaleY)

    return PoofGlyph(
      x: glyph.x * positionScale,
      y: glyph.y * positionScale,
      width: glyph.width,
      height: glyph.height,
      opacity: glyph.opacity,
      contour: glyph.contour,
      paint: glyph.paint,
      rotation: glyph.rotation,
      tone: glyph.tone
    )
  }

  private static func matchedReferenceGeometry(
    _ glyph: PoofGlyph,
    pose: PoofPose,
    index descriptorIndex: Int,
    style: PoofStyle
  ) -> PoofGlyph {
    // Calibrate the authored vectors to the clean-room measurement envelopes
    // asserted by the rendering tests. `descriptorIndex` addresses the
    // measured tables, not the glyph slot, so the calibration stays attached
    // to the descriptor it was fitted against at any particle count.
    let index = descriptorIndex
    let positionScaleX: Double
    let positionScaleY: Double
    let sizeScaleX: Double
    let sizeScaleY: Double
    let offsetX: Double
    let offsetY: Double

    switch pose {
    case .cloud:
      positionScaleX = 1.15
      positionScaleY = 1.02
      sizeScaleX = 1.24
      sizeScaleY = 1.10
      offsetX = -0.010
      offsetY = -0.040
    case .clusters:
      // Calibration runs before styling, so the expressive styles multiply
      // whatever lands here. They were tuned against the compact second pose
      // and keep it; restoring the measured one is classic's alone.
      positionScaleX = style == .classic ? 1.035 : 0.78
      positionScaleY = style == .classic ? 1.035 : 0.78
      sizeScaleX = style == .classic ? 1.258 : 0.86
      sizeScaleY = style == .classic ? 1.258 : 0.86
      offsetX = -0.005
      offsetY = 0.018
    case .puffs:
      positionScaleX = 1.215
      positionScaleY = 1.060
      sizeScaleX = index < 11 ? 0.693 : 1.425
      sizeScaleY = index < 11 ? 0.693 : 1.425
      offsetX = 0
      offsetY = -0.005
    case .wisps:
      positionScaleX = 1.025
      // The descriptor jitter is clamped to 0.58 before this scale applies,
      // so anything above one here can push a glyph past the sanity bound.
      positionScaleY = 1.000
      sizeScaleX = 1.292
      sizeScaleY = 1.292
      offsetX = -0.018
      offsetY = 0.008
    case .ringlets:
      positionScaleX = 1
      positionScaleY = 1
      sizeScaleX = 1.196
      sizeScaleY = 1.196
      offsetX = -0.010
      offsetY = -0.011
    }

    return PoofGlyph(
      x: glyph.x * positionScaleX + offsetX,
      y: glyph.y * positionScaleY + offsetY,
      width: glyph.width * sizeScaleX,
      height: glyph.height * sizeScaleY,
      opacity: glyph.opacity,
      contour: glyph.contour,
      paint: glyph.paint,
      rotation: glyph.rotation,
      tone: glyph.tone
    )
  }

  private static func sourceCoverLayout(
    seed: UInt64,
    clusterGlyphs: [PoofGlyph],
    aspect: PoofSourceCoverAspect?
  ) -> PoofSourceCoverLayout {
    let geometrySeed = sourceCoverGeometrySeed(for: seed)
    let includesSquare = aspect == nil || aspect == .square
    let includesWide = aspect == nil || aspect == .wide
    let includesTall = aspect == nil || aspect == .tall
    let square =
      includesSquare
      ? organicSourceCoverGlyphs(
        seed: geometrySeed,
        variationSeed: seed,
        clusterGlyphs: clusterGlyphs,
        sourceWidth: 84,
        sourceHeight: 84,
        keyOffset: 0
      )
      : []
    let wide =
      includesWide
      ? organicSourceCoverGlyphs(
        seed: geometrySeed,
        variationSeed: seed,
        clusterGlyphs: clusterGlyphs,
        sourceWidth: 132,
        sourceHeight: 48,
        keyOffset: 0x1_0000
      )
      : []
    let tall =
      includesTall
      ? organicSourceCoverGlyphs(
        seed: geometrySeed,
        variationSeed: seed,
        clusterGlyphs: clusterGlyphs,
        sourceWidth: 48,
        sourceHeight: 132,
        keyOffset: 0x2_0000
      )
      : []

    return PoofSourceCoverLayout(
      square: square,
      wide: wide,
      tall: tall
    )
  }

  private static func organicSourceCoverGlyphs(
    seed: UInt64,
    variationSeed: UInt64,
    clusterGlyphs: [PoofGlyph],
    sourceWidth: Double,
    sourceHeight: Double,
    keyOffset: UInt64
  ) -> [PoofSourceCoverGlyph] {
    let artSide = min(
      max((sourceWidth * sourceHeight).squareRoot(), 42),
      160
    )
    let glyphs = sourceCoverGlyphs(
      seed: seed,
      variationSeed: variationSeed,
      clusterGlyphs: clusterGlyphs,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      artSide: artSide,
      keyOffset: keyOffset
    )
    return sourceCoverGlyphsSizedForCoverage(
      glyphs,
      seed: seed,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      artSide: artSide,
      keyOffset: keyOffset
    )
  }

  private static func sourceCoverGlyphs(
    seed: UInt64,
    variationSeed: UInt64,
    clusterGlyphs: [PoofGlyph],
    sourceWidth: Double,
    sourceHeight: Double,
    artSide: Double,
    keyOffset: UInt64
  ) -> [PoofSourceCoverGlyph] {
    let halfWidth = sourceWidth / 2
    let halfHeight = sourceHeight / 2
    let coverageInset = min(
      artSide * 0.095,
      min(sourceWidth, sourceHeight) * 0.17
    )
    let baseCoverageCount =
      PoofSourceCoverLayout.baseGlyphCount
    let repairEndIndex =
      baseCoverageCount + PoofSourceCoverLayout.repairGlyphCount
    var centers: [(x: Double, y: Double)] = []
    var fringeAnchorIndices: [Int] = []
    var glyphs: [PoofSourceCoverGlyph] = []
    glyphs.reserveCapacity(PoofSourceCoverLayout.glyphCount)

    for index in 0..<PoofSourceCoverLayout.glyphCount {
      let key = keyOffset + UInt64(0x2200 + index * 0x20)
      let center: (x: Double, y: Double)
      let clusterIndex: Int
      let lineageParentIndex: Int?

      if index < PoofSourceCoverLayout.rootGlyphCount {
        clusterIndex = index % max(clusterGlyphs.count, 1)
        lineageParentIndex = nil

        let cluster =
          clusterGlyphs.indices.contains(clusterIndex)
          ? clusterGlyphs[clusterIndex]
          : PoofGlyph(x: 0, y: 0, width: 0.3, height: 0.3)
        let siblingIndex = index / max(clusterGlyphs.count, 1)
        let outwardAngle = atan2(cluster.y, cluster.x)
        let angle =
          outwardAngle
          + (Double(siblingIndex) - 1) * 0.82
          + noise(seed: seed, key: key + 13) * 0.28
        let distance =
          artSide
          * coverUnitNoise(
            seed: seed,
            key: key + 14,
            in: 0.035...0.09
          )

        let candidateX =
          cluster.x * artSide + cos(angle) * distance
        let candidateY =
          cluster.y * artSide + sin(angle) * distance
        center = (
          x: min(
            max(candidateX, -halfWidth + coverageInset),
            halfWidth - coverageInset
          ),
          y: min(
            max(candidateY, -halfHeight + coverageInset),
            halfHeight - coverageInset
          )
        )
      } else if index < baseCoverageCount {
        var bestCandidate = centers[0]
        var bestParentIndex = 0
        var bestScore = -Double.infinity

        // Grow a seeded tree in short overlapping steps. Candidate targets
        // explore the source while the step limit preserves visual lineage.
        for candidateIndex in 0..<96 {
          let candidateKey =
            keyOffset + 0x5000
            + UInt64(index) * 0x1000
            + UInt64(candidateIndex) * 0x20
          let targetX = coverUnitNoise(
            seed: seed,
            key: candidateKey + 2,
            in: (-halfWidth + coverageInset)...(halfWidth - coverageInset)
          )
          let targetY = coverUnitNoise(
            seed: seed,
            key: candidateKey + 3,
            in: (-halfHeight + coverageInset)...(halfHeight - coverageInset)
          )
          // Explicit scan: min(by:) re-measures the incumbent on every
          // comparison, and this runs 96 times per grown glyph. Strict `<`
          // keeps the first nearest, matching min(by:).
          var parentIndex = 0
          var parentSquaredDistance = Double.infinity

          for centerIndex in centers.indices {
            let deltaX = targetX - centers[centerIndex].x
            let deltaY = targetY - centers[centerIndex].y
            let squared = deltaX * deltaX + deltaY * deltaY

            if squared < parentSquaredDistance {
              parentSquaredDistance = squared
              parentIndex = centerIndex
            }
          }

          let parent = centers[parentIndex]
          let targetDistance = hypot(
            targetX - parent.x,
            targetY - parent.y
          )
          guard targetDistance > 0 else {
            continue
          }
          let stepLength = min(
            targetDistance,
            artSide
              * coverUnitNoise(
                seed: seed,
                key: candidateKey + 4,
                in: 0.11...0.19
              )
          )
          let unitX = (targetX - parent.x) / targetDistance
          let unitY = (targetY - parent.y) / targetDistance
          let tangentOffset =
            noise(seed: seed, key: candidateKey + 5)
            * artSide * 0.035
          let candidate = (
            x: min(
              max(
                parent.x + unitX * stepLength - unitY * tangentOffset,
                -halfWidth + coverageInset
              ),
              halfWidth - coverageInset
            ),
            y: min(
              max(
                parent.y + unitY * stepLength + unitX * tangentOffset,
                -halfHeight + coverageInset
              ),
              halfHeight - coverageInset
            )
          )
          let nearestSquaredDistance =
            centers.reduce(Double.infinity) { distance, center in
              let deltaX = candidate.x - center.x
              let deltaY = candidate.y - center.y
              return min(
                distance,
                deltaX * deltaX + deltaY * deltaY
              )
            }
          let nearestDistance = nearestSquaredDistance.squareRoot()
          let score =
            nearestDistance
            * coverUnitNoise(
              seed: seed,
              key: candidateKey + 6,
              in: 0.62...1.38
            )
            + targetDistance * 0.08

          if score > bestScore {
            bestCandidate = candidate
            bestParentIndex =
              centers.indices.min {
                let firstX = candidate.x - centers[$0].x
                let firstY = candidate.y - centers[$0].y
                let secondX = candidate.x - centers[$1].x
                let secondY = candidate.y - centers[$1].y
                return firstX * firstX + firstY * firstY
                  < secondX * secondX + secondY * secondY
              } ?? parentIndex
            bestScore = score
          }
        }

        center = bestCandidate
        lineageParentIndex = bestParentIndex
        clusterIndex = glyphs[bestParentIndex].clusterIndex
      } else {
        let baseParents = Set(
          glyphs.prefix(baseCoverageCount)
            .compactMap(\.lineageParentIndex)
        )
        let leaves =
          (PoofSourceCoverLayout.rootGlyphCount..<baseCoverageCount)
          .filter {
            !baseParents.contains($0)
              && !fringeAnchorIndices.contains($0)
          }
        let availableAnchors =
          leaves.isEmpty
          ? (0..<baseCoverageCount).filter {
            !fringeAnchorIndices.contains($0)
          }
          : leaves
        let anchorIndex =
          availableAnchors.max {
            let first = centers[$0]
            let second = centers[$1]
            let firstReach = max(
              abs(first.x / max(halfWidth, 1)),
              abs(first.y / max(halfHeight, 1))
            )
            let secondReach = max(
              abs(second.x / max(halfWidth, 1)),
              abs(second.y / max(halfHeight, 1))
            )
            let firstScore =
              firstReach
              + noise(seed: seed, key: key + UInt64($0)) * 0.42
            let secondScore =
              secondReach
              + noise(seed: seed, key: key + UInt64($1)) * 0.42
            return firstScore < secondScore
          } ?? 0

        if index >= repairEndIndex {
          fringeAnchorIndices.append(anchorIndex)
        }

        let anchor = centers[anchorIndex]
        let parentIndex =
          glyphs[anchorIndex].lineageParentIndex ?? 0
        let parent = centers[parentIndex]
        let branchX =
          index < repairEndIndex
          ? anchor.x - parent.x
          : anchor.x
        let branchY =
          index < repairEndIndex
          ? anchor.y - parent.y
          : anchor.y
        let branchLength = max(hypot(branchX, branchY), 0.001)
        let unitX = branchX / branchLength
        let unitY = branchY / branchLength
        let outwardDistance =
          artSide
          * coverUnitNoise(
            seed: seed,
            key: key + 15,
            in:
              index < repairEndIndex
              ? 0.04...0.085
              : 0.02...0.08
          )
        let tangentScale: Double

        if index < repairEndIndex {
          tangentScale =
            noise(seed: seed, key: key + 16) * 0.035
        } else {
          tangentScale =
            noise(seed: seed, key: key + 16) * 0.025
        }
        let tangentDistance = tangentScale * artSide

        center = (
          x:
            anchor.x + unitX * outwardDistance
            - unitY * tangentDistance,
          y:
            anchor.y + unitY * outwardDistance
            + unitX * tangentDistance
        )
        lineageParentIndex = anchorIndex
        clusterIndex = glyphs[anchorIndex].clusterIndex
      }

      let sizeRange: ClosedRange<Double> =
        if index < baseCoverageCount {
          0.18...0.29
        } else if index < repairEndIndex {
          0.13...0.21
        } else {
          0.15...0.29
        }
      let size =
        artSide
        * coverUnitNoise(
          seed: seed,
          key: key + 2,
          in: sizeRange
        )
      let aspect = coverUnitNoise(
        seed: seed,
        key: key + 3,
        in: 0.94...1.06
      )
      let width = size * aspect
      let height = size / aspect
      let tone: PoofTone =
        noise(seed: variationSeed, key: key + 5) > 0.58
        ? .middle
        : .light
      let hueIndex = min(
        Int(
          coverUnitNoise(
            seed: variationSeed,
            key: key + 7,
            in: 0...3.999
          )
        ),
        3
      )

      glyphs.append(
        PoofSourceCoverGlyph(
          x: center.x / sourceWidth,
          y: center.y / sourceHeight,
          width: width / sourceWidth,
          height: height / sourceHeight,
          rotation:
            Double(index) * 0.83
            + noise(seed: seed, key: key + 6) * 0.45,
          contour: index.isMultiple(of: 3) ? .puff5 : .puff4,
          tone: tone,
          paletteIndex: (hueIndex - tone.rawValue + 4) % 4,
          clusterIndex: clusterIndex,
          lineageParentIndex: lineageParentIndex
        )
      )
      centers.append(center)
    }

    return glyphs
  }

  private static func warpedSourceCoverGlyphs(
    _ glyphs: [PoofSourceCoverGlyph],
    seed: UInt64,
    sourceWidth: Double,
    sourceHeight: Double,
    artSide: Double,
    keyOffset: UInt64
  ) -> [PoofSourceCoverGlyph] {
    let halfWidth = sourceWidth / 2
    let halfHeight = sourceHeight / 2
    let phaseX = coverUnitNoise(
      seed: seed,
      key: keyOffset + 0xA100,
      in: 0...(2 * .pi)
    )
    let phaseY = coverUnitNoise(
      seed: seed,
      key: keyOffset + 0xA200,
      in: 0...(2 * .pi)
    )
    let phaseDiagonal = coverUnitNoise(
      seed: seed,
      key: keyOffset + 0xA300,
      in: 0...(2 * .pi)
    )
    let maximumCoordinateX = halfWidth + artSide * 0.13
    let maximumCoordinateY = halfHeight + artSide * 0.13

    return glyphs.map { glyph in
      let x = glyph.x * sourceWidth
      let y = glyph.y * sourceHeight
      let normalizedX = x / max(halfWidth, 1)
      let normalizedY = y / max(halfHeight, 1)
      let normalizedReach = min(
        max(abs(normalizedX), abs(normalizedY)),
        1
      )
      let edgeProgress = min(
        max((normalizedReach - 0.42) / 0.58, 0),
        1
      )
      let edgeWeight =
        edgeProgress * edgeProgress * (3 - 2 * edgeProgress)
      let angle = atan2(normalizedY, normalizedX)
      let radialLobe = min(
        max(
          0.58
            + sin(angle * 3 + phaseX) * 0.25
            + sin(angle * 5 + phaseY) * 0.12
            + sin(angle * 2 + phaseDiagonal) * 0.08,
          0.08
        ),
        1
      )
      let tangentialWave =
        sin(angle * 2 + phaseDiagonal) * 0.22
      let directionX = cos(angle)
      let directionY = sin(angle)
      let sourceAspect = sourceWidth / sourceHeight
      let roundsSquareSource =
        (0.75...1.33).contains(sourceAspect)
      let sourceEdgeRadius = min(
        halfWidth / max(abs(directionX), 0.001),
        halfHeight / max(abs(directionY), 0.001)
      )
      // A square needs about 21% radial overscan to fit inside a round cloud.
      // Vary that minimum by seed so the result does not become a circle.
      let roundedEnvelopeRadius =
        hypot(halfWidth, halfHeight) + artSide * 0.01
      let roundingOffset =
        roundsSquareSource
        ? max(roundedEnvelopeRadius - sourceEdgeRadius, 0)
          * (0.38 + radialLobe * 0.22)
        : 0
      let radialOffset =
        edgeWeight
        * (artSide * (0.006 + 0.035 * radialLobe)
          + roundingOffset)
      let tangentialOffset =
        artSide * 0.025 * edgeWeight * tangentialWave
      let warpedX = min(
        max(
          x + directionX * radialOffset - directionY * tangentialOffset,
          -maximumCoordinateX
        ),
        maximumCoordinateX
      )
      let warpedY = min(
        max(
          y + directionY * radialOffset + directionX * tangentialOffset,
          -maximumCoordinateY
        ),
        maximumCoordinateY
      )

      return PoofSourceCoverGlyph(
        x: warpedX / sourceWidth,
        y: warpedY / sourceHeight,
        width: glyph.width,
        height: glyph.height,
        rotation: glyph.rotation,
        contour: glyph.contour,
        tone: glyph.tone,
        paletteIndex: glyph.paletteIndex,
        clusterIndex: glyph.clusterIndex,
        lineageParentIndex: glyph.lineageParentIndex
      )
    }
  }

  private static func sourceCoverGlyphsSizedForCoverage(
    _ glyphs: [PoofSourceCoverGlyph],
    seed: UInt64,
    sourceWidth: Double,
    sourceHeight: Double,
    artSide: Double,
    keyOffset: UInt64
  ) -> [PoofSourceCoverGlyph] {
    let repairStartIndex =
      PoofSourceCoverLayout.baseGlyphCount
    let fringeStartIndex =
      repairStartIndex + PoofSourceCoverLayout.repairGlyphCount
    var resolvedGlyphs = glyphs

    for repairIndex in repairStartIndex..<fringeStartIndex {
      let gap = largestSourceCoverGap(
        among: resolvedGlyphs.prefix(repairIndex),
        seed: seed,
        key: keyOffset + UInt64(repairIndex) * 0x100,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        artSide: artSide
      )
      let repairInset = min(
        artSide * 0.09,
        min(sourceWidth, sourceHeight) * 0.18
      )
      // Keep repairs away from the exact source edge. Their puff paths still
      // cover it without creating a row of boundary-clamped centers.
      let repairCenter = (
        x: min(
          max(gap.x, -sourceWidth / 2 + repairInset),
          sourceWidth / 2 - repairInset
        ),
        y: min(
          max(gap.y, -sourceHeight / 2 + repairInset),
          sourceHeight / 2 - repairInset
        )
      )
      let parentIndex =
        (0..<repairIndex).min {
          let first = resolvedGlyphs[$0]
          let second = resolvedGlyphs[$1]
          return hypot(
            repairCenter.x - sourceWidth * first.x,
            repairCenter.y - sourceHeight * first.y
          )
            < hypot(
              repairCenter.x - sourceWidth * second.x,
              repairCenter.y - sourceHeight * second.y
            )
        } ?? 0
      let glyph = resolvedGlyphs[repairIndex]
      let currentWidth = sourceWidth * glyph.width
      let currentHeight = sourceHeight * glyph.height
      let aspect = max(
        (currentWidth / currentHeight).squareRoot(),
        0.001
      )
      let size = max(
        (currentWidth * currentHeight).squareRoot(),
        artSide * 0.22
      )

      resolvedGlyphs[repairIndex] = PoofSourceCoverGlyph(
        x: repairCenter.x / sourceWidth,
        y: repairCenter.y / sourceHeight,
        width: size * aspect / sourceWidth,
        height: size / aspect / sourceHeight,
        rotation: glyph.rotation,
        contour: glyph.contour,
        tone: glyph.tone,
        paletteIndex: glyph.paletteIndex,
        clusterIndex: resolvedGlyphs[parentIndex].clusterIndex,
        lineageParentIndex: parentIndex
      )
    }

    let warpedGlyphs = warpedSourceCoverGlyphs(
      resolvedGlyphs,
      seed: seed,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      artSide: artSide,
      keyOffset: keyOffset
    )
    let fullySizedGlyphs = sizedSourceCoverGlyphs(
      warpedGlyphs,
      coverageCount: fringeStartIndex,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      artSide: artSide
    )

    return fullySizedGlyphs
  }

  /// The radius each covering glyph must reach so no grid cell is left bare.
  static func sourceCoverageRadii(
    _ glyphs: [PoofSourceCoverGlyph],
    coverageCount: Int,
    sourceWidth: Double,
    sourceHeight: Double,
    artSide: Double
  ) -> [Double] {
    let cellSide = max(artSide * 0.02, 1)
    let columnCount = max(Int(ceil(sourceWidth / cellSide)), 1)
    let rowCount = max(Int(ceil(sourceHeight / cellSide)), 1)
    let cellWidth = sourceWidth / Double(columnCount)
    let cellHeight = sourceHeight / Double(rowCount)
    let halfCellDiagonal = hypot(cellWidth, cellHeight) / 2
    var requiredRadii = [Double](
      repeating: 0,
      count: glyphs.count
    )

    for row in 0..<rowCount {
      for column in 0..<columnCount {
        let cellCenterX =
          -sourceWidth / 2
          + (Double(column) + 0.5) * cellWidth
        let cellCenterY =
          -sourceHeight / 2
          + (Double(row) + 0.5) * cellHeight
        // One pass, one hypot per surviving candidate, keeping the first
        // minimum exactly as Sequence.min(by:) does. The squared prefilter
        // orders candidates identically to hypot, with a one-sided margin so
        // it can only cost an extra hypot, never discard the true nearest.
        var nearestIndex = 0
        var nearestDistance = Double.infinity
        var nearestSquaredBound = Double.infinity

        for index in 0..<coverageCount {
          let glyph = glyphs[index]
          let deltaX = cellCenterX - sourceWidth * glyph.x
          let deltaY = cellCenterY - sourceHeight * glyph.y
          let squared = deltaX * deltaX + deltaY * deltaY

          if squared > nearestSquaredBound {
            continue
          }

          let distance = hypot(deltaX, deltaY)

          if distance < nearestDistance {
            nearestIndex = index
            nearestDistance = distance
            nearestSquaredBound = squared * (1 + 1e-12)
          }
        }

        let farthestDistance =
          (coverageCount > 0
            ? nearestDistance
            : hypot(
              cellCenterX - sourceWidth * glyphs[0].x,
              cellCenterY - sourceHeight * glyphs[0].y
            ))
          + halfCellDiagonal
        requiredRadii[nearestIndex] = max(
          requiredRadii[nearestIndex],
          farthestDistance
        )
      }
    }

    return requiredRadii
  }

  static func sizedSourceCoverGlyphs(
    _ glyphs: [PoofSourceCoverGlyph],
    coverageCount: Int,
    sourceWidth: Double,
    sourceHeight: Double,
    artSide: Double
  ) -> [PoofSourceCoverGlyph] {
    let requiredRadii = sourceCoverageRadii(
      glyphs,
      coverageCount: coverageCount,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      artSide: artSide
    )

    return zip(glyphs, requiredRadii).enumerated().map {
      index,
      pair in
      let (glyph, radius) = pair
      let currentWidth = sourceWidth * glyph.width
      let currentHeight = sourceHeight * glyph.height
      let aspect = max(
        (currentWidth / currentHeight).squareRoot(),
        0.001
      )
      let minorScale = min(aspect, 1 / aspect)
      let currentSize = (currentWidth * currentHeight).squareRoot()
      let coverageSize =
        radius / (0.30 * minorScale)
      let size =
        if index < coverageCount {
          min(
            max(currentSize, coverageSize),
            artSide * 0.40
          )
        } else {
          currentSize
        }
      let width = size * aspect
      let height = size / aspect

      return PoofSourceCoverGlyph(
        x: glyph.x,
        y: glyph.y,
        width: width / sourceWidth,
        height: height / sourceHeight,
        rotation: glyph.rotation,
        contour: glyph.contour,
        tone: glyph.tone,
        paletteIndex: glyph.paletteIndex,
        clusterIndex: glyph.clusterIndex,
        lineageParentIndex: glyph.lineageParentIndex
      )
    }
  }

  static func largestSourceCoverGap(
    among glyphs: ArraySlice<PoofSourceCoverGlyph>,
    seed: UInt64,
    key: UInt64,
    sourceWidth: Double,
    sourceHeight: Double,
    artSide: Double
  ) -> (x: Double, y: Double) {
    let cellSide = max(artSide * 0.02, 1)
    let columnCount = max(Int(ceil(sourceWidth / cellSide)), 1)
    let rowCount = max(Int(ceil(sourceHeight / cellSide)), 1)
    let cellWidth = sourceWidth / Double(columnCount)
    let cellHeight = sourceHeight / Double(rowCount)
    // Parallel arrays keep the inner scan free of tuple loads.
    var discX = [Double]()
    var discY = [Double]()
    var discRadius = [Double]()
    discX.reserveCapacity(glyphs.count)
    discY.reserveCapacity(glyphs.count)
    discRadius.reserveCapacity(glyphs.count)

    for glyph in glyphs {
      discX.append(sourceWidth * glyph.x)
      discY.append(sourceHeight * glyph.y)
      discRadius.append(
        min(
          sourceWidth * glyph.width,
          sourceHeight * glyph.height
        ) * 0.30
      )
    }

    let originX = -sourceWidth / 2
    let originY = -sourceHeight / 2
    var largestGap = (x: 0.0, y: 0.0)
    var largestDeficit = -Double.infinity

    for row in 0..<rowCount {
      for column in 0..<columnCount {
        let cellKey =
          key + UInt64(row * columnCount + column) * 0x10
        let point = (
          x:
            originX
            + (Double(column)
              + coverUnitNoise(
                seed: seed,
                key: cellKey + 1,
                in: 0.28...0.72
              )) * cellWidth,
          y:
            originY
            + (Double(row)
              + coverUnitNoise(
                seed: seed,
                key: cellKey + 2,
                in: 0.28...0.72
              )) * cellHeight
        )
        var deficit = Double.infinity
        var isPruned = false

        for discIndex in discRadius.indices {
          // The score below scales the final deficit by a factor bounded to
          // 0.96...1.04, and the deficit only falls as discs are scanned, so
          // the running value bounds this cell's best possible score. Once
          // that bound cannot beat the winner the cell is settled. Skipping
          // the remaining work is exact because the noise is counter-based:
          // an undrawn value leaves no state behind.
          let bound =
            deficit >= 0
            ? deficit * 1.04
            : deficit * 0.96

          if bound <= largestDeficit {
            isPruned = true
            break
          }

          let reach = deficit + discRadius[discIndex]

          guard reach > 0 else {
            continue
          }

          let deltaX = point.x - discX[discIndex]
          let deltaY = point.y - discY[discIndex]
          let squared = deltaX * deltaX + deltaY * deltaY

          // Squared distance orders the discs identically to hypot. The
          // margin keeps the comparison one-sided, so the filter can only
          // cost an extra hypot, never skip a disc that would have won.
          if squared > reach * reach * (1 + 1e-12) {
            continue
          }

          deficit = min(
            deficit,
            hypot(deltaX, deltaY) - discRadius[discIndex]
          )
        }

        guard !isPruned else {
          continue
        }

        let score =
          deficit
          * coverUnitNoise(
            seed: seed,
            key: cellKey + 3,
            in: 0.96...1.04
          )

        if score > largestDeficit {
          largestGap = point
          largestDeficit = score
        }
      }
    }

    return largestGap
  }

  static func coverUnitNoise(
    seed: UInt64,
    key: UInt64,
    in range: ClosedRange<Double>
  ) -> Double {
    PoofNoise.value(seed: seed, key: key, in: range)
  }

  private static func sourceCoverGeometrySeed(
    for seed: UInt64
  ) -> UInt64 {
    // Every seed maps to one of the geometry profiles exhaustively exercised
    // by the coverage tests.
    let profile =
      seed % UInt64(sourceCoverGeometryProfileCount)
    return fallbackLayoutSeed
      &+ profile &* 0x9E37_79B9_7F4A_7C15
  }

  private static func varied(
    _ glyph: PoofGlyph,
    pose: PoofPose,
    index: Int,
    seed: UInt64
  ) -> PoofGlyph {
    let isOpeningPose =
      pose == .cloud
      || pose == .clusters
    let rotationAmplitude = isOpeningPose ? 0.004 : 0.035
    let translationAmplitude = isOpeningPose ? 0.002 : 0.010
    let positionJitterAmplitude = isOpeningPose ? 0.001 : 0.006
    let sizeVariationAmplitude = isOpeningPose ? 0.006 : 0.03
    let glyphRotationAmplitude = isOpeningPose ? 0.012 : 0.10
    let rotation = noise(seed: seed, key: 1) * rotationAmplitude
    let translationX =
      noise(seed: seed, key: 2) * translationAmplitude
    let translationY =
      noise(seed: seed, key: 3) * translationAmplitude
    let cosine = cos(rotation)
    let sine = sin(rotation)
    let rotatedX = glyph.x * cosine - glyph.y * sine
    let rotatedY = glyph.x * sine + glyph.y * cosine
    let poseKey =
      switch pose {
      case .cloud, .clusters:
        UInt64(pose.rawValue + 1) &* 0x100
      case .puffs, .wisps, .ringlets:
        // Shared keys carry each glyph's variation through every breakup pose.
        UInt64(0x500)
      }
    let key = poseKey &+ UInt64(index + 1) &* 0x10
    let positionJitterX =
      noise(seed: seed, key: key &+ 1) * positionJitterAmplitude
    let positionJitterY =
      noise(seed: seed, key: key &+ 2) * positionJitterAmplitude
    let sizeVariation =
      1
      + noise(seed: seed, key: key &+ 3)
      * sizeVariationAmplitude
    let rotationVariation =
      noise(seed: seed, key: key &+ 4)
      * glyphRotationAmplitude

    return PoofGlyph(
      x: rotatedX + translationX + positionJitterX,
      y: rotatedY + translationY + positionJitterY,
      width: glyph.width * sizeVariation,
      height: glyph.height * sizeVariation,
      opacity: glyph.opacity,
      contour: glyph.contour,
      paint: glyph.paint,
      rotation: glyph.rotation + rotationVariation,
      tone: glyph.tone
    )
  }

  private static func noise(seed: UInt64, key: UInt64) -> Double {
    PoofNoise.value(seed: seed, key: key)
  }

  private static func normalized(_ value: Double) -> Double {
    if value.isNaN || value == -.infinity {
      return 0
    }

    if value == .infinity {
      return 1
    }

    return min(max(value, 0), 1)
  }
}
