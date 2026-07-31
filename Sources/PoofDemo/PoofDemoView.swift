#if os(macOS)
  import Foundation
  import Poof
  import SwiftUI

  struct PoofDemoView: View {
    @State private var appearance = DemoAppearance.system
    @State private var isItemVisible = true
    @State private var playbackSeed: UInt64 = 0x504F_4F46
    @State private var previewMode = DemoPreviewMode.animation
    @State private var surface = DemoSurface.roundedSquare
    @State private var palette = DemoPalette.automatic
    @State private var motion = DemoMotion.stepped
    @State private var playbackDuration = DemoPlaybackDuration.defaultValue

    var body: some View {
      VStack(spacing: 20) {
        DemoHeader()
        DemoComparisonGrid(
          isItemVisible: isItemVisible,
          playbackSeed: playbackSeed,
          previewMode: previewMode,
          surface: surface,
          palette: palette.poofPalette,
          motion: motion.poofMotion
        )
        DemoControls(
          appearance: $appearance,
          previewMode: $previewMode,
          surface: $surface,
          palette: $palette,
          motion: $motion,
          playbackDuration: $playbackDuration,
          isItemVisible: isItemVisible,
          toggleItem: toggleItem
        )
        AccessibilityStatus()
      }
      .padding(24)
      .frame(minWidth: 680, minHeight: 480)
      .preferredColorScheme(appearance.colorScheme)
      .onChange(of: previewMode) {
        isItemVisible = true
      }
      .onChange(of: surface) {
        isItemVisible = true
      }
      .onChange(of: palette) {
        isItemVisible = true
      }
      .onChange(of: motion) {
        isItemVisible = true
      }
    }

    private func toggleItem() {
      if isItemVisible {
        guard
          let animation = previewMode.playbackAnimation(
            duration: playbackDuration
          )
        else {
          return
        }

        withAnimation(animation) {
          isItemVisible = false
        }
      } else {
        // A shared seed keeps every style directly comparable.
        playbackSeed &+= 1
        isItemVisible = true
      }
    }
  }

  private struct DemoHeader: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        Text(
          "Three ways to poof",
          bundle: #bundle,
          comment: "Heading above the poof style comparison."
        )
        .font(.title2.weight(.semibold))

        Text(
          "The original, plus two playful takes designed for today.",
          bundle: #bundle,
          comment: "Description above the poof style comparison."
        )
        .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private struct DemoComparisonGrid: View {
    let isItemVisible: Bool
    let playbackSeed: UInt64
    let previewMode: DemoPreviewMode
    let surface: DemoSurface
    let palette: PoofPalette
    let motion: PoofMotion

    var body: some View {
      Grid(horizontalSpacing: 16, verticalSpacing: 16) {
        GridRow {
          DemoStylePreview(
            style: .classic,
            isItemVisible: isItemVisible,
            playbackSeed: playbackSeed,
            previewMode: previewMode,
            surface: surface,
            palette: palette,
            motion: motion
          )
          DemoStylePreview(
            style: .bloom,
            isItemVisible: isItemVisible,
            playbackSeed: playbackSeed,
            previewMode: previewMode,
            surface: surface,
            palette: palette,
            motion: motion
          )
          DemoStylePreview(
            style: .snap,
            isItemVisible: isItemVisible,
            playbackSeed: playbackSeed,
            previewMode: previewMode,
            surface: surface,
            palette: palette,
            motion: motion
          )
        }
      }
    }
  }

  private struct DemoStylePreview: View {
    let style: DemoPoofStyle
    let isItemVisible: Bool
    let playbackSeed: UInt64
    let previewMode: DemoPreviewMode
    let surface: DemoSurface
    let palette: PoofPalette
    let motion: PoofMotion

    var body: some View {
      GroupBox {
        VStack(spacing: 10) {
          ZStack {
            if let progress = previewMode.progress {
              PoofEffect(
                progress: progress,
                style: style.poofStyle,
                configuration: PoofConfiguration(seed: playbackSeed),
                palette: palette,
                motion: motion
              )
              .frame(width: surface.size.width, height: surface.size.height)
            } else if isItemVisible {
              DemoItem(surface: surface)
                .transition(
                  .poof(
                    style: style.poofStyle,
                    contentRemoval: .progressive,
                    configuration: PoofConfiguration(seed: playbackSeed),
                    palette: palette,
                    motion: motion
                  )
                )
            }
          }
          .frame(maxWidth: .infinity, minHeight: 128)
          .background(
            Color.primary.opacity(0.035),
            in: .rect(cornerRadius: 12)
          )

          Text(style.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } label: {
        Text(style.title)
          .font(.headline)
      }
      .accessibilityElement(children: .contain)
    }
  }

  private struct DemoItem: View {
    let surface: DemoSurface

    var body: some View {
      ZStack {
        switch surface {
        case .roundedSquare:
          RoundedRectangle(cornerRadius: 20)
            .fill(.tint)
          DemoSurfaceSymbol(systemName: "shippingbox.fill", size: 52)
        case .circle:
          Circle()
            .fill(.tint)
          DemoSurfaceSymbol(systemName: "circle.grid.2x2.fill", size: 48)
        case .capsule:
          Capsule()
            .fill(.tint)
          DemoSurfaceSymbol(systemName: "shippingbox.fill", size: 38)
        case .star:
          Image(systemName: "star.fill")
            .font(.system(size: 78, weight: .semibold))
            .foregroundStyle(.tint)
        }
      }
      .frame(width: surface.size.width, height: surface.size.height)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(surface.title))
    }
  }

  private struct DemoSurfaceSymbol: View {
    let systemName: String
    let size: Double

    var body: some View {
      Image(systemName: systemName)
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(.white)
    }
  }

  private struct DemoControls: View {
    @Binding var appearance: DemoAppearance
    @Binding var previewMode: DemoPreviewMode
    @Binding var surface: DemoSurface
    @Binding var palette: DemoPalette
    @Binding var motion: DemoMotion
    @Binding var playbackDuration: Double

    let isItemVisible: Bool
    let toggleItem: () -> Void

    var body: some View {
      VStack(spacing: 12) {
        HStack(spacing: 20) {
          Button(action: toggleItem) {
            if isItemVisible {
              Text(
                "Poof all",
                bundle: #bundle,
                comment: "Button that removes all three demo items."
              )
            } else {
              Text(
                "Restore",
                bundle: #bundle,
                comment: "Button that restores all three demo items."
              )
            }
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .keyboardShortcut(.defaultAction)
          .disabled(!previewMode.isPlayback)
          // The button label rides the same state as the poof, so without
          // this it cross-fades for the whole playback, which at the slowest
          // setting is five seconds of a half-faded word.
          .transaction { transaction in
            transaction.animation = nil
          }

          Picker(selection: $previewMode) {
            ForEach(DemoPreviewMode.allCases, id: \.self) { mode in
              Text(mode.title)
                .tag(mode)
            }
          } label: {
            Text(
              "Preview",
              bundle: #bundle,
              comment:
                "Label for choosing playback or a static poof pose."
            )
          }
          .pickerStyle(.menu)
          .fixedSize()

          Picker(selection: $surface) {
            ForEach(DemoSurface.allCases) { surface in
              Text(surface.title)
                .tag(surface)
            }
          } label: {
            Text(
              "Surface",
              bundle: #bundle,
              comment: "Label for choosing the source shape to poof."
            )
          }
          .pickerStyle(.menu)
          .fixedSize()

          Spacer()

          Picker(selection: $appearance) {
            Text(
              "System",
              bundle: #bundle,
              comment: "Appearance option that follows the system."
            )
            .tag(DemoAppearance.system)
            Text(
              "Light",
              bundle: #bundle,
              comment: "Appearance option that uses light mode."
            )
            .tag(DemoAppearance.light)
            Text(
              "Dark",
              bundle: #bundle,
              comment: "Appearance option that uses dark mode."
            )
            .tag(DemoAppearance.dark)
          } label: {
            Text(
              "Appearance",
              bundle: #bundle,
              comment: "Label for the demo appearance picker."
            )
          }
          .pickerStyle(.segmented)
          .fixedSize()
        }

        HStack(spacing: 20) {
          Picker(selection: $palette) {
            ForEach(DemoPalette.allCases, id: \.self) { palette in
              Text(palette.title)
                .tag(palette)
            }
          } label: {
            Text(
              "Palette",
              bundle: #bundle,
              comment: "Label for choosing poof fill colors."
            )
          }
          .pickerStyle(.menu)
          .fixedSize()

          Picker(selection: $motion) {
            ForEach(DemoMotion.allCases, id: \.self) { motion in
              Text(motion.title)
                .tag(motion)
            }
          } label: {
            Text(
              "Motion",
              bundle: #bundle,
              comment: "Label for choosing stepped or smooth poof motion."
            )
          }
          .pickerStyle(.segmented)
          .fixedSize()

          Spacer()

          Slider(
            value: $playbackDuration,
            in: DemoPlaybackDuration.range,
            step: DemoPlaybackDuration.step
          ) {
            Text(
              "Duration",
              bundle: #bundle,
              comment: "Label for the poof playback duration slider."
            )
          }
          .frame(width: 240)
          .disabled(!previewMode.isPlayback)

          Text(
            Measurement(
              value: playbackDuration,
              unit: UnitDuration.seconds
            ),
            format: .measurement(
              width: .abbreviated,
              usage: .asProvided,
              numberFormatStyle: .number.precision(
                .fractionLength(2)
              )
            )
          )
          .monospacedDigit()
          .fixedSize()
          .foregroundStyle(
            previewMode.isPlayback ? .primary : .tertiary
          )
        }
      }
    }
  }

  private struct AccessibilityStatus: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @Environment(\.accessibilityReduceTransparency)
    private var reducesTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
      VStack(spacing: 8) {
        HStack(spacing: 12) {
          // Bare literals here would resolve against Bundle.main, which for
          // an SPM executable never holds these strings.
          StatusPill(
            title: reducesMotion
              ? LocalizedStringResource(
                "Reduce Motion on",
                bundle: #bundle
              )
              : LocalizedStringResource(
                "Reduce Motion off",
                bundle: #bundle
              ),
            systemImage: reducesMotion ? "figure.walk.motion" : "figure.walk"
          )
          StatusPill(
            title: reducesTransparency
              ? LocalizedStringResource(
                "Reduce Transparency on",
                bundle: #bundle
              )
              : LocalizedStringResource(
                "Reduce Transparency off",
                bundle: #bundle
              ),
            systemImage: "circle.lefthalf.filled"
          )
          StatusPill(
            title: colorSchemeContrast == .increased
              ? LocalizedStringResource(
                "Increased Contrast on",
                bundle: #bundle
              )
              : LocalizedStringResource(
                "Increased Contrast off",
                bundle: #bundle
              ),
            systemImage: "circle.righthalf.filled"
          )
        }
        .foregroundStyle(.secondary)

        if reducesMotion {
          Text(
            "Reduce Motion replaces spatial poofs with a fade.",
            bundle: #bundle,
            comment: "Explanation shown when Reduce Motion is enabled."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
    }
  }

  private struct StatusPill: View {
    let title: LocalizedStringResource
    let systemImage: String

    var body: some View {
      Label {
        Text(title)
      } icon: {
        Image(systemName: systemImage)
      }
      .font(.caption)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.quaternary, in: .capsule)
    }
  }

  enum DemoPoofStyle: CaseIterable, Hashable {
    case classic
    case bloom
    case snap

    var poofStyle: PoofStyle {
      switch self {
      case .classic:
        .classic
      case .bloom:
        .bloom
      case .snap:
        .snap
      }
    }

    var title: LocalizedStringResource {
      switch self {
      case .classic:
        LocalizedStringResource("Classic", bundle: #bundle)
      case .bloom:
        LocalizedStringResource("Bloom", bundle: #bundle)
      case .snap:
        LocalizedStringResource("Snap", bundle: #bundle)
      }
    }

    var summary: LocalizedStringResource {
      switch self {
      case .classic:
        LocalizedStringResource(
          "The crisp five-pose original.",
          bundle: #bundle
        )
      case .bloom:
        LocalizedStringResource(
          "A soft, full cloud with a cartoony pop.",
          bundle: #bundle
        )
      case .snap:
        LocalizedStringResource(
          "A tighter poof with a punchier break.",
          bundle: #bundle
        )
      }
    }
  }

  enum DemoPalette: CaseIterable, Hashable {
    case automatic
    case pastel

    var poofPalette: PoofPalette {
      switch self {
      case .automatic:
        .automatic
      case .pastel:
        .pastel
      }
    }

    var title: LocalizedStringResource {
      switch self {
      case .automatic:
        LocalizedStringResource("Grayscale", bundle: #bundle)
      case .pastel:
        LocalizedStringResource("Pastel", bundle: #bundle)
      }
    }
  }

  enum DemoMotion: CaseIterable, Hashable {
    case stepped
    case smooth

    var poofMotion: PoofMotion {
      switch self {
      case .stepped:
        .stepped
      case .smooth:
        .smooth
      }
    }

    var title: LocalizedStringResource {
      switch self {
      case .stepped:
        LocalizedStringResource("Stepped", bundle: #bundle)
      case .smooth:
        LocalizedStringResource("Smooth", bundle: #bundle)
      }
    }
  }

  enum DemoPlaybackDuration {
    static let defaultValue = 1.0 / 3.0
    static let range = defaultValue...5.0
    static let step = 1.0 / 6.0
  }

  enum DemoSurface: CaseIterable, Hashable, Identifiable {
    case roundedSquare
    case circle
    case capsule
    case star

    var id: Self {
      self
    }

    var size: CGSize {
      switch self {
      case .roundedSquare, .circle, .star:
        CGSize(width: 88, height: 88)
      case .capsule:
        CGSize(width: 132, height: 48)
      }
    }

    var title: LocalizedStringResource {
      switch self {
      case .roundedSquare:
        LocalizedStringResource("Rounded square", bundle: #bundle)
      case .circle:
        LocalizedStringResource("Circle", bundle: #bundle)
      case .capsule:
        LocalizedStringResource("Capsule", bundle: #bundle)
      case .star:
        LocalizedStringResource("Star", bundle: #bundle)
      }
    }
  }

  enum DemoPreviewMode: CaseIterable, Hashable {
    case animation
    case cloud
    case clusters
    case puffs
    case wisps
    case ringlets

    var isPlayback: Bool {
      self == .animation
    }

    func playbackAnimation(duration: Double) -> Animation? {
      switch self {
      case .animation:
        .linear(
          duration: min(
            max(duration, DemoPlaybackDuration.range.lowerBound),
            DemoPlaybackDuration.range.upperBound)
        )
      case .cloud, .clusters, .puffs, .wisps, .ringlets:
        nil
      }
    }

    var progress: Double? {
      switch self {
      case .animation:
        nil
      case .cloud:
        0.1
      case .clusters:
        0.3
      case .puffs:
        0.5
      case .wisps:
        0.7
      case .ringlets:
        0.9
      }
    }

    var title: LocalizedStringResource {
      switch self {
      case .animation:
        LocalizedStringResource("Animation", bundle: #bundle)
      case .cloud:
        LocalizedStringResource("Cloud", bundle: #bundle)
      case .clusters:
        LocalizedStringResource("Clusters", bundle: #bundle)
      case .puffs:
        LocalizedStringResource("Puffs", bundle: #bundle)
      case .wisps:
        LocalizedStringResource("Wisps", bundle: #bundle)
      case .ringlets:
        LocalizedStringResource("Ringlets", bundle: #bundle)
      }
    }
  }

  private enum DemoAppearance: Hashable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
      switch self {
      case .system:
        nil
      case .light:
        .light
      case .dark:
        .dark
      }
    }
  }
#endif
