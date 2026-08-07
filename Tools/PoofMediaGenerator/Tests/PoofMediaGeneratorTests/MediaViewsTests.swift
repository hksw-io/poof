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

@Suite("Social clips")
struct SocialClipTests {
  @Test("The grid columns cover every style and all three color choices")
  func gridColumns() {
    let columns = SocialCell.columns

    #expect(columns.map(\.style) == [.classic, .bloom, .snap])
    #expect(columns[0].palette == .automatic)
    #expect(columns[1].palette == .pastel)
    // A caller-supplied palette, which is the third thing color can be.
    #expect(columns[2].palette != .automatic)
    #expect(columns[2].palette != .pastel)
    #expect(Set(columns.map(\.id)).count == columns.count)
  }

  @Test("A clip is every pose and then the empty frame, with no source")
  func sequenceShape() {
    for frames in [SocialSequence.grid, SocialSequence.hero] {
      // One image per pose and nothing between them: the playback is a
      // sequence of hard swaps, so anything finer would render duplicates.
      #expect(frames.count == SocialSequence.poseProgresses.count + 1)
      #expect(frames.allSatisfy { $0.delay > 0 })

      // The smoke is the subject. Nothing stands in for a view being removed,
      // so no frame paints a placeholder.
      #expect(!frames.contains { $0.phase == .source })

      if case .empty = frames.last?.phase {
      } else {
        Issue.record("a clip should end empty")
      }

      let poses = frames.dropLast()

      #expect(
        poses.map(\.phase)
          == SocialSequence.poseProgresses.map { CaptureFrame.Phase.poof($0) }
      )
      // Every pose is held for the same beat, so no pose reads as emphasized.
      #expect(Set(poses.map(\.delay)).count == 1)
    }
  }

  @Test("Each pose is held far longer than production timing")
  func posesAreSlowedForReading() {
    let poseHold = SocialSequence.grid.first?.delay ?? 0

    // Production runs a pose in a fifteenth of a second, which is a blur in a
    // feed. The clips trade fidelity for legibility here, deliberately.
    #expect(poseHold > 1.0 / 15.0)
    #expect(poseHold < 0.5)
  }

  @Test("Clips loop in the few seconds a feed gives them")
  func clipsAreShort() {
    for frames in [SocialSequence.grid, SocialSequence.hero] {
      let total = frames.reduce(0.0) { $0 + $1.delay }

      #expect(total > 2)
      #expect(total < 5)
    }
  }
}
