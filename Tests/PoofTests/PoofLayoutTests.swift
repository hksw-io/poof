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
    let size = PoofLayout.canvasSize(
      for: CGSize(width: 4_000, height: 44),
      fieldScale: 3,
      coversSource: true
    )

    #expect(size.width == 4_080)
    #expect(size.height == 480)
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

  @Test("Source-cover aspect follows the laid-out bounds")
  func sourceCoverAspect() {
    #expect(
      PoofSourceCoverAspect(size: CGSize(width: 84, height: 84))
        == .square
    )
    #expect(
      PoofSourceCoverAspect(size: CGSize(width: 132, height: 48))
        == .wide
    )
    #expect(
      PoofSourceCoverAspect(size: CGSize(width: 48, height: 132))
        == .tall
    )
  }
}
