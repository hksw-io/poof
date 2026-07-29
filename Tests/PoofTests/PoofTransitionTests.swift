import SwiftUI
import Testing

@testable import Poof

@MainActor
@Suite("Poof transition")
struct PoofTransitionTests {
  @Test("Insertion stays quiet")
  func insertion() {
    let state = PoofTransition.state(for: .willAppear)

    #expect(state.progress == 0)
    #expect(!state.isRemoving)
  }

  @Test("Identity keeps the source visible")
  func identity() {
    let state = PoofTransition.state(for: .identity)

    #expect(state.progress == 0)
    #expect(!state.isRemoving)
  }

  @Test("Removal starts the poof and retires source interaction")
  func removal() {
    let state = PoofTransition.state(for: .didDisappear)

    #expect(state.progress == 1)
    #expect(state.isRemoving)
  }

  @Test("Core configuration and transition values are Sendable")
  func sendableTypes() {
    requireSendable(PoofConfiguration.self)
    requireSendable(PoofTransition.self)
  }

  private func requireSendable<T: Sendable>(_: T.Type) {}
}
