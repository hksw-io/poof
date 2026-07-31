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

struct PoofSmoothGeometry: Equatable, Sendable {
  let x: Double
  let y: Double
  let width: Double
  let height: Double
  let rotation: Double

  static let zero = PoofSmoothGeometry(
    x: 0,
    y: 0,
    width: 0,
    height: 0,
    rotation: 0
  )

  init(glyph: PoofGlyph) {
    x = glyph.x
    y = glyph.y
    width = glyph.width
    height = glyph.height
    rotation = glyph.rotation
  }

  init(
    x: Double,
    y: Double,
    width: Double,
    height: Double,
    rotation: Double
  ) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.rotation = rotation
  }

  func replacing(
    x: Double? = nil,
    y: Double? = nil,
    rotation: Double? = nil
  ) -> PoofSmoothGeometry {
    PoofSmoothGeometry(
      x: x ?? self.x,
      y: y ?? self.y,
      width: width,
      height: height,
      rotation: rotation ?? self.rotation
    )
  }

  static func tangent(
    previous: PoofSmoothGeometry,
    next: PoofSmoothGeometry,
    duration: Double
  ) -> PoofSmoothGeometry {
    PoofSmoothGeometry(
      x: (next.x - previous.x) / duration,
      y: (next.y - previous.y) / duration,
      width: (next.width - previous.width) / duration,
      height: (next.height - previous.height) / duration,
      rotation: (next.rotation - previous.rotation) / duration
    )
  }

  static func hermite(
    start: PoofSmoothGeometry,
    end: PoofSmoothGeometry,
    startTangent: PoofSmoothGeometry,
    endTangent: PoofSmoothGeometry,
    amount: Double,
    duration: Double
  ) -> PoofSmoothGeometry {
    let amountSquared = amount * amount
    let amountCubed = amountSquared * amount
    let startWeight = 2 * amountCubed - 3 * amountSquared + 1
    let startTangentWeight = amountCubed - 2 * amountSquared + amount
    let endWeight = -2 * amountCubed + 3 * amountSquared
    let endTangentWeight = amountCubed - amountSquared

    func value(
      _ start: Double,
      _ end: Double,
      _ startTangent: Double,
      _ endTangent: Double
    ) -> Double {
      startWeight * start
        + startTangentWeight * duration * startTangent
        + endWeight * end
        + endTangentWeight * duration * endTangent
    }

    return PoofSmoothGeometry(
      x: value(start.x, end.x, startTangent.x, endTangent.x),
      y: value(start.y, end.y, startTangent.y, endTangent.y),
      width: value(
        start.width,
        end.width,
        startTangent.width,
        endTangent.width
      ),
      height: value(
        start.height,
        end.height,
        startTangent.height,
        endTangent.height
      ),
      rotation: value(
        start.rotation,
        end.rotation,
        startTangent.rotation,
        endTangent.rotation
      )
    )
  }
}

struct PoofSmoothTrackState: Equatable, Sendable {
  let glyph: PoofGlyph
  let paletteIndex: Int
  let scale: Double
}

struct PoofSmoothLifecycle: Equatable, Sendable {
  let start: Double
  let duration: Double
}

struct PoofSmoothTrack: Equatable, Sendable {
  let contour: PoofContour
  let paint: PoofPaint
  let tone: PoofTone
  let opacity: Double
  let paletteIndex: Int
  let anchors: [PoofSmoothGeometry]
  let tangents: [PoofSmoothGeometry]
  let activity: [Double]
  let lifecycles: [PoofSmoothLifecycle]

  func state(for sample: PoofPoseSample) -> PoofSmoothTrackState {
    let segment = min(
      max(sample.segment, 0),
      anchors.count - 2
    )
    let amount = min(max(sample.amount, 0), 1)
    let duration =
      PoofSmoothPlan.anchorProgress[segment + 1]
      - PoofSmoothPlan.anchorProgress[segment]
    let geometry = PoofSmoothGeometry.hermite(
      start: anchors[segment],
      end: anchors[segment + 1],
      startTangent: tangents[segment],
      endTangent: tangents[segment + 1],
      amount: amount,
      duration: duration
    )
    let scale = interpolatedActivity(
      start: activity[segment],
      end: activity[segment + 1],
      amount: amount,
      lifecycle: lifecycles[segment]
    )

    return PoofSmoothTrackState(
      glyph: PoofGlyph(
        x: geometry.x,
        y: geometry.y,
        width: max(geometry.width, 0) * scale,
        height: max(geometry.height, 0) * scale,
        opacity: opacity,
        contour: contour,
        paint: paint,
        rotation: geometry.rotation,
        tone: tone
      ),
      paletteIndex: paletteIndex,
      scale: scale
    )
  }

