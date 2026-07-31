import Poof
import SwiftUI

struct CaptureFrame: Equatable, Sendable {
  enum Phase: Equatable, Sendable {
    case empty
    case poof(Double)
    case source
  }

  private static let optionAnimationFrameCount = 25

  // GIF delays use centiseconds. Alternating 7 and 6 keeps the five-pose
  // playback at 0.33 seconds instead of rounding every pose up.
  static let sequence = [
    CaptureFrame(phase: .source, delay: 0.90),
    CaptureFrame(phase: .poof(0.10), delay: 0.07),
    CaptureFrame(phase: .poof(0.30), delay: 0.06),
    CaptureFrame(phase: .poof(0.50), delay: 0.07),
    CaptureFrame(phase: .poof(0.70), delay: 0.06),
    CaptureFrame(phase: .poof(0.90), delay: 0.07),
    CaptureFrame(phase: .empty, delay: 0.90),
  ]

  // A one-second playback makes the motion choices readable in documentation.
  // Twenty-five frames also maps cleanly to GIF centisecond delays.
  static let optionSequence =
    [CaptureFrame(phase: .source, delay: 0.75)]
    + (0..<optionAnimationFrameCount).map { frameIndex in
      CaptureFrame(
        phase: .poof(
          (Double(frameIndex) + 0.5)
            / Double(optionAnimationFrameCount)
        ),
        delay: 0.04
      )
    }
    + [CaptureFrame(phase: .empty, delay: 0.75)]

  let phase: Phase
  let delay: Double
}

struct MediaOption: Identifiable, Sendable {
  static let all = [
    MediaOption(
      id: "classic-stepped",
      style: .classic,
      motion: .stepped,
      palette: .automatic,
      title: "Classic",
      detail: "Stepped · Grayscale"
    ),
    MediaOption(
      id: "classic-smooth",
      style: .classic,
      motion: .smooth,
      palette: .automatic,
      title: "Classic",
      detail: "Smooth · Grayscale"
    ),
    MediaOption(
      id: "bloom-pastel",
      style: .bloom,
      motion: .smooth,
      palette: .pastel,
      title: "Bloom",
      detail: "Smooth · Pastel"
    ),
    MediaOption(
      id: "snap-custom",
      style: .snap,
      motion: .smooth,
      palette: PoofPalette(
        colors: [
          Color(red: 1.00, green: 0.63, blue: 0.52),
          Color(red: 0.48, green: 0.78, blue: 1.00),
          Color(red: 0.56, green: 0.90, blue: 0.68),
          Color(red: 0.78, green: 0.67, blue: 1.00),
        ]
      ),
      title: "Snap",
      detail: "Smooth · Custom palette"
    ),
  ]

  let id: String
  let style: PoofStyle
  let motion: PoofMotion
  let palette: PoofPalette
  let title: String
  let detail: String
}

struct MacPreview: View {
  let appearance: ColorScheme
  let frame: CaptureFrame

  private var palette: MediaPalette {
    MediaPalette(appearance: appearance)
  }

  var body: some View {
    ZStack {
      palette.page

      VStack(spacing: 0) {
        titleBar

        ZStack {
          palette.surface

          PoofStage(frame: frame, side: 174, palette: palette)
        }
        .frame(height: 292)
      }
      .frame(width: 540)
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(palette.border, lineWidth: 1)
      }
      .compositingGroup()
      .shadow(color: palette.shadow, radius: 16, y: 10)
    }
    .frame(width: 640, height: 400)
    .environment(\.colorScheme, appearance)
  }

  private var titleBar: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(Color(red: 0.98, green: 0.37, blue: 0.34))
        .frame(width: 13, height: 13)
      Circle()
        .fill(Color(red: 0.98, green: 0.74, blue: 0.22))
        .frame(width: 13, height: 13)
      Circle()
        .fill(Color(red: 0.25, green: 0.78, blue: 0.35))
        .frame(width: 13, height: 13)

      Spacer()

      Text("Poof")
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(palette.secondaryText)

      Spacer()

      Color.clear
        .frame(width: 52)
    }
    .frame(height: 48)
    .padding(.horizontal, 16)
    .background(palette.chrome)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(palette.border)
        .frame(height: 1)
    }
  }
}

