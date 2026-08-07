import Foundation
import SwiftUI
import Testing

@testable import Poof

@MainActor
@Suite("Point poof")
struct PoofEmissionTests {
  @Test("An emission snapshots its playback inputs")
  func snapshotsInputs() throws {
    let id = try #require(UUID(uuidString: "504F4F46-0000-0000-0000-000000000001"))
    let location = CGPoint(x: 24, y: 36)
    let configuration = PoofConfiguration(
      particleCount: 40,
      spread: 1,
      fieldScale: 2.5,
      seed: 0x504F_4F46
    )
    let palette = PoofPalette(colors: [.red, .blue])
    let emission = try #require(
      PoofEmission(
        location: location,
        size: 96,
        style: .bloom,
        configuration: configuration,
        palette: palette,
        id: id
      )
    )

    #expect(emission.id == id)
    #expect(emission.location == location)
    #expect(emission.size == 96)
    #expect(emission.style == .bloom)
    #expect(emission.configuration == configuration)
    #expect(emission.palette == palette)
    #expect(emission.frameSet.variationSeed == configuration.seed)
  }

  @Test("Emission size is bounded and nonfinite values use the default")
  func resolvesSize() throws {
    let cases: [(input: CGFloat, expected: CGFloat)] = [
      (-1, 42),
      (42, 42),
      (84, 84),
      (160, 160),
      (1_000, 160),
      (.nan, 84),
      (.infinity, 84),
      (-.infinity, 84),
    ]

    for testCase in cases {
      let emission = try #require(
        PoofEmission(
          location: .zero,
          size: testCase.input,
          style: .classic,
          configuration: .standard,
          palette: .automatic
        )
      )

      #expect(emission.size == testCase.expected)
    }
  }

  @Test("Nonfinite locations do not emit")
  func rejectsNonfiniteLocations() {
    let locations = [
      CGPoint(x: CGFloat.nan, y: 0),
      CGPoint(x: 0, y: CGFloat.infinity),
      CGPoint(x: -CGFloat.infinity, y: 0),
    ]

    for location in locations {
      #expect(
        PoofEmission(
          location: location,
          size: 84,
          style: .classic,
          configuration: .standard,
          palette: .automatic
        ) == nil
      )
    }
  }

  @Test("Point poof modifier supports default and styled calls")
  func publicModifierAPI() {
    requireView(
      Color.clear.poof(at: CGPoint(x: 10, y: 20), trigger: 1)
    )
    requireView(
      Color.clear.poof(
        at: CGPoint(x: 30, y: 40),
        size: 120,
        style: .snap,
        configuration: PoofConfiguration(seed: 7),
        palette: .pastel,
        trigger: "again"
      )
    )
    requireSendable(PoofEmission.self)
  }

  private func requireView<Content: View>(_: Content) {}

  private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