  private func interpolatedActivity(
    start: Double,
    end: Double,
    amount: Double,
    lifecycle: PoofSmoothLifecycle
  ) -> Double {
    guard start != end else {
      return start
    }

    let lifecycleAmount = min(
      max(
        (amount - lifecycle.start) / lifecycle.duration,
        0
      ),
      1
    )
    let amountCubed =
      lifecycleAmount * lifecycleAmount * lifecycleAmount
    let smootherAmount =
      amountCubed
      * (lifecycleAmount
        * (lifecycleAmount * 6 - 15)
        + 10)
    return start + (end - start) * smootherAmount
  }
}

struct PoofSmoothPlan: Equatable, Sendable {
  // Empty endpoints let puffs grow into and shrink out of the playback.
  static let anchorProgress = [
    0.0,
    0.1,
    0.3,
    0.5,
    0.7,
    0.9,
    1.0,
  ]
  static let visibleScaleThreshold = 0.000_001

  let tracks: [PoofSmoothTrack]

  init(
    poseAnchors: [[PoofGlyphLayer]],
    variationSeed: UInt64,
    preservingLineageThrough fixedPoseIndex: Int? = nil
  ) {
    let builders = Self.trackBuilders(
      poseAnchors: poseAnchors,
      preservingLineageThrough: fixedPoseIndex
    )
    let visibleLayersByAnchor =
      builders.first.map { firstBuilder in
        firstBuilder.layers.indices.map { anchorIndex in
          builders.compactMap {
            $0.layers[anchorIndex]
          }
        }
      } ?? []
    let lifecycles = Self.lifecycles(
      for: builders,
      seed: variationSeed
    )

    tracks = builders.enumerated().compactMap {
      trackIndex,
      builder in
      guard
        let firstLayer = builder.layers.compactMap({ $0 }).first
      else {
        return nil
      }

      let resolvedAnchors = Self.resolvedAnchors(
        for: builder,
        visibleLayersByAnchor: visibleLayersByAnchor
      )
      let unwrappedAnchors = Self.unwrappedRotations(
        in: resolvedAnchors
      )
      return PoofSmoothTrack(
        contour: firstLayer.glyph.contour,
        paint: firstLayer.glyph.paint,
        tone: firstLayer.glyph.tone,
        opacity: firstLayer.glyph.opacity,
        paletteIndex: firstLayer.paletteIndex,
        anchors: unwrappedAnchors,
        tangents: Self.tangents(for: unwrappedAnchors),
        activity: builder.layers.map {
          $0 == nil ? 0 : 1
        },
        lifecycles: lifecycles[trackIndex]
      )
    }
  }

  func states(for sample: PoofPoseSample) -> [PoofSmoothTrackState] {
    tracks.map {
      $0.state(for: sample)
    }
  }

  func glyphs(for sample: PoofPoseSample) -> [PoofGlyph] {
    states(for: sample).compactMap { state in
      state.scale > Self.visibleScaleThreshold
        ? state.glyph
        : nil
    }
  }

  func blends(for sample: PoofPoseSample) -> [PoofGlyphBlend] {
    states(for: sample).compactMap { state in
      guard state.scale > Self.visibleScaleThreshold else {
        return nil
      }

      return .single(
        state.glyph,
        paletteIndex: state.paletteIndex,
        scale: state.scale
      )
    }
  }

  private struct TrackBuilder {
    var layers: [PoofGlyphLayer?]
    var lastLayer: PoofGlyphLayer
  }

  private struct Match {
    let distance: Double
    let trackIndex: Int
    let layerIndex: Int
  }

  private static func trackBuilders(
    poseAnchors: [[PoofGlyphLayer]],
    preservingLineageThrough fixedPoseIndex: Int?
  ) -> [TrackBuilder] {
    var builders: [TrackBuilder] = []

    for (poseIndex, anchor) in poseAnchors.enumerated() {
      let anchorIndex = poseIndex + 1

      for index in builders.indices {
        builders[index].layers.append(nil)
      }

      if let fixedPoseIndex, poseIndex <= fixedPoseIndex {
        assignByLineage(
          anchor,
          at: anchorIndex,
          builders: &builders
        )
      } else {
        assignSpatially(
          anchor,
          at: anchorIndex,
          builders: &builders
        )
      }
    }

    for index in builders.indices {
      builders[index].layers.append(nil)
    }

    return builders
  }

