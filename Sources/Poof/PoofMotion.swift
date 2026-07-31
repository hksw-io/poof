/// How a poof moves between its five authored poses.
public enum PoofMotion: Hashable, Sendable {
  /// Holds each pose for one frame at 15 frames per second.
  case stepped

  /// Moves persistent puffs continuously between poses.
  ///
  /// Puffs scale in and out at staggered, playback-seeded moments.
  case smooth
}
