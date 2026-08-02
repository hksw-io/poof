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

  // A one-second playback makes the style choices readable in documentation.
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
      id: "classic-grayscale",
      style: .classic,
      palette: .automatic,
      title: "Classic",
      detail: "Grayscale"
    ),
    MediaOption(
      id: "bloom-grayscale",
      style: .bloom,
      palette: .automatic,
      title: "Bloom",
      detail: "Grayscale"
    ),
    MediaOption(
      id: "bloom-pastel",
      style: .bloom,
      palette: .pastel,
      title: "Bloom",
      detail: "Pastel"
    ),
    MediaOption(
      id: "snap-custom",
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

        Text("Style and color can be chosen independently")
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
        poofPalette: option.palette
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

private struct PoofStage: View {
  // A fixed seed keeps committed media stable when only the generator changes.
  private static let configuration = PoofConfiguration(seed: 0x504F_4F46)

  let frame: CaptureFrame
  let side: CGFloat
  let palette: MediaPalette
  var style = PoofStyle.classic
  var poofPalette = PoofPalette.automatic

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
          palette: poofPalette
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

struct MediaPalette {
  let accent: Color
  let border: Color
  let card: Color
  let chrome: Color
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
      page = Color(red: 0.055, green: 0.06, blue: 0.07)
      secondaryText = Color.white.opacity(0.62)
      shadow = Color.black.opacity(0.48)
      surface = Color(red: 0.075, green: 0.08, blue: 0.095)
      text = Color.white.opacity(0.94)
    default:
      border = Color.black.opacity(0.12)
      card = Color(red: 0.97, green: 0.975, blue: 0.985)
      chrome = Color(red: 0.94, green: 0.945, blue: 0.955)
      page = Color(red: 0.91, green: 0.925, blue: 0.95)
      secondaryText = Color.black.opacity(0.56)
      shadow = Color.black.opacity(0.18)
      surface = .white
      text = Color.black.opacity(0.88)
    }
  }
}
