import Testing

@testable import PoofMediaGenerator

@Suite("GIF stability")
struct GIFWriterTests {
  @Test("Each equivalence threshold is the deciding one somewhere")
  func everyThresholdDecides() {
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
