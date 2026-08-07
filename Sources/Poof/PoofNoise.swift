/// Counter-based seeded noise.
///
/// Every value is a pure function of a seed and a key, so nothing has to
/// remember what it drew last. That is what keeps a playback repeatable and
/// lets callers skip a draw they turn out not to need without changing
/// anything downstream.
enum PoofNoise {
  /// A value in `-1...1` for a seed and key.
  static func value(seed: UInt64, key: UInt64) -> Double {
    var value =
      (seed ^ (key &* 0xD6E8_FEB8_6659_FD93))
      &+ 0x9E37_79B9_7F4A_7C15
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    value ^= value >> 31

    let unit = Double(value >> 11) * 0x1.0p-53
    return -1 + 2 * unit
  }

  /// A value in `0...1` for a seed and key.
  static func unitValue(seed: UInt64, key: UInt64) -> Double {
    (value(seed: seed, key: key) + 1) / 2
  }

  /// A value inside `range` for a seed and key.
  static func value(
    seed: UInt64,
    key: UInt64,
    in range: ClosedRange<Double>
  ) -> Double {
    range.lowerBound
      + (range.upperBound - range.lowerBound)
      * unitValue(seed: seed, key: key)
  }
}
