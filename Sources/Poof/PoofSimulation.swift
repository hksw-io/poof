import Foundation

enum PoofPose: Int, CaseIterable, Sendable {
  case cloud
  case clusters
  case puffs
  case wisps
  case ringlets
}

struct PoofParticle: Hashable, Sendable {
  enum Tone: Int, Hashable, Sendable {
    case light
    case middle
    case dark
  }

  let directionX: Double
  let directionY: Double
  let distance: Double
  let diameter: Double
  let aspectRatio: Double
  let lobeCount: Int
  let phase: Double
  let lastPose: PoofPose
  let tone: Tone
}

struct PoofGlyph: Equatable, Sendable {
  let x: Double
  let y: Double
  let width: Double
  let height: Double
  let opacity: Double
  let lobeCount: Int
  let phase: Double
  let tone: PoofParticle.Tone
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

  static func makeParticles(
    count: Int,
    spread: Double,
    seed: UInt64
  ) -> [PoofParticle] {
    (0..<count).map { index in
      makeParticle(
        at: index,
        count: count,
        spread: spread,
        seed: seed
      )
    }
  }

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
    case .puffs, .wisps, .ringlets:
      configuration.particles.count
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
      guard configuration.particles.indices.contains(index) else {
        return nil
      }

      glyph = particleGlyph(
        configuration.particles[index],
        pose: pose
      )
    }

    guard let glyph else {
      return nil
    }

    return varied(
      glyph,
      pose: pose,
      index: index,
      seed: variationSeed
    )
  }

  private static func makeParticle(
    at index: Int,
    count: Int,
    spread: Double,
    seed: UInt64
  ) -> PoofParticle {
    var random = SplitMix64(
      seed: seed
        &+ UInt64(index + 1) &* 0x9E37_79B9_7F4A_7C15
    )
    let slot = Double(index) / Double(count)
    let angle =
      2 * Double.pi
      * (slot
        + random.value(in: -0.42...0.42) / Double(count))
    let longevity = random.value(in: 0...1)
    let lastPose: PoofPose =
      if longevity < 0.28 {
        .puffs
      } else if longevity < 0.54 {
        .wisps
      } else {
        .ringlets
      }
    let toneValue = random.value(in: 0...1)
    let tone: PoofParticle.Tone =
      if toneValue < 0.56 {
        .light
      } else if toneValue < 0.86 {
        .middle
      } else {
        .dark
      }
    let radialJitter =
      random.value(in: -0.35...0.35) / Double(count)
    let radialSample = min(
      max(radicalInverse(index + 1) + radialJitter, 0.01),
      0.99
    )

    return PoofParticle(
      directionX: cos(angle),
      directionY: sin(angle),
      distance: spread * pow(radialSample, 0.82) * 0.48,
      diameter: random.value(in: 0.05...0.24),
      aspectRatio: random.value(in: 0.88...1.12),
      lobeCount: Int(random.value(in: 4...6.999)),
      phase: random.value(in: 0...(2 * Double.pi)),
      lastPose: lastPose,
      tone: tone
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
        lobeCount: 5,
        phase: 0.18,
        tone: .light
      )
    case 1:
      PoofGlyph(
        x: -0.27,
        y: -0.10,
        width: 0.38,
        height: 0.34,
        opacity: 1,
        lobeCount: 5,
        phase: 1.12,
        tone: .light
      )
    case 2:
      PoofGlyph(
        x: 0.27,
        y: -0.10,
        width: 0.38,
        height: 0.34,
        opacity: 1,
        lobeCount: 5,
        phase: 2.06,
        tone: .light
      )
    case 3:
      PoofGlyph(
        x: -0.23,
        y: 0.14,
        width: 0.36,
        height: 0.34,
        opacity: 1,
        lobeCount: 5,
        phase: 2.84,
        tone: .light
      )
    case 4:
      PoofGlyph(
        x: 0.23,
        y: 0.14,
        width: 0.36,
        height: 0.34,
        opacity: 1,
        lobeCount: 5,
        phase: 3.62,
        tone: .light
      )
    case 5:
      PoofGlyph(
        x: 0,
        y: 0.24,
        width: 0.50,
        height: 0.32,
        opacity: 1,
        lobeCount: 6,
        phase: 4.40,
        tone: .light
      )
    case 6:
      PoofGlyph(
        x: 0,
        y: -0.015,
        width: 0.68,
        height: 0.51,
        opacity: 1,
        lobeCount: 8,
        phase: 5.18,
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
        lobeCount: 6,
        phase: 0.20,
        tone: .light
      )
    case 1:
      PoofGlyph(
        x: 0.21,
        y: -0.22,
        width: 0.41,
        height: 0.40,
        opacity: 1,
        lobeCount: 6,
        phase: 1.04,
        tone: .light
      )
    case 2:
      PoofGlyph(
        x: -0.21,
        y: 0.18,
        width: 0.42,
        height: 0.38,
        opacity: 1,
        lobeCount: 6,
        phase: 1.86,
        tone: .middle
      )
    case 3:
      PoofGlyph(
        x: 0.22,
        y: 0.17,
        width: 0.41,
        height: 0.38,
        opacity: 1,
        lobeCount: 6,
        phase: 2.68,
        tone: .light
      )
    default:
      nil
    }
  }

  private static func particleGlyph(
    _ particle: PoofParticle,
    pose: PoofPose
  ) -> PoofGlyph? {
    let positionScaleX: Double
    let positionScaleY: Double
    let sizeScale: Double
    let opacity: Double
    let xOffset: Double
    let yOffset: Double

    switch pose {
    case .puffs:
      positionScaleX = 1.30
      positionScaleY = 1.11
      sizeScale = 0.78
      opacity = 1
      xOffset = 0
      yOffset = 0
    case .wisps:
      guard particle.lastPose.rawValue >= PoofPose.wisps.rawValue else {
        return nil
      }

      positionScaleX = 0.92
      positionScaleY = 1.04
      sizeScale = 0.50
      opacity = 1
      xOffset = -0.01
      yOffset = 0.015
    case .ringlets:
      guard particle.lastPose == .ringlets else {
        return nil
      }

      positionScaleX = 1.25
      positionScaleY = 0.90
      sizeScale = 0.31
      opacity = 0.96
      xOffset = -0.04
      yOffset = 0.015
    case .cloud, .clusters:
      return nil
    }

    let x =
      particle.directionX * particle.distance * positionScaleX
      + xOffset
    let y =
      particle.directionY * particle.distance * positionScaleY
      + yOffset

    return PoofGlyph(
      x: min(max(x, -0.58), 0.58),
      y: min(max(y, -0.58), 0.58),
      width: particle.diameter * particle.aspectRatio * sizeScale,
      height: particle.diameter / particle.aspectRatio * sizeScale,
      opacity: opacity,
      lobeCount: particle.lobeCount,
      phase: particle.phase,
      tone: particle.tone
    )
  }

  private static func varied(
    _ glyph: PoofGlyph,
    pose: PoofPose,
    index: Int,
    seed: UInt64
  ) -> PoofGlyph {
    let rotation = noise(seed: seed, key: 1) * 0.035
    let translationX = noise(seed: seed, key: 2) * 0.010
    let translationY = noise(seed: seed, key: 3) * 0.010
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
    let positionJitterX = noise(seed: seed, key: key &+ 1) * 0.006
    let positionJitterY = noise(seed: seed, key: key &+ 2) * 0.006
    let sizeVariation = 1 + noise(seed: seed, key: key &+ 3) * 0.03
    let phaseVariation = noise(seed: seed, key: key &+ 4) * 0.10

    return PoofGlyph(
      x: rotatedX + translationX + positionJitterX,
      y: rotatedY + translationY + positionJitterY,
      width: glyph.width * sizeVariation,
      height: glyph.height * sizeVariation,
      opacity: glyph.opacity,
      lobeCount: glyph.lobeCount,
      phase: glyph.phase + phaseVariation,
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

  private static func radicalInverse(_ value: Int) -> Double {
    var value = value
    var result = 0.0
    var place = 0.5

    while value > 0 {
      if value & 1 == 1 {
        result += place
      }

      value >>= 1
      place *= 0.5
    }

    return result
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
