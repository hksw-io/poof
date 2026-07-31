/// The visual character of a poof.
///
/// Every style uses the same five-pose, one-third-second playback. Use
/// ``classic`` for the clean-room recreation of the former AppKit effect, or
/// choose one of the modern styles for a more expressive removal.
public enum PoofStyle: Hashable, Sendable {
  /// The crisp, compact clean-room recreation.
  case classic

  /// A rounder cloud with fuller, softer smoke shapes.
  case bloom

  /// A compact opening followed by a punchier radial snap.
  case snap
}
