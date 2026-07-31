import Poof
import Testing

@testable import PoofMediaGenerator

@Suite("README media")
struct MediaViewsTests {
  @Test("Option playback samples progress continuously")
  func optionPlaybackSamplesProgressContinuously() {
    let frames = CaptureFrame.optionSequence
    let progressValues = frames.compactMap { frame -> Double? in
      guard case .poof(let progress) = frame.phase else {
        return nil
      }
      return progress
    }

    #expect(frames.first?.phase == .source)
    #expect(frames.last?.phase == .empty)
    #expect(progressValues.count == 25)
    #expect(progressValues.first == 0.02)
    #expect(progressValues.last == 0.98)
    #expect(
      zip(progressValues, progressValues.dropFirst())
        .allSatisfy(<)
    )
    #expect(
      abs(frames.reduce(0) { $0 + $1.delay } - 2.5)
        < 0.000_001
    )
  }

  @Test("Option cards cover motion, style, and color choices")
  func optionCardsCoverChoices() {
    let options = MediaOption.all

    #expect(options.count == 4)
    #expect(options.map(\.motion) == [.stepped, .smooth, .smooth, .smooth])
    #expect(options.map(\.style) == [.classic, .classic, .bloom, .snap])
    #expect(options[0].palette == .automatic)
    #expect(options[1].palette == .automatic)
    #expect(options[2].palette == .pastel)
    #expect(options[3].palette != .automatic)
    #expect(Set(options.map(\.id)).count == options.count)
  }
}