  private static func assignByLineage(
    _ anchor: [PoofGlyphLayer],
    at anchorIndex: Int,
    builders: inout [TrackBuilder]
  ) {
    for (layerIndex, layer) in anchor.enumerated() {
      if builders.indices.contains(layerIndex) {
        builders[layerIndex].layers[anchorIndex] = layer
        builders[layerIndex].lastLayer = layer
      } else {
        builders.append(
          TrackBuilder(
            layers:
              Array(
                repeating: nil,
                count: anchorIndex
              ) + [layer],
            lastLayer: layer
          )
        )
      }
    }
  }

  private static func assignSpatially(
    _ anchor: [PoofGlyphLayer],
    at anchorIndex: Int,
    builders: inout [TrackBuilder]
  ) {
    var remainingLayerIndices = Set(anchor.indices)
    // Continue visible tracks before recycling dormant ones. This keeps a
    // puff's path stable when the authored pose changes its glyph count.
    let activeTrackIndices = builders.indices.filter {
      builders[$0].layers[anchorIndex - 1] != nil
    }

    assignMatches(
      trackIndices: activeTrackIndices,
      anchor: anchor,
      anchorIndex: anchorIndex,
      remainingLayerIndices: &remainingLayerIndices,
      builders: &builders
    )

    let inactiveTrackIndices = builders.indices.filter {
      builders[$0].layers[anchorIndex] == nil
    }
    assignMatches(
      trackIndices: inactiveTrackIndices,
      anchor: anchor,
      anchorIndex: anchorIndex,
      remainingLayerIndices: &remainingLayerIndices,
      builders: &builders
    )

    for layerIndex in anchor.indices
    where remainingLayerIndices.contains(layerIndex) {
      let layer = anchor[layerIndex]
      builders.append(
        TrackBuilder(
          layers:
            Array(
              repeating: nil,
              count: anchorIndex
            ) + [layer],
          lastLayer: layer
        )
      )
    }
  }

  private static func assignMatches(
    trackIndices: [Int],
    anchor: [PoofGlyphLayer],
    anchorIndex: Int,
    remainingLayerIndices: inout Set<Int>,
    builders: inout [TrackBuilder]
  ) {
    guard
      !trackIndices.isEmpty,
      !remainingLayerIndices.isEmpty
    else {
      return
    }

    let matches = trackIndices.flatMap { trackIndex in
      remainingLayerIndices.map { layerIndex in
        Match(
          distance: squaredDistance(
            from: builders[trackIndex].lastLayer.glyph,
            to: anchor[layerIndex].glyph
          ),
          trackIndex: trackIndex,
          layerIndex: layerIndex
        )
      }
    }.sorted {
      if $0.distance != $1.distance {
        return $0.distance < $1.distance
      }
      if $0.trackIndex != $1.trackIndex {
        return $0.trackIndex < $1.trackIndex
      }
      return $0.layerIndex < $1.layerIndex
    }
    var matchedTrackIndices: Set<Int> = []

    for match in matches
    where !matchedTrackIndices.contains(match.trackIndex)
      && remainingLayerIndices.contains(match.layerIndex)
    {
      let layer = anchor[match.layerIndex]
      builders[match.trackIndex].layers[anchorIndex] = layer
      builders[match.trackIndex].lastLayer = layer
      matchedTrackIndices.insert(match.trackIndex)
      remainingLayerIndices.remove(match.layerIndex)
    }
  }

