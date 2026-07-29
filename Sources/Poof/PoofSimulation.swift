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

struct PoofFrameSet: Sendable {
  let configuration: PoofConfiguration
  private let poses: [[PoofGlyph]]

  init(
    configuration: PoofConfiguration,
    poses: [[PoofGlyph]]
  ) {
    self.configuration = configuration
    self.poses = poses
  }

  func glyphs(for pose: PoofPose) -> [PoofGlyph] {
    poses[pose.rawValue]
  }
}

enum PoofSimulation {
  static let frameDuration = 1.0 / 15.0
  static let duration = frameDuration * Double(PoofPose.allCases.count)

  static func makeFrameSet(
    configuration: PoofConfiguration,
    variationSeed: UInt64
  ) -> PoofFrameSet {
    let poses = PoofPose.allCases.map { pose in
      (0..<glyphCount(for: pose, configuration: configuration))
        .compactMap { index in
          glyph(
            at: index,
            pose: pose,
            configuration: configuration,
            variationSeed: variationSeed
          )
        }
    }

    return PoofFrameSet(
      configuration: configuration,
      poses: poses
    )
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

    return varied(
      styled(glyph, pose: pose, index: index),
      pose: pose,
      index: index,
      seed: variationSeed
    )
  }

  private static func cloudGlyph(at index: Int) -> PoofGlyph? {
    switch index {
    case 0:
      PoofGlyph(
        x: 0,
        y: -0.25,
        width: 0.36,
        height: 0.25,
        opacity: 1,
        rotation: 0.18,
        tone: .light
      )
    case 1:
      PoofGlyph(
        x: -0.27,
        y: -0.10,
        width: 0.38,
        height: 0.34,
        opacity: 1,
        rotation: 1.12,
        tone: .light
      )
    case 2:
      PoofGlyph(
        x: 0.27,
        y: -0.10,
        width: 0.38,
        height: 0.34,
        opacity: 1,
        rotation: 2.06,
        tone: .light
      )
    case 3:
      PoofGlyph(
        x: -0.23,
        y: 0.14,
        width: 0.36,
        height: 0.34,
        opacity: 1,
        rotation: 2.84,
        tone: .light
      )
    case 4:
      PoofGlyph(
        x: 0.23,
        y: 0.14,
        width: 0.36,
        height: 0.34,
        opacity: 1,
        rotation: 3.62,
        tone: .light
      )
    case 5:
      PoofGlyph(
        x: 0,
        y: 0.24,
        width: 0.50,
        height: 0.32,
        opacity: 1,
        rotation: 4.40,
        tone: .light
      )
    case 6:
      PoofGlyph(
        x: 0,
        y: -0.015,
        width: 0.68,
        height: 0.51,
        opacity: 1,
        rotation: 5.18,
        tone: .light
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
        opacity: 1,
        rotation: 0.20,
        tone: .light
      )
    case 1:
      PoofGlyph(
        x: 0.21,
        y: -0.22,
        width: 0.41,
        height: 0.40,
        opacity: 1,
        rotation: 1.04,
        tone: .light
      )
    case 2:
      PoofGlyph(
        x: -0.21,
        y: 0.18,
        width: 0.42,
        height: 0.38,
        opacity: 1,
        rotation: 1.86,
        tone: .middle
      )
    case 3:
      PoofGlyph(
        x: 0.22,
        y: 0.17,
        width: 0.41,
        height: 0.38,
        opacity: 1,
        rotation: 2.68,
        tone: .light
      )
    default:
      nil
    }
  }

  private static func breakupCount(
    referenceCount: Int,
    configuration: PoofConfiguration
  ) -> Int {
    max(
      1,
      Int(
        (Double(configuration.particleCount)
          * Double(referenceCount)
          / Double(puffReferences.count)).rounded()
      )
    )
  }

  private static func breakupGlyph(
    at index: Int,
    pose: PoofPose,
    configuration: PoofConfiguration
  ) -> PoofGlyph? {
    let references: [PoofGlyph] =
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
    let count = glyphCount(for: pose, configuration: configuration)

    guard
      references.isEmpty == false,
      (0..<count).contains(index)
    else {
      return nil
    }

    let referenceIndex =
      if count <= references.count {
        min(
          Int(
            (Double(index) + 0.5)
              * Double(references.count)
              / Double(count)
          ),
          references.count - 1
        )
      } else {
        index % references.count
      }
    let reference = references[referenceIndex]
    let spreadScale = configuration.spread / 0.82

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

    let seed = configuration.seed ?? 0x504F_4F46
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

  private static func styled(
    _ glyph: PoofGlyph,
    pose: PoofPose,
    index: Int
  ) -> PoofGlyph {
    let contour: PoofContour
    let paint: PoofPaint

    switch pose {
    case .cloud:
      contour = index.isMultiple(of: 2) ? .puff4 : .puff5
      paint = .fillAndOutline
    case .clusters:
      contour =
        [PoofContour.puff4, .puff5, .puff5, .puff4][
          index % 4
        ]
      paint = .fillAndOutline
    case .puffs:
      switch index % 8 {
      case 0, 1:
        contour = .puff4
        paint = .fillAndOutline
      case 2, 3, 4:
        contour = .puff5
        paint = .fillAndOutline
      case 5:
        contour = .ring
        paint = .fillOutlineAndInset
      case 6:
        contour = .curl
        paint = .doubleStroke
      default:
        contour = .fleck
        paint = .fillAndOutline
      }
    case .wisps:
      switch index % 8 {
      case 0, 1, 2:
        contour = index.isMultiple(of: 2) ? .puff4 : .puff5
        paint = .fillAndOutline
      case 3, 4:
        contour = .ring
        paint = .fillOutlineAndInset
      case 5:
        contour = .curl
        paint = .doubleStroke
      default:
        contour = .fleck
        paint = .fillAndOutline
      }
    case .ringlets:
      switch index % 8 {
      case 3:
        contour = .puff4
        paint = .fillAndOutline
      case 4:
        contour = .ring
        paint = .doubleStroke
      case 5:
        contour = .curl
        paint = .doubleStroke
      default:
        contour = .fleck
        paint = .fillAndOutline
      }
    }

    return PoofGlyph(
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
    var random = SplitMix64(
      seed: seed
        ^ (key &* 0xD6E8_FEB8_6659_FD93)
    )
    return random.value(in: -1...1)
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

private struct SplitMix64 {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func value(in range: ClosedRange<Double>) -> Double {
    let upperBits = next() >> 11
    let unit = Double(upperBits) * 0x1.0p-53
    return range.lowerBound
      + (range.upperBound - range.lowerBound) * unit
  }

  private mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }
}
