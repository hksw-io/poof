import SwiftUI

/// The fill colors used by a poof.
///
/// Outlines and detail marks remain neutral so every palette stays legible in
/// light and dark appearance.
public struct PoofPalette: Hashable, Sendable {
  /// Uses the original white and neutral-gray fills.
  public static let monochrome = PoofPalette(colors: [])

  /// Uses the default white and neutral-gray fills.
  public static let automatic = monochrome

  /// Uses restrained peach, sky, mint, and lavender fills.
  public static let pastel = PoofPalette(
    colors: [
      Color(red: 1.00, green: 0.88, blue: 0.82),
      Color(red: 0.82, green: 0.92, blue: 1.00),
      Color(red: 0.84, green: 0.97, blue: 0.88),
      Color(red: 0.91, green: 0.86, blue: 1.00),
    ]
  )

  let colors: [Color]

  /// Creates a palette from a repeating set of fill colors.
  ///
  /// Pass an empty array to use monochrome fills.
  public init(colors: [Color]) {
    self.colors = colors
  }
}