struct OptionsPreview: View {
  let appearance: ColorScheme
  let frame: CaptureFrame

  private var palette: MediaPalette {
    MediaPalette(appearance: appearance)
  }

  var body: some View {
    VStack(spacing: 18) {
      VStack(spacing: 5) {
        Text("One poof, four choices")
          .font(.system(size: 25, weight: .bold, design: .rounded))
          .foregroundStyle(palette.text)

        Text("Style, motion, and color can be chosen independently")
          .font(.system(size: 14, weight: .medium, design: .rounded))
          .foregroundStyle(palette.secondaryText)
      }

      Grid(horizontalSpacing: 16, verticalSpacing: 16) {
        GridRow {
          ForEach(MediaOption.all.prefix(2)) { option in
            OptionCard(
              option: option,
              frame: frame,
              palette: palette
            )
          }
        }

        GridRow {
          ForEach(MediaOption.all.suffix(2)) { option in
            OptionCard(
              option: option,
              frame: frame,
              palette: palette
            )
          }
        }
      }
    }
    .frame(width: 940, height: 580)
    .background(palette.page)
    .environment(\.colorScheme, appearance)
  }
}

private struct OptionCard: View {
  let option: MediaOption
  let frame: CaptureFrame
  let palette: MediaPalette

  var body: some View {
    VStack(spacing: 2) {
      Text(option.title)
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundStyle(palette.text)

      Text(option.detail)
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(palette.secondaryText)

      PoofStage(
        frame: frame,
        side: 158,
        palette: palette,
        style: option.style,
        poofPalette: option.palette,
        motion: option.motion
      )
    }
    .padding(.top, 12)
    .frame(width: 438, height: 220)
    .background {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(palette.card)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(palette.border, lineWidth: 1)
    }
  }
}

struct PlatformPreview: View {
  let appearance: ColorScheme
  let frame: CaptureFrame

  private let columns: [PlatformKind] = [.mac, .iPhone, .iPad]
  private let secondRow: [PlatformKind] = [.watch, .tv, .visionPro]

  private var palette: MediaPalette {
    MediaPalette(appearance: appearance)
  }

  var body: some View {
    VStack(spacing: 18) {
      VStack(spacing: 5) {
        Text("One SwiftUI renderer")
          .font(.system(size: 25, weight: .bold, design: .rounded))
          .foregroundStyle(palette.text)

        Text("Representative control sizes across supported platforms")
          .font(.system(size: 14, weight: .medium, design: .rounded))
          .foregroundStyle(palette.secondaryText)
      }

      Grid(horizontalSpacing: 16, verticalSpacing: 16) {
        GridRow {
          ForEach(columns, id: \.self) { platform in
            PlatformCard(
              platform: platform,
              frame: frame,
              palette: palette
            )
          }
        }

        GridRow {
          ForEach(secondRow, id: \.self) { platform in
            PlatformCard(
              platform: platform,
              frame: frame,
              palette: palette
            )
          }
        }
      }
    }
    .frame(width: 940, height: 650)
    .background(palette.page)
    .environment(\.colorScheme, appearance)
  }
}

private struct PlatformCard: View {
  let platform: PlatformKind
  let frame: CaptureFrame
  let palette: MediaPalette

