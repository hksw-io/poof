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

  @Test("Each equivalence threshold is the deciding one somewhere")
  func everyThresholdDecides() {
    // These constants decide whether committed media gets rewritten, and the
    // three cases above are all settled by the channel-delta or changed-count
    // limits. Without a case that only the total can reject, that constant
    // could be raised to any value at all and nothing would notice.
    let base = [UInt8](repeating: 128, count: 4_000)

    func changed(count: Int, by delta: UInt8) -> [UInt8] {
      var pixels = base

      for index in 0..<count {
        pixels[index] += delta
      }

      return pixels
    }

    // Inside every limit.
    #expect(
      GIFWriter.pixelsAreEquivalent(base, changed(count: 300, by: 10))
    )
    // Only the per-channel delta rejects this one.
    #expect(
      !GIFWriter.pixelsAreEquivalent(base, changed(count: 10, by: 13))
    )
    // Only the changed-channel count rejects this one.
    #expect(
      !GIFWriter.pixelsAreEquivalent(base, changed(count: 513, by: 1))
    )
    // Only the total delta rejects this one: 500 channels is under the count
    // limit and 10 is under the per-channel limit, but 5000 is over the total.
    #expect(
      !GIFWriter.pixelsAreEquivalent(base, changed(count: 500, by: 10))
    )
  }
}
