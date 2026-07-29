import Foundation

/// Controls the density and reach of a poof.
public struct PoofConfiguration: Hashable, Sendable {
  /// A balanced effect for controls, rows, and icons.
  public static let standard = PoofConfiguration()

  /// The number of glyphs in the dense breakup pose.
  ///
  /// Later poses retain proportionally fewer glyphs. The initializer clamps
  /// values outside `12...64` to keep drawing work bounded.
  public let particleCount: Int

  /// How widely breakup glyphs are distributed.
  ///
  /// The opening silhouettes stay fixed. The initializer clamps values outside
  /// `0.55...1.10`.
  public let spread: Double

  /// The transparent drawing overscan relative to the disappearing view.
  ///
  /// This does not scale the artwork. The initializer clamps values outside
  /// `1.50...3.00`.
  public let fieldScale: Double

  /// The seed used to derive the smoke shapes.
  ///
  /// Leave this as `nil` to apply a slight variation to each playback. Supply
  /// a seed when repeatable output is required.
  public let seed: UInt64?

  /// Creates a poof configuration.
  public init(
    particleCount: Int = 28,
    spread: Double = 0.82,
    fieldScale: Double = 2.10,
    seed: UInt64? = nil
  ) {
    let particleCount = min(max(particleCount, 12), 64)
    let spread = spread.isFinite ? min(max(spread, 0.55), 1.10) : 0.82
    let fieldScale =
      fieldScale.isFinite
      ? min(max(fieldScale, 1.50), 3.00)
      : 2.10

    self.particleCount = particleCount
    self.spread = spread
    self.fieldScale = fieldScale
    self.seed = seed
  }
}
