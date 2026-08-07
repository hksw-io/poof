import Poof
import SwiftUI

/// The cells of the social grid.
///
/// Six cells cover what the package actually offers: all three styles, the
/// grayscale default, the built-in pastel palette, a caller-supplied palette,
/// and both appearances. The same three columns repeat in the dark row so a
/// viewer reads the appearance change rather than hunting for what else moved.
struct SocialCell: Identifiable, Sendable {
  static let columns: [SocialCell] = [
    SocialCell(
      id: "classic",
      style: .classic,
      palette: .automatic,
      title: "Classic",
      detail: "Grayscale"
    ),
    SocialCell(
      id: "bloom",
      style: .bloom,
      palette: .pastel,
      title: "Bloom",
      detail: "Pastel"
    ),
    SocialCell(
      id: "snap",
      style: .snap,
      palette: PoofPalette(
        colors: [
          Color(red: 1.00, green: 0.63, blue: 0.52),
          Color(red: 0.48, green: 0.78, blue: 1.00),
          Color(red: 0.56, green: 0.90, blue: 0.68),
          Color(red: 0.78, green: 0.67, blue: 1.00),
        ]
      ),
      title: "Snap",
      detail: "Custom palette"
    ),
  ]

  let id: String
  let style: PoofStyle
  let palette: PoofPalette
  let title: String
  let detail: String
}

/// Timings for the social clips.
///
/// The clips show the smoke and nothing else: no stand-in view sits under it
/// waiting to be removed, because the effect is the subject and a placeholder
/// icon only invites the reader to wonder what app it belongs to. A playback
/// is five hard pose swaps, so a whole clip is six images — one per pose, plus
/// the empty frame. Holding each pose well past its production one-fifteenth
/// of a second is what makes the sequence readable at a glance in a feed.
///
/// The trailing empty hold is also the lead-in, since the clips loop.
enum SocialSequence {
  static let poseProgresses = [0.1, 0.3, 0.5, 0.7, 0.9]

  static func frames(
    poseHold: Double,
    emptyHold: Double
  ) -> [CaptureFrame] {
    poseProgresses.map {
      CaptureFrame(phase: .poof($0), delay: poseHold)
    } + [CaptureFrame(phase: .empty, delay: emptyHold)]
  }

  /// The grid loops a little quicker, because six cells carry the reading.
  static let grid = frames(
    poseHold: 0.20,
    emptyHold: 1.05
  )

  static let hero = frames(
    poseHold: 0.24,
    emptyHold: 1.25
  )
}

/// The grid clip: three styles across, light above and dark below.
///
/// Both bands hold cards of the same height, so the only thing that changes
/// between the rows is the appearance — which is the comparison being made.
struct SocialGrid: View {
  static let size = CGSize(width: 1920, height: 1080)

  private static let headerHeight = 172.0
  private static let bandHeight = 454.0
  private static let cardHeight = 372.0
  private static let sourceSide = 208.0

  let frame: CaptureFrame

  var body: some View {
    let light = MediaPalette(appearance: .light)

    VStack(spacing: 0) {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          Text("Poof")
            .font(.system(size: 60, weight: .heavy, design: .rounded))
            .foregroundStyle(light.text)

          Text("The classic Mac poof, recreated for SwiftUI")
            .font(.system(size: 25, weight: .medium, design: .rounded))
            .foregroundStyle(light.secondaryText)
        }
        .frame(height: Self.headerHeight)

        band(appearance: .light)
      }
      .frame(maxWidth: .infinity)
      .background(light.page)

      band(appearance: .dark)
        .frame(maxWidth: .infinity)
        .background(MediaPalette(appearance: .dark).page)
    }
    .frame(width: Self.size.width, height: Self.size.height)
  }

  private func band(appearance: ColorScheme) -> some View {
    let palette = MediaPalette(appearance: appearance)

    return VStack(alignment: .leading, spacing: 12) {
      Text(appearance == .dark ? "Dark" : "Light")
        .font(.system(size: 17, weight: .semibold, design: .rounded))
        .foregroundStyle(palette.secondaryText)

      HStack(spacing: 26) {
        ForEach(SocialCell.columns) { cell in
          SocialCard(
            cell: cell,
            frame: frame,
            palette: palette,
            height: Self.cardHeight,
            sourceSide: Self.sourceSide
          )
        }
      }
    }
    .padding(.horizontal, 60)
    .frame(height: Self.bandHeight)
    .environment(\.colorScheme, appearance)
  }
}

private struct SocialCard: View {
  let cell: SocialCell
  let frame: CaptureFrame
  let palette: MediaPalette
  let height: Double
  let sourceSide: Double

  var body: some View {
    VStack(spacing: 4) {
      Text(cell.title)
        .font(.system(size: 27, weight: .semibold, design: .rounded))
        .foregroundStyle(palette.text)

      Text(cell.detail)
        .font(.system(size: 18, weight: .medium, design: .rounded))
        .foregroundStyle(palette.secondaryText)

      SocialStage(
        frame: frame,
        sourceSide: sourceSide,
        style: cell.style,
        poofPalette: cell.palette
      )
      .frame(maxHeight: .infinity)
    }
    .padding(.top, 22)
    .padding(.bottom, 10)
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .background {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(palette.card)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(palette.border, lineWidth: 1)
    }
  }
}

/// The hero clip: one poof, large and slow.
struct SocialHero: View {
  static let size = CGSize(width: 1920, height: 1080)

  let frame: CaptureFrame

  var body: some View {
    let palette = MediaPalette(appearance: .dark)

    ZStack {
      palette.page

      VStack(spacing: 26) {
        SocialStage(frame: frame, sourceSide: 380)

        VStack(spacing: 10) {
          Text("Poof")
            .font(.system(size: 68, weight: .heavy, design: .rounded))
            .foregroundStyle(palette.text)

          Text("A removal transition for SwiftUI, in one line")
            .font(.system(size: 27, weight: .medium, design: .rounded))
            .foregroundStyle(palette.secondaryText)

          Text(".transition(.poof)")
            .font(.system(size: 25, weight: .semibold, design: .monospaced))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(palette.card, in: .rect(cornerRadius: 14))
            .overlay {
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
            }
            .padding(.top, 6)
        }
      }
    }
    .frame(width: Self.size.width, height: Self.size.height)
    .environment(\.colorScheme, .dark)
  }
}

/// The smoke alone, at social scale.
///
/// The stage is sized from the source bounds rather than the other way round:
/// the smoke fills roughly the bounds it is given, so that side is what
/// decides how large the poof reads. The box around it only has to leave room
/// for the spread.
private struct SocialStage: View {
  // The committed media's seed, so a clip and the README show one poof.
  private static let configuration = PoofConfiguration(seed: 0x504F_4F46)
  private static let spreadAllowance = 1.32

  let frame: CaptureFrame
  let sourceSide: CGFloat
  var style = PoofStyle.classic
  var poofPalette = PoofPalette.automatic

  private var side: CGFloat {
    sourceSide * Self.spreadAllowance
  }

  var body: some View {
    ZStack {
      if case .poof(let progress) = frame.phase {
        PoofEffect(
          progress: progress,
          style: style,
          configuration: Self.configuration,
          palette: poofPalette
        )
        .frame(width: sourceSide, height: sourceSide)
      }
    }
    .frame(width: side, height: side)
  }
}
