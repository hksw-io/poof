import Foundation

/// Controls the density and reach of a poof.
public struct PoofConfiguration: Hashable, Sendable {
  /// A balanced effect for controls, rows, and icons.
  public static let standard = PoofConfiguration()

  /// The number of smoke particles.
  ///
  /// Values outside `12...64` are clamped to keep drawing work bounded.
  public let particleCount: Int

  /// How widely smoke is distributed relative to the drawing field.
  ///
  /// Values outside `0.55...1.10` are clamped.
  public let spread: Double

  /// The size of the drawing field relative to the disappearing view.
  ///
  /// Values outside `1.50...3.00` are clamped.
  public let fieldScale: Double

  /// The seed used to derive the particle field.
  public let seed: UInt64

  let particles: [PoofParticle]

  /// Creates a deterministic poof configuration.
  public init(
    particleCount: Int = 22,
    spread: Double = 0.82,
    fieldScale: Double = 2.10,
    seed: UInt64 = 0x504F_4F46
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
    particles = PoofSimulation.makeParticles(
      count: particleCount,
      spread: spread,
      seed: seed
    )
  }
}
