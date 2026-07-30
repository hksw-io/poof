#if os(macOS)
  import Poof
  import SwiftUI

  struct PoofDemoView: View {
    @State private var appearance = DemoAppearance.system
    @State private var isItemVisible = true
    @State private var playbackSeed: UInt64 = 0x504F_4F46
    @State private var previewMode = DemoPreviewMode.animation
    @State private var surface = DemoSurface.roundedSquare

    var body: some View {
      VStack(spacing: 20) {
        DemoHeader()
        DemoComparisonGrid(
          isItemVisible: isItemVisible,
          playbackSeed: playbackSeed,
          previewMode: previewMode,
          surface: surface
        )
        DemoControls(
          appearance: $appearance,
          previewMode: $previewMode,
          surface: $surface,
          isItemVisible: isItemVisible,
          toggleItem: toggleItem
        )
        AccessibilityStatus()
      }
      .padding(24)
      .frame(minWidth: 680, minHeight: 620)
      .preferredColorScheme(appearance.colorScheme)
      .onChange(of: previewMode) {
        isItemVisible = true
      }
      .onChange(of: surface) {
        isItemVisible = true
      }
    }

    private func toggleItem() {
      if isItemVisible {
        guard let animation = previewMode.playbackAnimation else {
          return
        }

        withAnimation(animation) {
          isItemVisible = false
        }
      } else {
        // A shared seed keeps the four styles directly comparable.
        playbackSeed &+= 1
        isItemVisible = true
      }
    }
  }

  private struct DemoHeader: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        Text(
          "Four ways to poof",
          bundle: #bundle,
          comment: "Heading above the poof style comparison."
        )
        .font(.title2.weight(.semibold))

        Text(
          "The original, plus three playful takes designed for today.",
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

    var body: some View {
      Grid(horizontalSpacing: 16, verticalSpacing: 16) {
        GridRow {
          DemoStylePreview(
            style: .classic,
            isItemVisible: isItemVisible,
            playbackSeed: playbackSeed,
            previewMode: previewMode,
            surface: surface
          )
          DemoStylePreview(
            style: .bloom,
            isItemVisible: isItemVisible,
            playbackSeed: playbackSeed,
            previewMode: previewMode,
            surface: surface
          )
        }

        GridRow {
          DemoStylePreview(
            style: .snap,
            isItemVisible: isItemVisible,
            playbackSeed: playbackSeed,
            previewMode: previewMode,
            surface: surface
          )
          DemoStylePreview(
            style: .drift,
            isItemVisible: isItemVisible,
            playbackSeed: playbackSeed,
            previewMode: previewMode,
            surface: surface
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

    var body: some View {
      GroupBox {
        VStack(spacing: 10) {
          ZStack {
            if let progress = previewMode.progress {
              PoofEffect(
                progress: progress,
                style: style.poofStyle,
                configuration: PoofConfiguration(seed: playbackSeed)
              )
              .frame(width: surface.size.width, height: surface.size.height)
            } else if isItemVisible {
              DemoItem(surface: surface)
                .transition(
                  .poof(
                    style: style.poofStyle,
                    contentRemoval: .progressive,
                    configuration: PoofConfiguration(seed: playbackSeed)
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

    let isItemVisible: Bool
    let toggleItem: () -> Void

    var body: some View {
      HStack(spacing: 20) {
        Button(action: toggleItem) {
          if isItemVisible {
            Text(
              "Poof all",
              bundle: #bundle,
              comment: "Button that removes all four demo items."
            )
          } else {
            Text(
              "Restore",
              bundle: #bundle,
              comment: "Button that restores all four demo items."
            )
          }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .disabled(!previewMode.isPlayback)

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
              "Label for choosing normal playback, slow playback, or a static poof pose."
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
        .disabled(!previewMode.isPlayback)

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
          StatusPill(
            title: reducesMotion
              ? "Reduce Motion on"
              : "Reduce Motion off",
            systemImage: reducesMotion ? "figure.walk.motion" : "figure.walk"
          )
          StatusPill(
            title: reducesTransparency
              ? "Reduce Transparency on"
              : "Reduce Transparency off",
            systemImage: "circle.lefthalf.filled"
          )
          StatusPill(
            title: colorSchemeContrast == .increased
              ? "Increased Contrast on"
              : "Increased Contrast off",
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

  private enum DemoPoofStyle: Hashable {
    case classic
    case bloom
    case snap
    case drift

    var poofStyle: PoofStyle {
      switch self {
      case .classic:
        .classic
      case .bloom:
        .bloom
      case .snap:
        .snap
      case .drift:
        .drift
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
      case .drift:
        LocalizedStringResource("Drift", bundle: #bundle)
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
          "A soft pastel cloud with a cartoony pop.",
          bundle: #bundle
        )
      case .snap:
        LocalizedStringResource(
          "A tighter poof with a punchier break.",
          bundle: #bundle
        )
      case .drift:
        LocalizedStringResource(
          "Light wisps that lift as they fade.",
          bundle: #bundle
        )
      }
    }
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
    case slowMotion
    case cloud
    case clusters
    case puffs
    case wisps
    case ringlets

    // The five-second demo holds each of the five production poses for one
    // second without changing the library's real playback timing.
    static let slowPoseDuration = 1.0
    static let slowPlaybackDuration = slowPoseDuration * 5

    var isPlayback: Bool {
      playbackAnimation != nil
    }

    var playbackAnimation: Animation? {
      switch self {
      case .animation:
        .poof
      case .slowMotion:
        .linear(duration: Self.slowPlaybackDuration)
      case .cloud, .clusters, .puffs, .wisps, .ringlets:
        nil
      }
    }

    var progress: Double? {
      switch self {
      case .animation, .slowMotion:
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
      case .slowMotion:
        LocalizedStringResource("Slow motion", bundle: #bundle)
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
