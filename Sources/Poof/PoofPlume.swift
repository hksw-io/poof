import Foundation

/// How a plume behaves for one role and style.
///
/// Every field is a constant. Nothing here is fitted at runtime, so a profile
/// can be read as a description of the motion.
struct PoofPlumeProfile: Equatable, Sendable {
  /// The last moment a puff can be born, as a fraction of playback.
  let emissionEnd: Double
  /// Below one, births crowd toward the start: the cloud builds, then trickles.
  let emissionBias: Double
  let emissionJitter: Double
  let lifeBase: Double
  let lifeSpread: Double
  /// Travel away from the origin, in art units.
  let speed: Double
  let speedBase: Double
  let speedSpread: Double
  /// Buoyant drift, which is upward and therefore negative in view space.
  let rise: Double
  /// How far a puff wanders off its ray.
  let curl: Double
  let curlRateBase: Double
  let curlRateSpread: Double
  let directionScatter: Double
  let sizeScale: Double
  let growthBase: Double
  let growthSpread: Double
  let spin: Double
  let fadeStart: Double
  /// The age by which a newborn puff has fully faded in.
  let fadeInFraction: Double
  /// The age by which a newborn puff has reached full size.
  let emergeFraction: Double
  /// A puff's visible core tightens as its edges fall below the threshold.
  let taperStart: Double
  let lateTaper: Double
  /// Everything is gone by here, whatever the individual lifetimes say.
  let globalFadeStart: Double
  /// The furthest a puff's edge may reach from the center.
  ///
  /// The standalone effect fills its frame, so the drawable half-extent is
  /// half an art unit, and outlines and the blurred shadow reach past the
  /// geometry. This matches where the authored poses actually sit.
  let maximumExcursion: Double

  /// A poof drawn on its own, free to disperse.
  static let standalone = PoofPlumeProfile(
    emissionEnd: 0.52,
    emissionBias: 0.62,
    emissionJitter: 0.12,
    lifeBase: 0.44,
    lifeSpread: 0.28,
    speed: 0.42,
    speedBase: 0.55,
    speedSpread: 0.75,
    rise: 0.10,
    curl: 0.055,
    curlRateBase: 1.4,
    curlRateSpread: 1.9,
    directionScatter: 0.34,
    sizeScale: 1,
    growthBase: 0.55,
    growthSpread: 0.80,
    spin: 0.55,
    fadeStart: 0.38,
    fadeInFraction: 0.16,
    emergeFraction: 0.22,
    taperStart: 0.74,
    lateTaper: 0.20,
    globalFadeStart: 0.88,
    maximumExcursion: 0.42
  )

  /// A poof eating a view out from under itself.
  ///
  /// Everything is born early and grown early, because the source has to be
  /// gone by the dense pose. The low speed matters for the erosion too: the
  /// eaten region is swept rather than instantaneous, so fast puffs would open
  /// a trail wider than the smoke that made it.
  static let progressive = PoofPlumeProfile(
    emissionEnd: 0.26,
    emissionBias: 0.55,
    emissionJitter: 0.09,
    lifeBase: 0.52,
    lifeSpread: 0.26,
    speed: 0.26,
    speedBase: 0.45,
    speedSpread: 0.60,
    rise: 0.07,
    curl: 0.040,
    curlRateBase: 1.2,
    curlRateSpread: 1.5,
    directionScatter: 0.28,
    sizeScale: 1,
    growthBase: 0.35,
    growthSpread: 0.55,
    spin: 0.40,
    fadeStart: 0.46,
    fadeInFraction: 0.12,
    emergeFraction: 0.18,
    taperStart: 0.78,
    lateTaper: 0.16,
    globalFadeStart: 0.90,
    maximumExcursion: 0.42
  )

  func styled(for style: PoofStyle) -> PoofPlumeProfile {
    switch style {
    case .classic:
      return self
    case .bloom:
      return scaled(
        sizeScale: 1.18,
        speed: 0.86,
        growth: 1.25,
        scatter: 0.9
      )
    case .snap:
      return scaled(
        sizeScale: 0.86,
        speed: 1.28,
        growth: 0.88,
        scatter: 1.4
      )
    }
  }