  private static func resolvedAnchors(
    for builder: TrackBuilder,
    visibleLayersByAnchor: [[PoofGlyphLayer]]
  ) -> [PoofSmoothGeometry] {
    builder.layers.indices.map { anchorIndex in
      if let layer = builder.layers[anchorIndex] {
        return PoofSmoothGeometry(glyph: layer.glyph)
      }

      let previousLayer = builder.layers[..<anchorIndex]
        .reversed()
        .compactMap { $0 }
        .first
      let nextLayer = builder.layers[(anchorIndex + 1)...]
        .compactMap { $0 }
        .first
      let referenceLayer = previousLayer ?? nextLayer

      guard let referenceLayer else {
        return .zero
      }

      // A track begins at the center and ends at its last visible position.
      if anchorIndex == 0 {
        return PoofSmoothGeometry(glyph: referenceLayer.glyph)
          .replacing(x: 0, y: 0)
      }

      guard
        let targetLayer = nearestLayer(
          to: referenceLayer.glyph,
          in: visibleLayersByAnchor[anchorIndex]
        )
      else {
        return PoofSmoothGeometry(glyph: referenceLayer.glyph)
      }

      // Dormant tracks collapse into nearby smoke instead of jumping across
      // the field before they scale back in.
      return PoofSmoothGeometry(glyph: referenceLayer.glyph)
        .replacing(
          x: targetLayer.glyph.x,
          y: targetLayer.glyph.y,
          rotation: targetLayer.glyph.rotation
        )
    }
  }

  private static func nearestLayer(
    to glyph: PoofGlyph,
    in candidates: [PoofGlyphLayer]
  ) -> PoofGlyphLayer? {
    candidates.min {
      let firstDistance = squaredDistance(
        from: glyph,
        to: $0.glyph
      )
      let secondDistance = squaredDistance(
        from: glyph,
        to: $1.glyph
      )
      return firstDistance < secondDistance
    }
  }

  private static func squaredDistance(
    from start: PoofGlyph,
    to end: PoofGlyph
  ) -> Double {
    let deltaX = end.x - start.x
    let deltaY = end.y - start.y
    return deltaX * deltaX + deltaY * deltaY
  }

  private static func unwrappedRotations(
    in anchors: [PoofSmoothGeometry]
  ) -> [PoofSmoothGeometry] {
    guard let first = anchors.first else {
      return []
    }

    var result = [first]

    for anchor in anchors.dropFirst() {
      let previousRotation = result[result.count - 1].rotation
      let delta = atan2(
        sin(anchor.rotation - previousRotation),
        cos(anchor.rotation - previousRotation)
      )
      result.append(
        anchor.replacing(
          rotation: previousRotation + delta
        )
      )
    }

    return result
  }

  private static func tangents(
    for anchors: [PoofSmoothGeometry]
  ) -> [PoofSmoothGeometry] {
    anchors.indices.map { index in
      guard index > 0, index < anchors.count - 1 else {
        return .zero
      }

      // One shared central tangent gives both sides of an anchor the same
      // velocity. The empty endpoints remain at rest.
      return .tangent(
        previous: anchors[index - 1],
        next: anchors[index + 1],
        duration:
          anchorProgress[index + 1]
          - anchorProgress[index - 1]
      )
    }
  }

  private static func lifecycles(
    for builders: [TrackBuilder],
    seed: UInt64
  ) -> [[PoofSmoothLifecycle]] {
    guard let anchorCount = builders.first?.layers.count else {
      return []
    }

    let segmentCount = anchorCount - 1
    let idle = PoofSmoothLifecycle(start: 0, duration: 1)
    var result = builders.map { _ in
      Array(repeating: idle, count: segmentCount)
    }

    for segment in 0..<segmentCount {
      // Sort each lifecycle event once, then place it in a jittered timing
      // stratum. Randomness can change the order without creating batches.
      let changingTracks = builders.indices.compactMap {
        trackIndex
          -> (index: Int, order: UInt64)? in
        guard
          (builders[trackIndex].layers[segment] == nil)
            != (builders[trackIndex].layers[segment + 1] == nil)
        else {
          return nil
        }

        return (
          trackIndex,
          lifecycleOrder(
            seed: seed,
            trackIndex: trackIndex,
            segment: segment
          )
        )
      }.sorted {
        $0.order == $1.order
          ? $0.index < $1.index
          : $0.order < $1.order
      }
      let count = Double(changingTracks.count)

      for (rank, track) in changingTracks.enumerated() {
        let trackIndex = track.index
        let jitter =
          (unitNoise(
            seed: lifecycleKey(
              seed: seed,
              trackIndex: trackIndex,
              segment: segment,
              salt: 0xA076_1D64_78BD_642F
            )
          ) - 0.5) * 0.5
        let phase =
          (Double(rank) + 0.5 + jitter) / count
        let duration =
          0.16
          + unitNoise(
            seed: lifecycleKey(
              seed: seed,
              trackIndex: trackIndex,
              segment: segment,
              salt: 0xE703_7ED1_A0B4_28DB
            )
          ) * 0.06
        result[trackIndex][segment] = PoofSmoothLifecycle(
          start: 0.02 + phase * 0.74,
          duration: duration
        )
      }
    }

    return result
  }

