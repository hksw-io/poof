import Foundation

struct PoofParticle: Hashable, Sendable {
  enum Tone: Int, Hashable, Sendable {
    case light
    case middle
    case dark
  }

  let directionX: Double
  let directionY: Double
  let distance: Double
  let drift: Double
  let diameter: Double
  let delay: Double
  let curl: Double
  let lift: Double
  let aspectRatio: Double
  let maximumOpacity: Double
  let isMote: Bool
  let tone: Tone
}

struct PoofParticleState: Equatable, Sendable {
  let x: Double
  let y: Double
  let width: Double
  let height: Double
  let opacity: Double
  let tone: PoofParticle.Tone
}

enum PoofSimulation {
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
    let jitter =
      random.value(in: -0.42...0.42)
      / Double(count)
    let angle = 2 * Double.pi * (slot + jitter)
    let toneIndex = min(Int(random.value(in: 0...3)), 2)
    let isMote = index.isMultiple(of: 4)

    return PoofParticle(
      directionX: cos(angle),
      directionY: sin(angle),
      distance: spread
        * random.value(in: isMote ? 0.18...0.38 : 0.05...0.30),
      drift: spread * random.value(in: 0.025...0.065),
      diameter: random.value(in: isMote ? 0.045...0.080 : 0.12...0.21),
      delay: random.value(in: isMote ? 0.04...0.16 : 0...0.10),
      curl: random.value(in: -0.24...0.24),
      lift: random.value(in: 0.025...0.10),
      aspectRatio: random.value(in: 0.78...1.24),
      maximumOpacity: random.value(in: isMote ? 0.46...0.70 : 0.64...0.92),
      isMote: isMote,
      tone: PoofParticle.Tone(rawValue: toneIndex) ?? .middle
    )
  }

  static func state(
    for particle: PoofParticle,
    progress: Double,
    reducesTransparency: Bool
  ) -> PoofParticleState {
    let progress = clamp(progress)
    let localProgress = clamp(
      (progress - particle.delay) / (1 - particle.delay)
    )
    let appearance = smoothstep(
      edge0: 0,
      edge1: 0.14,
      value: localProgress
    )
    let distanceFactor = min(max(particle.distance / 0.42, 0), 1)
    let fadeStart =
      (reducesTransparency ? 0.74 : 0.52)
      - (reducesTransparency ? 0.04 : 0.12) * distanceFactor
    let disappearance =
      1
      - smoothstep(
        edge0: fadeStart,
        edge1: 1,
        value: localProgress
      )
    let travel = easeOutCubic(localProgress)
    let distance =
      particle.distance * mix(from: 0.84, to: 1, amount: travel)
      + particle.drift * travel
    let curve =
      particle.curl
      * particle.drift
      * 4
      * localProgress
      * (1 - localProgress)
    let growth = mix(
      from: 0.36,
      to: 1,
      amount: smoothstep(edge0: 0, edge1: 0.22, value: localProgress)
    )
    let contraction = mix(
      from: 1,
      to: 0.64,
      amount: smoothstep(edge0: 0.58, edge1: 1, value: localProgress)
    )
    let diameter = particle.diameter * growth * contraction
    let opacityFloor =
      reducesTransparency
      ? max(0.88, particle.maximumOpacity)
      : particle.maximumOpacity

    return PoofParticleState(
      x: particle.directionX * distance
        - particle.directionY * curve,
      y: particle.directionY * distance
        + particle.directionX * curve
        - particle.lift * localProgress * localProgress,
      width: diameter * particle.aspectRatio,
      height: diameter / particle.aspectRatio,
      opacity: opacityFloor * appearance * disappearance,
      tone: particle.tone
    )
  }

  static func smoothstep(
    edge0: Double,
    edge1: Double,
    value: Double
  ) -> Double {
    guard edge0 != edge1 else {
      return value < edge0 ? 0 : 1
    }

    let amount = clamp((value - edge0) / (edge1 - edge0))
    return amount * amount * (3 - 2 * amount)
  }

  private static func easeOutCubic(_ value: Double) -> Double {
    let inverse = 1 - clamp(value)
    return 1 - inverse * inverse * inverse
  }

  private static func mix(
    from start: Double,
    to end: Double,
    amount: Double
  ) -> Double {
    start + (end - start) * clamp(amount)
  }

  private static func clamp(_ value: Double) -> Double {
    min(max(value, 0), 1)
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