  private func scaled(
    sizeScale: Double,
    speed speedScale: Double,
    growth growthScale: Double,
    scatter scatterScale: Double
  ) -> PoofPlumeProfile {
    PoofPlumeProfile(
      emissionEnd: emissionEnd,
      emissionBias: emissionBias,
      emissionJitter: emissionJitter,
      lifeBase: lifeBase,
      lifeSpread: lifeSpread,
      speed: speed * speedScale,
      speedBase: speedBase,
      speedSpread: speedSpread,
      rise: rise,
      curl: curl,
      curlRateBase: curlRateBase,
      curlRateSpread: curlRateSpread,
      directionScatter: directionScatter * scatterScale,
      sizeScale: self.sizeScale * sizeScale,
      growthBase: growthBase * growthScale,
      growthSpread: growthSpread * growthScale,
      spin: spin,
      fadeStart: fadeStart,
      fadeInFraction: fadeInFraction,
      emergeFraction: emergeFraction,
      taperStart: taperStart,
      lateTaper: lateTaper,
      globalFadeStart: globalFadeStart,
      maximumExcursion: maximumExcursion
    )
  }
}

/// One puff, described entirely by constants.
///
/// Nothing here is a state that advances. Everything the puff does at a given
/// progress is recovered by evaluating closed forms at its age, which is what
/// keeps a playback scrubbable and repeatable.
struct PoofPlumeParticle: Equatable, Sendable {
  let birth: Double
  let life: Double
  let originX: Double
  let originY: Double
  let directionX: Double
  let directionY: Double
  let speed: Double
  let rise: Double
  let curlAmplitude: Double
  let curlRate: Double
  let curlPhase: Double
  let size: Double
  let aspect: Double
  let growth: Double
  let rotation: Double
  let spin: Double
  let opacity: Double
  let contour: PoofContour
  let paint: PoofPaint
  let tone: PoofTone
  let paletteIndex: Int
}

/// Continuous smoke.
///
/// The stepped sequence is the faithful recreation: five drawn poses, swapped
/// without interpolation. Smooth motion used to be those same five poses with
/// a tween between them, which is exactly how it read. A plume instead gives
/// every puff its own trajectory and lets the poses decide only where puffs
/// start, how big they are, and in what order they arrive. The recognizable
/// shape of a poof survives because emission order carries it: early puffs are
/// dense and round, late ones are sparse and wispy.
struct PoofPlume: Equatable, Sendable {
  /// Keys are namespaced away from every other consumer of the seed.
  private static let keyBase: UInt64 = 0x0011_0000

  let particles: [PoofPlumeParticle]
  let profile: PoofPlumeProfile
  let engulfProgress: Double

  /// The glyphs alive at this progress.
  func blends(at progress: Double) -> [PoofGlyphBlend] {
    guard
      !progress.isNaN,
      progress > 0,
      progress < 1
    else {
      return []
    }

    var blends: [PoofGlyphBlend] = []
    blends.reserveCapacity(particles.count)

    for particle in particles {
      guard let blend = blend(for: particle, at: progress) else {
        continue
      }

      blends.append(blend)
    }

    return blends
  }

  private func blend(
    for particle: PoofPlumeParticle,
    at progress: Double
  ) -> PoofGlyphBlend? {
    let age = (progress - particle.birth) / particle.life

    guard age > 0, age < 1 else {
      return nil
    }

    // Ballistic, then dragged: fast off the mark and asymptotically still.
    let drift = 1 - pow(1 - age, 2.2)
    let rise = pow(age, 1.6)
    // Phased to start at exactly zero so the path leaves the origin cleanly.
    let curl =
      sin(particle.curlPhase + particle.curlRate * age)
      - sin(particle.curlPhase)
    let emerge = PoofNoise.smootherStep(age / profile.emergeFraction)
    let taper =
      1
      - profile.lateTaper
      * PoofNoise.smootherStep(
        from: profile.taperStart,
        to: 1,
        at: age
      )
    // Growing while fading reads as dissipation. Scaling out reads as
    // deflation, which is what the tweened lifecycle used to do.
    let size = particle.size * (1 + particle.growth * age) * emerge * taper

    guard size > 0 else {
      return nil
    }

    let opacity =
      particle.opacity
      * PoofNoise.smootherStep(age / profile.fadeInFraction)
      * (1 - PoofNoise.smootherStep(from: profile.fadeStart, to: 1, at: age))
      * (1
        - PoofNoise.smootherStep(
          from: profile.globalFadeStart,
          to: 1,
          at: progress
        ))

    guard opacity > 0.004 else {
      return nil
    }

    let x =
      particle.originX
      + particle.directionX * particle.speed * drift
      - particle.directionY * particle.curlAmplitude * curl
    let y =
      particle.originY
      + particle.directionY * particle.speed * drift
      + particle.directionX * particle.curlAmplitude * curl
      - particle.rise * rise

    return .single(
      PoofGlyph(
        x: x,
        y: y,
        width: size * particle.aspect,
        height: size / particle.aspect,
        opacity: opacity,
        contour: particle.contour,
        paint: particle.paint,
        rotation: particle.rotation + particle.spin * age,
        tone: particle.tone
      ),
      paletteIndex: particle.paletteIndex
    )
  }
}

