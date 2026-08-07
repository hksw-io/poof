#if os(macOS)
  import Poof
  import SwiftUI

  struct PoofDemoView: View {
    @State private var model = DemoModel()
    @State private var isInspectorPresented = true

    var body: some View {
      DemoGallery(model: model)
        .safeAreaPadding(20)
        .frame(minWidth: 560, minHeight: 380)
        .navigationTitle(Text("Poof"))
        .navigationSubtitle(Text("Click anywhere in a preview to poof"))
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            DemoPoofButton(model: model)
          }
          ToolbarItem {
            Toggle(isOn: $isInspectorPresented) {
              Label {
                Text("Options")
              } icon: {
                Image(systemName: "sidebar.trailing")
              }
            }
          }
        }
        .inspector(isPresented: $isInspectorPresented) {
          DemoOptions(model: model)
            .inspectorColumnWidth(min: 240, ideal: 280, max: 360)
        }
        .preferredColorScheme(model.appearance.colorScheme)
        .focusedSceneValue(\.demoModel, model)
        // Restarting on a settings change keeps the three styles comparable:
        // a half-poofed item under new settings is not a comparison. These
        // live here rather than beside the controls, which the inspector
        // stops instantiating as soon as it is collapsed.
        .onChange(of: model.previewMode) { model.reset() }
        .onChange(of: model.surface) { model.reset() }
        .onChange(of: model.palette) { model.reset() }
    }
  }

  /// Everything the demo lets you change, and the playback it drives.
  ///
  /// The controls, the toolbar, and the menu bar all act on one value, so a
  /// keyboard shortcut and a button press cannot disagree about what a poof is.
  @Observable
  @MainActor
  final class DemoModel {
    var appearance = DemoAppearance.system
    var previewMode = DemoPreviewMode.animation
    var surface = DemoSurface.roundedSquare
    var palette = DemoPalette.automatic

    private(set) var isItemVisible = true
    private(set) var playbackSeed: UInt64 = 0x504F_4F46

    var canPoof: Bool {
      previewMode.isPlayback && isItemVisible
    }

    var canRestore: Bool {
      previewMode.isPlayback && !isItemVisible
    }

    func toggleItem() {
      if isItemVisible {
        poof()
      } else {
        restore()
      }
    }

    func poof() {
      guard canPoof else {
        return
      }

      withAnimation(.poof) {
        isItemVisible = false
      }
    }

    func restore() {
      guard !isItemVisible else {
        return
      }

      // A fresh seed keeps every style directly comparable while still varying
      // between runs.
      playbackSeed &+= 1
      reset()
    }

    /// Puts the source back without advancing the seed, for when a setting
    /// changes mid-playback and the comparison has to start over.
    func reset() {
      isItemVisible = true
    }
  }

  private struct DemoPoofButton: View {
    let model: DemoModel

    var body: some View {
      Button {
        model.toggleItem()
      } label: {
        if model.isItemVisible {
          Label {
            Text("Poof")
          } icon: {
            Image(systemName: "wind")
          }
        } else {
          Label {
            Text("Restore")
          } icon: {
            Image(systemName: "arrow.counterclockwise")
          }
        }
      }
      // The verb is the point of the demo, so it keeps its word rather than
      // collapsing to an icon the way a document app's toolbar would.
      .labelStyle(.titleAndIcon)
      .keyboardShortcut(.defaultAction)
      .disabled(!model.previewMode.isPlayback)
      // The label follows the same state as the poof, but should swap at once.
      .transaction { transaction in
        transaction.animation = nil
      }
    }
  }

  private struct DemoGallery: View {
    let model: DemoModel

    var body: some View {
      ScrollView {
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
          GridRow {
            ForEach(DemoPoofStyle.allCases, id: \.self) { style in
              DemoStylePreview(style: style, model: model)
            }
          }
        }
        .frame(maxWidth: .infinity)
      }
      .scrollBounceBehavior(.basedOnSize)
      // Content shorter than the window sits in the middle of it rather than
      // stranded under the title bar; a window too short to hold the cards
      // still scrolls.
      .defaultScrollAnchor(.center)
    }
  }

  private struct DemoStylePreview: View {
    @State private var poofLocation = CGPoint.zero
    @State private var poofTrigger: UInt64 = 0

    let style: DemoPoofStyle
    let model: DemoModel

    var body: some View {
      GroupBox {
        VStack(alignment: .leading, spacing: 10) {
          ZStack {
            if let progress = model.previewMode.progress {
              PoofEffect(
                progress: progress,
                style: style.poofStyle,
                configuration: PoofConfiguration(seed: model.playbackSeed),
                palette: model.palette.poofPalette
              )
              .frame(
                width: model.surface.size.width,
                height: model.surface.size.height
              )
            } else if model.isItemVisible {
              DemoItem(surface: model.surface)
                .transition(
                  .poof(
                    style: style.poofStyle,
                    contentRemoval: .progressive,
                    configuration: PoofConfiguration(seed: model.playbackSeed),
                    palette: model.palette.poofPalette
                  )
                )
            }
          }
          .frame(maxWidth: .infinity, minHeight: 132)
          .background(.fill.quaternary, in: .rect(cornerRadius: 10))
          .contentShape(.rect)
          .poof(
            at: poofLocation,
            style: style.poofStyle,
            configuration: PoofConfiguration(seed: model.playbackSeed),
            palette: model.palette.poofPalette,
            trigger: poofTrigger
          )
          .onTapGesture(coordinateSpace: .local) { location in
            poofLocation = location
            poofTrigger &+= 1
          }

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

  private struct DemoOptions: View {
    @Bindable var model: DemoModel

    var body: some View {
      Form {
        Section {
          Picker(selection: $model.previewMode) {
            ForEach(DemoPreviewMode.allCases, id: \.self) { mode in
              Text(mode.title)
                .tag(mode)
            }
          } label: {
            Text("Preview")
          }

          Picker(selection: $model.surface) {
            ForEach(DemoSurface.allCases, id: \.self) { surface in
              Text(surface.title)
                .tag(surface)
            }
          } label: {
            Text("Surface")
          }
        }

        Section {
          Picker(selection: $model.palette) {
            ForEach(DemoPalette.allCases, id: \.self) { palette in
              Text(palette.title)
                .tag(palette)
            }
          } label: {
            Text("Palette")
          }

          Picker(selection: $model.appearance) {
            ForEach(DemoAppearance.allCases, id: \.self) { appearance in
              Text(appearance.title)
                .tag(appearance)
            }
          } label: {
            Text("Appearance")
          }
          .pickerStyle(.segmented)
        }

        Section {
          AccessibilityStatus()
        } header: {
          Text("Accessibility")
        }
      }
      .formStyle(.grouped)
    }
  }

  private struct AccessibilityStatus: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @Environment(\.accessibilityReduceTransparency)
    private var reducesTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
      AccessibilityStatusRow(
        title: "Reduce Motion",
        isOn: reducesMotion
      )
      AccessibilityStatusRow(
        title: "Reduce Transparency",
        isOn: reducesTransparency
      )
      AccessibilityStatusRow(
        title: "Increased Contrast",
        isOn: colorSchemeContrast == .increased
      )

      if reducesMotion {
        Text("Reduce Motion replaces spatial poofs with a fade.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private struct AccessibilityStatusRow: View {
    let title: String
    let isOn: Bool

    var body: some View {
      LabeledContent {
        Label {
          if isOn {
            Text("On")
          } else {
            Text("Off")
          }
        } icon: {
          Image(
            systemName: isOn
              ? "checkmark.circle.fill"
              : "circle"
          )
        }
        .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
      } label: {
        Text(title)
      }
      .accessibilityElement(children: .combine)
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

    var title: String {
      switch self {
      case .classic:
        "Classic"
      case .bloom:
        "Bloom"
      case .snap:
        "Snap"
      }
    }

    var summary: String {
      switch self {
      case .classic:
        "The crisp five-pose original."
      case .bloom:
        "A soft, full cloud with a cartoony pop."
      case .snap:
        "A tighter poof with a punchier break."
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

    var title: String {
      switch self {
      case .automatic:
        "Grayscale"
      case .pastel:
        "Pastel"
      }
    }
  }

  enum DemoSurface: CaseIterable, Hashable {
    case roundedSquare
    case circle
    case capsule
    case star

    var size: CGSize {
      switch self {
      case .roundedSquare, .circle, .star:
        CGSize(width: 88, height: 88)
      case .capsule:
        CGSize(width: 132, height: 48)
      }
    }

    var title: String {
      switch self {
      case .roundedSquare:
        "Rounded square"
      case .circle:
        "Circle"
      case .capsule:
        "Capsule"
      case .star:
        "Star"
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

    var title: String {
      switch self {
      case .animation:
        "Animation"
      case .cloud:
        "Cloud"
      case .clusters:
        "Clusters"
      case .puffs:
        "Puffs"
      case .wisps:
        "Wisps"
      case .ringlets:
        "Ringlets"
      }
    }
  }

  enum DemoAppearance: CaseIterable, Hashable {
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

    var title: String {
      switch self {
      case .system:
        "System"
      case .light:
        "Light"
      case .dark:
        "Dark"
      }
    }
  }

  /// Carries the focused window's demo to the menu bar, so the Poof commands
  /// act on the window in front rather than on a global singleton.
  extension FocusedValues {
    @Entry var demoModel: DemoModel?
  }
#endif
