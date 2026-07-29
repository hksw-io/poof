import CoreGraphics
import Testing

@testable import Poof

@Suite("Transition layout")
struct PoofLayoutTests {
  @Test("Small views use the measured 42-point reference size")
  func minimumReferenceSize() {
    let side = PoofLayout.fieldSide(
      for: CGSize(width: 12, height: 12),
      fieldScale: 2
    )

    #expect(side == 84)
  }

  @Test("Wide rows keep overscan bounded")
  func wideRow() {
    let side = PoofLayout.fieldSide(
      for: CGSize(width: 4_000, height: 44),
      fieldScale: 3
    )

    #expect(side == 480)
  }

  @Test("Invalid geometry remains finite")
  func invalidGeometry() {
    let side = PoofLayout.fieldSide(
      for: CGSize(width: CGFloat.nan, height: CGFloat.infinity),
      fieldScale: PoofConfiguration.standard.fieldScale
    )

    #expect(side.isFinite)
    #expect(
      side == 42 * CGFloat(PoofConfiguration.standard.fieldScale)
    )
  }
}
