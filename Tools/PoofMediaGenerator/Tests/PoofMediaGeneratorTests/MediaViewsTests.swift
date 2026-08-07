import Foundation
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

  @Test("Option cards cover style and color choices")
  func optionCardsCoverChoices() {
    let options = MediaOption.all

    #expect(options.count == 4)
    #expect(options.map(\.style) == [.classic, .bloom, .bloom, .snap])
    #expect(options[0].palette == .automatic)
    #expect(options[1].palette == .automatic)
    #expect(options[2].palette == .pastel)
    #expect(options[3].palette != .automatic)
    #expect(Set(options.map(\.id)).count == options.count)
  }
}

@Suite("Hero timing")
struct HeroTimingTests {
  @Test("The hero sequence plays the five poses at fifteen frames a second")
  func heroSequenceMatchesPlayback() {
    let frames = CaptureFrame.sequence
    let poses = frames.filter {
      if case .poof = $0.phase { return true }
      return false
    }

    // One frame per pose, sampled at the middle of each interval so the frame
    // lands on the pose it means to show rather than on a boundary.
    #expect(poses.count == 5)

    let playback = poses.reduce(0.0) { $0 + $1.delay }

    // GIF stores delays in centiseconds and one fifteenth of a second is not
    // representable, so the alternating 7 and 6 lands on 0.33 rather than
    // rounding every pose up to 0.35.
    #expect(abs(playback - 0.33) < 0.000_001)
    #expect(poses.allSatisfy { $0.delay == 0.07 || $0.delay == 0.06 })

    if case .source = frames.first?.phase {
    } else {
      Issue.record("the sequence should open on the source")
    }

    if case .empty = frames.last?.phase {
    } else {
      Issue.record("the sequence should end empty")
    }
  }
}
