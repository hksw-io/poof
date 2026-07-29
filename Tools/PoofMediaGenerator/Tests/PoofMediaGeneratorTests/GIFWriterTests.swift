import Testing

@testable import PoofMediaGenerator

@Suite("GIF stability")
struct GIFWriterTests {
  @Test("Small antialiasing differences are ignored")
  func antialiasingNoiseIsEquivalent() {
    let first = [UInt8](repeating: 128, count: 4_000)
    var second = first

    for index in 0..<300 {
      second[index] += UInt8(index % 11 + 1)
    }

    #expect(GIFWriter.pixelsAreEquivalent(first, second))
  }

  @Test("A visible block is not ignored")
  func visibleBlockIsDifferent() {
    let first = [UInt8](repeating: 128, count: 4_000)
    var second = first

    for index in 0..<675 {
      second[index] += 15
    }

    #expect(!GIFWriter.pixelsAreEquivalent(first, second))
  }

  @Test("Widespread small changes are not ignored")
  func widespreadChangeIsDifferent() {
    let first = [UInt8](repeating: 128, count: 4_000)
    let second = [UInt8](repeating: 129, count: 4_000)

    #expect(!GIFWriter.pixelsAreEquivalent(first, second))
  }
}