  var body: some View {
    VStack(spacing: 10) {
      Text(platform.title)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(palette.text)

      PlatformDevice(
        platform: platform,
        frame: frame,
        palette: palette
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(14)
    .frame(width: 288, height: 246)
    .background {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(palette.card)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(palette.border, lineWidth: 1)
    }
  }
}

private struct PlatformDevice: View {
  let platform: PlatformKind
  let frame: CaptureFrame
  let palette: MediaPalette

  @ViewBuilder
  var body: some View {
    switch platform {
    case .mac:
      MacDevice(frame: frame, palette: palette)
    case .iPhone:
      PhoneDevice(frame: frame, palette: palette)
    case .iPad:
      TabletDevice(frame: frame, palette: palette)
    case .watch:
      WatchDevice(frame: frame, palette: palette)
    case .tv:
      TVDevice(frame: frame, palette: palette)
    case .visionPro:
      VisionDevice(frame: frame, palette: palette)
    }
  }
}

private struct MacDevice: View {
  let frame: CaptureFrame
  let palette: MediaPalette

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(palette.device)
          .frame(width: 196, height: 130)

        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(palette.surface)
          .frame(width: 182, height: 111)

        PoofStage(frame: frame, side: 86, palette: palette)
      }

      Capsule()
        .fill(palette.device)
        .frame(width: 56, height: 9)
    }
  }
}

private struct PhoneDevice: View {
  let frame: CaptureFrame
  let palette: MediaPalette

  var body: some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 25, style: .continuous)
        .fill(palette.device)
        .frame(width: 91, height: 174)

      RoundedRectangle(cornerRadius: 21, style: .continuous)
        .fill(palette.surface)
        .frame(width: 81, height: 164)
        .padding(.top, 5)

      Capsule()
        .fill(palette.device)
        .frame(width: 29, height: 8)
        .padding(.top, 10)

      PoofStage(frame: frame, side: 72, palette: palette)
        .padding(.top, 47)
    }
  }
}

private struct TabletDevice: View {
  let frame: CaptureFrame
  let palette: MediaPalette

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(palette.device)
        .frame(width: 142, height: 174)

      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(palette.surface)
        .frame(width: 132, height: 164)

      PoofStage(frame: frame, side: 82, palette: palette)
    }
  }
}

private struct WatchDevice: View {
  let frame: CaptureFrame
  let palette: MediaPalette

  var body: some View {
    VStack(spacing: -2) {
      Capsule()
        .fill(palette.device)
        .frame(width: 48, height: 28)

      ZStack {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .fill(palette.device)
          .frame(width: 96, height: 112)

        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(palette.surface)
          .frame(width: 86, height: 102)

        PoofStage(frame: frame, side: 62, palette: palette)
      }

      Capsule()
        .fill(palette.device)
        .frame(width: 48, height: 28)
    }
  }
}

private struct TVDevice: View {
  let frame: CaptureFrame
  let palette: MediaPalette

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(palette.device)
          .frame(width: 202, height: 126)

        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(palette.surface)
          .frame(width: 190, height: 114)

        PoofStage(frame: frame, side: 82, palette: palette)
      }

      Rectangle()
        .fill(palette.device)
        .frame(width: 5, height: 13)

      Capsule()
        .fill(palette.device)
        .frame(width: 58, height: 7)
    }
  }
}

private struct VisionDevice: View {
  let frame: CaptureFrame
  let palette: MediaPalette

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(palette.surface)
        .frame(width: 202, height: 136)
        .overlay {
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(palette.device, lineWidth: 4)
        }

      HStack(spacing: 26) {
        Circle()
          .stroke(palette.border, lineWidth: 2)
        Circle()
          .stroke(palette.border, lineWidth: 2)
      }
      .frame(width: 118, height: 44)
      .opacity(0.45)

      PoofStage(frame: frame, side: 78, palette: palette)
    }
  }
}

private struct PoofStage: View {
  // A fixed seed keeps committed media stable when only the generator changes.
  private static let configuration = PoofConfiguration(seed: 0x504F_4F46)

  let frame: CaptureFrame
  let side: CGFloat
  let palette: MediaPalette
  var style = PoofStyle.classic
  var poofPalette = PoofPalette.automatic
  var motion = PoofMotion.stepped

  private var sourceSide: CGFloat {
    side * 0.68
  }

  var body: some View {
    ZStack {
      switch frame.phase {
      case .source:
        source
      case .poof(let progress):
        PoofEffect(
          progress: progress,
          style: style,
          configuration: Self.configuration,
          palette: poofPalette,
          motion: motion
        )
        .frame(width: sourceSide, height: sourceSide)
      case .empty:
        EmptyView()
      }
    }
    .frame(width: side, height: side)
  }