extension PoofPlume {
  /// Builds a plume whose puffs start from the authored poses.
  ///
  /// Origins are drawn from the opening poses first and the dense pose after,
  /// in emission order, and pulled toward the center as births get later. That
  /// pull is what makes the field fountain instead of flying apart: the outer
  /// ring is old and thin while the bright mass stays in the middle.
  static func make(
    configuration: PoofConfiguration,
    style: PoofStyle,
    profile: PoofPlumeProfile,
    origins: [PoofPlumeOrigin],
    variationSeed: UInt64
  ) -> PoofPlume {
    let profile = profile.styled(for: style)

    guard !origins.isEmpty else {
      return PoofPlume(
        particles: [],
        profile: profile,
        engulfProgress: 1
      )
    }

    let count = min(
      PoofPlumeLayout.maximumParticleCount,
      max(
        PoofPlumeLayout.minimumParticleCount,
        Int((Double(configuration.particleCount) * 2).rounded())
      )
    )
    var particles: [PoofPlumeParticle] = []
    particles.reserveCapacity(count)

    for index in 0..<count {
      particles.append(
        particle(
          at: index,
          count: count,
          profile: profile,
          style: style,
          origins: origins,
          spread: configuration.spread,
          seed: variationSeed
        )
      )
    }

    return PoofPlume(
      particles: particles,
      profile: profile,
      engulfProgress: profile.emissionEnd + 0.18
    )
  }

  private static func particle(
    at index: Int,
    count: Int,
    profile: PoofPlumeProfile,
    style: PoofStyle,
    origins: [PoofPlumeOrigin],
    spread: Double,
    seed: UInt64
  ) -> PoofPlumeParticle {
    func noise(_ field: UInt64) -> Double {
      PoofNoise.value(seed: seed, key: key(index: index, field: field))
    }

    func unit(_ field: UInt64) -> Double {
      PoofNoise.unitValue(seed: seed, key: key(index: index, field: field))
    }

    let rank = (Double(index) + 0.5) / Double(count)
    // Jitter scales the moment rather than shifting it. Added, it would pile
    // the earliest puffs onto zero, and simultaneous births are the one thing
    // staggered emission exists to avoid.
    let birth =
      profile.emissionEnd
      * min(
        max(
          pow(rank, profile.emissionBias)
            * (1 + noise(0) * profile.emissionJitter),
          0.002
        ),
        1
      )
    let life = min(
      profile.lifeBase + unit(1) * profile.lifeSpread,
      1 - birth
    )
    let origin = origins[
      Int(rank * Double(origins.count)) % origins.count
    ]
    // Later puffs start nearer the middle and travel out from there.
    let reach =
      1
      - 0.45
      * (profile.emissionEnd > 0 ? birth / profile.emissionEnd : 0)
    let pulledX = origin.x * reach
    let pulledY = origin.y * reach
    let pulledRadius = (pulledX * pulledX + pulledY * pulledY).squareRoot()
    // High spread pushes the authored layouts past the field. A puff born
    // outside it could never be drawn, so origins are drawn back to the rim.
    let radiusLimit = profile.maximumExcursion - 0.05
    let radiusScale =
      pulledRadius > radiusLimit && pulledRadius > 0
      ? radiusLimit / pulledRadius
      : 1
    let originX = pulledX * radiusScale
    let originY = pulledY * radiusScale
    let radius = min(pulledRadius, radiusLimit)
    let baseAngle =
      radius < 0.000_001
      ? Double(index) * PoofPlumeLayout.goldenAngle
      : atan2(originY, originX)
    let angle = baseAngle + noise(4) * profile.directionScatter
    let spreadScale = spread / PoofPlumeLayout.referenceSpread
    let growth = profile.growthBase + unit(12) * profile.growthSpread
    let aspect = 0.92 + unit(11) * 0.20
    let elongation = max(aspect, 1 / aspect)
    // An authored cloud lobe is a merged mass, not a puff, so origins are read
    // down to puff scale before anything grows them.
    let bornSize = max(
      min(origin.size, PoofPlumeLayout.maximumOriginSize)
        * PoofPlumeLayout.originSizeScale
        * profile.sizeScale
        * (0.82 + unit(10) * 0.42),
      0.001
    )
    // Fit the puff to the room its origin leaves. Clamping only the speed
    // would stop it travelling while still letting it grow out of the field.
    let availableHalfExtent = max(profile.maximumExcursion - radius, 0.02)
    let grownHalfExtent = bornSize * (1 + growth) * elongation / 2
    let size =
      grownHalfExtent > availableHalfExtent
      ? bornSize * (availableHalfExtent / grownHalfExtent)
      : bornSize
    let fittedHalfExtent = min(grownHalfExtent, availableHalfExtent)
    // A puff born near the rim travels less than one born in the middle, which
    // is what makes the field read as a fountain rather than an explosion.
    let speed = max(
      min(
        profile.speed
          * spreadScale
          * (profile.speedBase + unit(5) * profile.speedSpread),
        profile.maximumExcursion - radius - fittedHalfExtent
      ),
      0
    )
    // Buoyancy spends whatever room the travel left, so a rising puff cannot
    // climb out of the top of the field.
    let rise = min(
      profile.rise * (0.55 + unit(6) * 0.9),
      max(
        profile.maximumExcursion - radius - fittedHalfExtent - speed,
        0
      )
    )
    let contour = contour(
      for: birth,
      style: style,
      profile: profile,
      unit: unit(17)
    )

    return PoofPlumeParticle(
      birth: birth,
      life: max(life, 0.001),
      originX: originX,
      originY: originY,
      directionX: cos(angle),
      directionY: sin(angle),
      speed: speed,
      rise: rise,
      curlAmplitude: profile.curl * (0.35 + unit(7) * 1.30),
      curlRate: profile.curlRateBase + unit(8) * profile.curlRateSpread,
      curlPhase: unit(9) * 2 * .pi,
      size: size,
      aspect: aspect,
      growth: growth,
      rotation: unit(13) * 2 * .pi,
      spin: noise(14) * profile.spin,
      opacity: origin.opacity,
      contour: contour,
      paint: paint(for: contour, unit: unit(18)),
      tone: tone(for: unit(19)),
      paletteIndex: index
    )
  }

