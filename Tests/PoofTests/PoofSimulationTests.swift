import Foundation
import Testing

@testable import Poof

@Suite("Particle simulation")
struct PoofSimulationTests {
  @Test("A seed produces the same field every time")
  func deterministicField() {
    let configuration = PoofConfiguration(
      particleCount: 24,
      seed: 0xCAFE_BABE
    )

    let first = particles(for: configuration)
    let second = particles(for: configuration)

    #expect(first == second)
  }

  @Test("Different seeds produce different fields")
  func seedChangesField() {
    let first = particles(
      for: PoofConfiguration(particleCount: 24, seed: 1)
    )
    let second = particles(
      for: PoofConfiguration(particleCount: 24, seed: 2)
    )

    #expect(first != second)
  }

  @Test("Particle values remain finite across the animation")
  func finiteValues() {
    let configuration = PoofConfiguration(
      particleCount: 64,
      spread: 1.10,
      fieldScale: 3
    )

    for particle in particles(for: configuration) {
      for progress in stride(from: -0.2, through: 1.2, by: 0.05) {
        let state = PoofSimulation.state(
          for: particle,
          progress: progress,
          reducesTransparency: false
        )

        #expect(state.x.isFinite)
        #expect(state.y.isFinite)
        #expect(state.width.isFinite)
        #expect(state.height.isFinite)
        #expect(state.opacity.isFinite)
        #expect(state.width >= 0)
        #expect(state.height >= 0)
        #expect((0...1).contains(state.opacity))
      }
    }
  }

  @Test("The first and last frames are transparent")
  func transparentEndpoints() {
    let configuration = PoofConfiguration.standard

    for particle in particles(for: configuration) {
      let first = PoofSimulation.state(
        for: particle,
        progress: 0,
        reducesTransparency: false
      )
      let last = PoofSimulation.state(
        for: particle,
        progress: 1,
        reducesTransparency: false
      )

      #expect(first.opacity == 0)
      #expect(last.opacity == 0)
    }
  }

  @Test("Progress is clamped")
  func progressClamping() {
    let particle = PoofConfiguration.standard.particles[0]

    let beforeStart = PoofSimulation.state(
      for: particle,
      progress: -10,
      reducesTransparency: false
    )
    let start = PoofSimulation.state(
      for: particle,
      progress: 0,
      reducesTransparency: false
    )
    let end = PoofSimulation.state(
      for: particle,
      progress: 1,
      reducesTransparency: false
    )
    let afterEnd = PoofSimulation.state(
      for: particle,
      progress: 10,
      reducesTransparency: false
    )

    #expect(beforeStart == start)
    #expect(afterEnd == end)
  }

  @Test("Particles expand away from the origin")
  func outwardTravel() {
    let configuration = PoofConfiguration.standard
    var outwardCount = 0
    var earlyDistance = 0.0
    var lateDistance = 0.0

    for particle in particles(for: configuration) {
      let early = PoofSimulation.state(
        for: particle,
        progress: 0.20,
        reducesTransparency: false
      )
      let late = PoofSimulation.state(
        for: particle,
        progress: 0.70,
        reducesTransparency: false
      )
      let earlyRadius = hypot(early.x, early.y)
      let lateRadius = hypot(late.x, late.y)

      earlyDistance += earlyRadius
      lateDistance += lateRadius

      if lateRadius > earlyRadius {
        outwardCount += 1
      }
    }

    #expect(outwardCount >= configuration.particleCount * 4 / 5)
    #expect(lateDistance > earlyDistance)
  }

  @Test("Reduce Transparency keeps smoke solid for longer")
  func reduceTransparency() {
    let configuration = PoofConfiguration.standard

    for particle in particles(for: configuration) {
      let standard = PoofSimulation.state(
        for: particle,
        progress: 0.60,
        reducesTransparency: false
      )
      let reduced = PoofSimulation.state(
        for: particle,
        progress: 0.60,
        reducesTransparency: true
      )

      #expect(reduced.opacity > standard.opacity)
    }
  }

  @Test("Smoothstep has stable boundaries and midpoint")
  func smoothstep() {
    #expect(
      PoofSimulation.smoothstep(edge0: 0, edge1: 1, value: -1) == 0
    )
    #expect(
      PoofSimulation.smoothstep(edge0: 0, edge1: 1, value: 0.5) == 0.5
    )
    #expect(
      PoofSimulation.smoothstep(edge0: 0, edge1: 1, value: 2) == 1
    )
  }

  private func particles(
    for configuration: PoofConfiguration
  ) -> [PoofParticle] {
    configuration.particles
  }
}
