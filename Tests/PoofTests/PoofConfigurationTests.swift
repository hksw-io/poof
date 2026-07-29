import Testing

@testable import Poof

@Suite("Poof configuration")
struct PoofConfigurationTests {
  @Test("Values are clamped to rendering limits")
  func clamping() {
    let minimum = PoofConfiguration(
      particleCount: -1,
      spread: -100,
      fieldScale: 0
    )
    let maximum = PoofConfiguration(
      particleCount: 1_000,
      spread: 100,
      fieldScale: 100
    )

    #expect(minimum.particleCount == 12)
    #expect(minimum.spread == 0.55)
    #expect(minimum.fieldScale == 1.50)
    #expect(maximum.particleCount == 64)
    #expect(maximum.spread == 1.10)
    #expect(maximum.fieldScale == 3.00)
  }

  @Test("Standard configuration remains stable")
  func standardConfiguration() {
    #expect(PoofConfiguration.standard == PoofConfiguration())
    #expect(PoofConfiguration.standard.particleCount == 28)
    #expect(PoofConfiguration.standard.spread == 0.82)
    #expect(PoofConfiguration.standard.fieldScale == 2.10)
    #expect(PoofConfiguration.standard.seed == nil)
  }

  @Test("A nil seed uses stable shapes and allows playback variation")
  func nilSeed() {
    let first = PoofConfiguration()
    let second = PoofConfiguration()

    #expect(first.seed == nil)
    #expect(second.seed == nil)
    #expect(first.particles == second.particles)
  }

  @Test("An explicit seed is retained and repeatable")
  func explicitSeed() {
    let first = PoofConfiguration(seed: 0xCAFE_BABE)
    let second = PoofConfiguration(seed: 0xCAFE_BABE)
    let different = PoofConfiguration(seed: 0xDEAD_BEEF)

    #expect(first.seed == 0xCAFE_BABE)
    #expect(first == second)
    #expect(first.particles == second.particles)
    #expect(first.particles != different.particles)
  }

  @Test("Nonfinite dimensions resolve to defaults")
  func nonfiniteDimensions() {
    let configuration = PoofConfiguration(
      spread: .nan,
      fieldScale: .infinity
    )

    #expect(configuration.spread == 0.82)
    #expect(configuration.fieldScale == 2.10)
    #expect(
      configuration.particles.allSatisfy { $0.distance.isFinite }
    )
  }
}