  /// Shape follows birth time, so the smoke changes character as it goes
  /// without anyone interpolating between two authored shapes.
  private static func contour(
    for birth: Double,
    style: PoofStyle,
    profile: PoofPlumeProfile,
    unit: Double
  ) -> PoofContour {
    let phase =
      profile.emissionEnd > 0
      ? birth / profile.emissionEnd
      : 0

    guard style != .classic else {
      // Classic smoke is puffs the whole way down; size carries dissipation.
      return unit < 0.58 ? .puff4 : .puff5
    }

    if phase < 0.45 {
      return unit < 0.62 ? .puff4 : .puff5
    }

    if phase < 0.78 {
      return unit < 0.34 ? .puff4 : unit < 0.68 ? .fleck : .curl
    }

    return unit < 0.45 ? .ring : unit < 0.78 ? .curl : .fleck
  }

  private static func paint(
    for contour: PoofContour,
    unit: Double
  ) -> PoofPaint {
    switch contour {
    case .puff4, .puff5, .fleck:
      return unit > 0.22 ? .fillAndOutline : .fillOutlineAndInset
    case .ring, .curl:
      return unit > 0.45 ? .doubleStroke : .fillAndOutline
    }
  }

  private static func tone(for unit: Double) -> PoofTone {
    if unit > 0.62 {
      return .middle
    }

    return unit > 0.30 ? .light : .dark
  }

  private static func key(index: Int, field: UInt64) -> UInt64 {
    keyBase &+ UInt64(index + 1) &* 0x40 &+ field
  }
}

extension PoofPlume {
  /// Reads emission origins out of the authored poses.
  ///
  /// The opening poses come first and the dense pose after, so walking the
  /// list in order walks the sequence the stepped playback draws. That is what
  /// keeps a plume recognizable as the same effect without anyone
  /// interpolating between two poses.
  static func origins(from poses: [[PoofGlyph]]) -> [PoofPlumeOrigin] {
    let ordered: [PoofPose] = [.cloud, .clusters, .puffs]

    return ordered.flatMap { pose -> [PoofPlumeOrigin] in
      guard poses.indices.contains(pose.rawValue) else {
        return []
      }

      return poses[pose.rawValue].map { glyph in
        PoofPlumeOrigin(
          x: glyph.x,
          y: glyph.y,
          size: (glyph.width * glyph.height).squareRoot(),
          opacity: glyph.opacity
        )
      }
    }
  }
}

/// Where a puff starts and how large it begins.
struct PoofPlumeOrigin: Equatable, Sendable {
  let x: Double
  let y: Double
  let size: Double
  let opacity: Double
}

enum PoofPlumeLayout {
  static let minimumParticleCount = 12
  static let maximumParticleCount = 64
  static let goldenAngle = 2.399_963_229_728_653
  static let referenceSpread = 0.82
  /// Authored cloud lobes are far larger than a single puff.
  static let maximumOriginSize = 0.22
  static let originSizeScale = 0.62
}