  private static func lifecycleOrder(
    seed: UInt64,
    trackIndex: Int,
    segment: Int
  ) -> UInt64 {
    mixedValue(
      seed: lifecycleKey(
        seed: seed,
        trackIndex: trackIndex,
        segment: segment,
        salt: 0x8EBC_6AF0_9C88_C6E3
      )
    )
  }

  private static func lifecycleKey(
    seed: UInt64,
    trackIndex: Int,
    segment: Int,
    salt: UInt64
  ) -> UInt64 {
    seed
      ^ (UInt64(trackIndex + 1) &* 0xD6E8_FEB8_6659_FD93)
      ^ (UInt64(segment + 1) &* 0x9E37_79B9_7F4A_7C15)
      ^ salt
  }

  private static func unitNoise(seed: UInt64) -> Double {
    Double(mixedValue(seed: seed) >> 11) * 0x1.0p-53
  }

  private static func mixedValue(seed: UInt64) -> UInt64 {
    var value = seed &+ 0x9E37_79B9_7F4A_7C15
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    value ^= value >> 31
    return value
  }
}

struct PoofPoseSample: Equatable, Sendable {
  let segment: Int
  let start: PoofPose?
  let end: PoofPose?
  let amount: Double

  func weight(for pose: PoofPose) -> Double {
    let startWeight = start == pose ? 1 - amount : 0
    let endWeight = end == pose ? amount : 0
    return startWeight + endWeight
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
  private let smoothPlan: PoofSmoothPlan
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
    smoothPlan = PoofSmoothPlan(
      poseAnchors: poses.map { pose in
        pose.enumerated().map {
          PoofGlyphLayer(
            glyph: $0.element,
            paletteIndex: $0.offset
          )
        }
      },
      variationSeed: variationSeed
    )
    self.sourceCoverLayout = sourceCoverLayout
    self.sourceCoverAspect = sourceCoverAspect
  }

  func glyphs(for pose: PoofPose) -> [PoofGlyph] {
    poses[pose.rawValue]
  }

  func glyphs(for sample: PoofPoseSample) -> [PoofGlyph] {
    smoothPlan.glyphs(for: sample)
  }

  func blends(for sample: PoofPoseSample) -> [PoofGlyphBlend] {
    smoothPlan.blends(for: sample)
  }

  func sourceCoverGlyphs(
    for aspect: PoofSourceCoverAspect
  ) -> [PoofSourceCoverGlyph] {
    sourceCoverLayout?.glyphs(for: aspect) ?? []
  }
}

enum PoofSimulation {
  static let frameDuration = 1.0 / 15.0
  static let duration = frameDuration * Double(PoofPose.allCases.count)

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