  private var source: some View {
    RoundedRectangle(cornerRadius: sourceSide * 0.16, style: .continuous)
      .fill(palette.accent)
      .frame(width: sourceSide, height: sourceSide)
      .overlay {
        PackageMark()
          .stroke(
            Color.white,
            style: StrokeStyle(
              lineWidth: max(sourceSide * 0.045, 1),
              lineCap: .round,
              lineJoin: .round
            )
          )
          .frame(width: sourceSide * 0.48, height: sourceSide * 0.48)
      }
  }
}

private struct PackageMark: Shape {
  func path(in rect: CGRect) -> Path {
    let drawingRect = rect.insetBy(
      dx: rect.width * 0.06,
      dy: rect.height * 0.06
    )
    let top = CGPoint(x: drawingRect.midX, y: drawingRect.minY)
    let upperLeft = CGPoint(
      x: drawingRect.minX,
      y: drawingRect.minY + drawingRect.height * 0.24
    )
    let upperRight = CGPoint(
      x: drawingRect.maxX,
      y: drawingRect.minY + drawingRect.height * 0.24
    )
    let center = CGPoint(
      x: drawingRect.midX,
      y: drawingRect.minY + drawingRect.height * 0.48
    )
    let lowerLeft = CGPoint(
      x: drawingRect.minX,
      y: drawingRect.minY + drawingRect.height * 0.76
    )
    let lowerRight = CGPoint(
      x: drawingRect.maxX,
      y: drawingRect.minY + drawingRect.height * 0.76
    )
    let bottom = CGPoint(x: drawingRect.midX, y: drawingRect.maxY)

    return Path { path in
      path.move(to: top)
      path.addLine(to: upperRight)
      path.addLine(to: center)
      path.addLine(to: upperLeft)
      path.closeSubpath()

      path.move(to: upperLeft)
      path.addLine(to: lowerLeft)
      path.addLine(to: bottom)
      path.addLine(to: center)

      path.move(to: upperRight)
      path.addLine(to: lowerRight)
      path.addLine(to: bottom)

      path.move(to: center)
      path.addLine(to: bottom)
    }
  }
}

enum PlatformKind: Hashable {
  case iPad
  case iPhone
  case mac
  case tv
  case visionPro
  case watch

  var title: String {
    switch self {
    case .iPad:
      "iPad"
    case .iPhone:
      "iPhone"
    case .mac:
      "Mac"
    case .tv:
      "Apple TV"
    case .visionPro:
      "Apple Vision Pro"
    case .watch:
      "Apple Watch"
    }
  }
}

struct MediaPalette {
  let accent: Color
  let border: Color
  let card: Color
  let chrome: Color
  let device: Color
  let page: Color
  let secondaryText: Color
  let shadow: Color
  let surface: Color
  let text: Color

  init(appearance: ColorScheme) {
    accent = Color(red: 0.10, green: 0.43, blue: 0.96)

    switch appearance {
    case .dark:
      border = Color.white.opacity(0.13)
      card = Color(red: 0.105, green: 0.11, blue: 0.13)
      chrome = Color(red: 0.13, green: 0.135, blue: 0.15)
      device = Color(red: 0.31, green: 0.32, blue: 0.35)
      page = Color(red: 0.055, green: 0.06, blue: 0.07)
      secondaryText = Color.white.opacity(0.62)
      shadow = Color.black.opacity(0.48)
      surface = Color(red: 0.075, green: 0.08, blue: 0.095)
      text = Color.white.opacity(0.94)
    default:
      border = Color.black.opacity(0.12)
      card = Color(red: 0.97, green: 0.975, blue: 0.985)
      chrome = Color(red: 0.94, green: 0.945, blue: 0.955)
      device = Color(red: 0.25, green: 0.26, blue: 0.29)
      page = Color(red: 0.91, green: 0.925, blue: 0.95)
      secondaryText = Color.black.opacity(0.56)
      shadow = Color.black.opacity(0.18)
      surface = .white
      text = Color.black.opacity(0.88)
    }
  }
}
