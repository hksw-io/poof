import Foundation

/// Counter-based seeded noise.
///
/// Every value is a pure function of a seed and a key, so nothing has to
/// remember what it drew last. That is what keeps a playback repeatable, keeps
/// it scrubbable, and lets callers skip a draw they turn out not to need
/// without changing anything downstream.
enum PoofNoise {
  /// A value in `-1...1` for a seed and key.
  static func value(seed: UInt64, key: UInt64) -> Double {
    var random = SplitMix64(
      seed: seed
        ^ (key &* 0xD6E8_FEB8_6659_FD93)
    )
    return random.value(in: -1...1)
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

  /// The quintic smoothstep, zero-sloped at both ends.
  static func smootherStep(_ amount: Double) -> Double {
    let amount = min(max(amount, 0), 1)
    let cubed = amount * amount * amount
    return cubed * (amount * (amount * 6 - 15) + 10)
  }

  /// ``smootherStep(_:)`` over an arbitrary interval.
  static func smootherStep(
    from start: Double,
    to end: Double,
    at amount: Double
  ) -> Double {
    guard end > start else {
      return amount >= end ? 1 : 0
    }

    return smootherStep((amount - start) / (end - start))
  }
}

struct SplitMix64 {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func value(in range: ClosedRange<Double>) -> Double {
    let upperBits = next() >> 11
    let unit = Double(upperBits) * 0x1.0p-53
    return range.lowerBound
      + (range.upperBound - range.lowerBound) * unit
  }

  private mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }
}