  static func smoothSample(for progress: Double) -> PoofPoseSample? {
    let progress = normalized(progress)

    guard progress > 0, progress < 1 else {
      return nil
    }

    let anchors = zip(
      PoofSmoothPlan.anchorProgress,
      [nil, .cloud, .clusters, .puffs, .wisps, .ringlets, nil]
        as [PoofPose?]
    ).map { (progress: $0, pose: $1) }
    let segment =
      anchors.indices.dropLast().first { index in
        progress <= anchors[index + 1].progress
      } ?? anchors.count - 2
    let start = anchors[segment]
    let end = anchors[segment + 1]
    let linearAmount =
      (progress - start.progress)
      / (end.progress - start.progress)

    return PoofPoseSample(
      segment: segment,
      start: start.pose,
      end: end.pose,
      amount: linearAmount
    )
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

    let variedGlyph = varied(
      styled(
        matchedReferenceGeometry(glyph, pose: pose, index: index),
        pose: pose,
        index: index,
        style: style
      ),
      pose: pose,
      index: index,
      seed: variationSeed
    )

    if style == .classic {
      return variedGlyph
    }

    return boundedModernGlyph(variedGlyph)
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

    return style == .classic
      ? variedGlyph
      : boundedModernGlyph(variedGlyph)
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
    index: Int,
    style: PoofStyle
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

  private static func boundedModernGlyph(_ glyph: PoofGlyph) -> PoofGlyph {
    let renderedHeight =
      glyph.height * (glyph.contour == .curl ? 1.60 : 1)
    let cosine = abs(cos(glyph.rotation))
    let sine = abs(sin(glyph.rotation))
    let halfWidth = glyph.width / 2
    let halfHeight = renderedHeight / 2
    let extentX = halfWidth * cosine + halfHeight * sine
    let extentY = halfWidth * sine + halfHeight * cosine
    // Reserve room for outlines and the optional blurred shadow.
    let drawingLimit = 0.43
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
    index: Int
  ) -> PoofGlyph {
    // Calibrate the authored vectors to the clean-room measurement envelopes
    // asserted by the rendering tests.
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
      positionScaleX = 0.78
      positionScaleY = 0.78
      sizeScaleX = 0.86
      sizeScaleY = 0.86
      offsetX = -0.005
      offsetY = 0.018
    case .puffs:
      positionScaleX = 1.18
      positionScaleY = 1.07
      sizeScaleX = index < 11 ? 0.72 : 1.48
      sizeScaleY = index < 11 ? 0.72 : 1.48
      offsetX = 0
      offsetY = -0.005
    case .wisps:
      positionScaleX = 1.02
      positionScaleY = 1.02
      sizeScaleX = 1.48
      sizeScaleY = 1.48
      offsetX = -0.018
      offsetY = 0.008
    case .ringlets:
      positionScaleX = 1
      positionScaleY = 1
      sizeScaleX = 1.38
      sizeScaleY = 1.38
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
          let parentIndex =
            centers.indices.min {
              let firstX = targetX - centers[$0].x
              let firstY = targetY - centers[$0].y
              let secondX = targetX - centers[$1].x
              let secondY = targetY - centers[$1].y
              return firstX * firstX + firstY * firstY
                < secondX * secondX + secondY * secondY
            } ?? 0
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

  private static func sizedSourceCoverGlyphs(
    _ glyphs: [PoofSourceCoverGlyph],
    coverageCount: Int,
    sourceWidth: Double,
    sourceHeight: Double,
    artSide: Double
  ) -> [PoofSourceCoverGlyph] {
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
        let nearestIndex =
          (0..<coverageCount).min {
            let first = glyphs[$0]
            let second = glyphs[$1]
            return hypot(
              cellCenterX - sourceWidth * first.x,
              cellCenterY - sourceHeight * first.y
            )
              < hypot(
                cellCenterX - sourceWidth * second.x,
                cellCenterY - sourceHeight * second.y
              )
          } ?? 0
        let glyph = glyphs[nearestIndex]
        let farthestDistance =
          hypot(
            cellCenterX - sourceWidth * glyph.x,
            cellCenterY - sourceHeight * glyph.y
          )
          + halfCellDiagonal
        requiredRadii[nearestIndex] = max(
          requiredRadii[nearestIndex],
          farthestDistance
        )
      }
    }

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

  private static func largestSourceCoverGap(
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
    let discs = glyphs.map { glyph in
      (
        x: sourceWidth * glyph.x,
        y: sourceHeight * glyph.y,
        radius:
          min(
            sourceWidth * glyph.width,
            sourceHeight * glyph.height
          ) * 0.30
      )
    }
    var largestGap = (x: 0.0, y: 0.0)
    var largestDeficit = -Double.infinity

    for row in 0..<rowCount {
      for column in 0..<columnCount {
        let cellKey =
          key + UInt64(row * columnCount + column) * 0x10
        let point = (
          x:
            -sourceWidth / 2
            + (Double(column)
              + coverUnitNoise(
                seed: seed,
                key: cellKey + 1,
                in: 0.28...0.72
              )) * cellWidth,
          y:
            -sourceHeight / 2
            + (Double(row)
              + coverUnitNoise(
                seed: seed,
                key: cellKey + 2,
                in: 0.28...0.72
              )) * cellHeight
        )
        var deficit = Double.infinity

        for disc in discs {
          deficit = min(
            deficit,
            hypot(
              point.x - disc.x,
              point.y - disc.y
            ) - disc.radius
          )
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

  private static func coverUnitNoise(
    seed: UInt64,
    key: UInt64,
    in range: ClosedRange<Double>
  ) -> Double {
    let unit = (noise(seed: seed, key: key) + 1) / 2
    return range.lowerBound
      + (range.upperBound - range.lowerBound) * unit
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
    // Counter-based noise stays deterministic without mutable random state.
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
