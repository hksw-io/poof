#if os(macOS)
  import Foundation
  import Poof
  import SwiftUI

  struct PoofDemoView: View {
    @State private var model = DemoModel()
    @State private var isInspectorPresented = true

    var body: some View {
      DemoGallery(model: model)
        .safeAreaPadding(20)
        .frame(minWidth: 560, minHeight: 380)
        .navigationTitle(
          Text(
            "Poof",
            bundle: #bundle,
            comment: "The demo window's title."
          )
        )
        .navigationSubtitle(
          Text(
            "Three ways to poof",
            bundle: #bundle,
            comment: "The demo window's subtitle."
          )
        )
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            DemoPoofButton(model: model)
          }
          ToolbarItem {
            Toggle(isOn: $isInspectorPresented) {
              Label {
                Text(
                  "Options",
                  bundle: #bundle,
                  comment: "Button that shows or hides the options panel."
                )
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
    var playbackDuration = DemoPlaybackDuration.defaultValue

    private(set) var isItemVisible = true
    private(set) var playbackSeed: UInt64 = 0x504F_4F46
    private(set) var playbackStart: Date? = nil
    // Ticking is separate from the value the clock shows. The readout holds its
    // final reading after a poof, but nothing should still be waking the
    // display to redraw an unchanging number.
    private(set) var isClockRunning = false

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
      guard
        canPoof,
        let animation = previewMode.playbackAnimation(
          duration: playbackDuration
        )
      else {
        return
      }

      playbackStart = Date()
      isClockRunning = true
      // The completion is what stops the clock: it fires exactly when the poof
      // finishes, so the readout freezes on its last reading instead of the
      // schedule running on for the life of the app.
      withAnimation(animation, completionCriteria: .removed) {
        isItemVisible = false
      } completion: { [weak self] in
        self?.isClockRunning = false
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
      playbackStart = nil
      isClockRunning = false
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
            Text(
              "Poof",
              bundle: #bundle,
              comment: "Button that removes the demo items."
            )
          } icon: {
            Image(systemName: "wind")
          }
        } else {
          Label {
            Text(
              "Restore",
              bundle: #bundle,
              comment: "Button that restores the demo items."
            )
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
      // The label rides the same state as the poof, so without this it
      // cross-fades for the whole playback, which at the slowest setting is
      // five seconds of a half-faded word.
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
            ForEach(DemoPoofStyle.allCases) { style in
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
            ForEach(DemoPreviewMode.allCases) { mode in
              Text(mode.title)
                .tag(mode)
            }
          } label: {
            Text(
              "Preview",
              bundle: #bundle,
              comment: "Label for choosing playback or a static poof pose."
            )
          }

          Picker(selection: $model.surface) {
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
        }

        Section {
          Picker(selection: $model.palette) {
            ForEach(DemoPalette.allCases) { palette in
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

          Picker(selection: $model.appearance) {
            ForEach(DemoAppearance.allCases) { appearance in
              Text(appearance.title)
                .tag(appearance)
            }
          } label: {
            Text(
              "Appearance",
              bundle: #bundle,
              comment: "Label for the demo appearance picker."
            )
          }
          .pickerStyle(.segmented)
        }

        Section {
          LabeledContent {
            Slider(
              value: $model.playbackDuration,
              in: DemoPlaybackDuration.range,
              step: DemoPlaybackDuration.step
            )
          } label: {
            Text(
              "Duration",
              bundle: #bundle,
              comment: "Label for the poof playback duration slider."
            )
            DemoDurationValue(duration: model.playbackDuration)
          }

          DemoPlaybackClock(
            start: model.playbackStart,
            duration: model.playbackDuration,
            isRunning: model.isClockRunning
          )
        }
        .disabled(!model.previewMode.isPlayback)

        Section {
          AccessibilityStatus()
        } header: {
          Text(
            "Accessibility",
            bundle: #bundle,
            comment: "Heading above the accessibility status rows."
          )
        }
      }
      .formStyle(.grouped)
    }
  }

  private struct DemoDurationValue: View {
    let duration: Double

    var body: some View {
      Text(
        Measurement(value: duration, unit: UnitDuration.seconds),
        format: .measurement(
          width: .abbreviated,
          usage: .asProvided,
          numberFormatStyle: .number.precision(.fractionLength(2))
        )
      )
      .monospacedDigit()
      .foregroundStyle(.secondary)
    }
  }

  /// A running readout of the playback, for pointing at a moment.
  ///
  /// Elapsed seconds and normalized progress tick while the poof plays and hold
  /// at the end, so "at 2.2 s, 44%" stays on screen to be quoted against a
  /// recording or a report.
  private struct DemoPlaybackClock: View {
    /// Wide enough for the longest reading the clock can show, so the value
    /// never resizes anything around it. A readout that grows by a digit
    /// invalidates the whole form, and the duration slider makes that
    /// re-layout expensive.
    private static let readoutWidth = 108.0

    let start: Date?
    let duration: Double
    let isRunning: Bool

    var body: some View {
      // Paused on the playback rather than on the value: the reading stays on
      // screen after a poof, but an idle app must not keep waking the display
      // to redraw a number that cannot change. The schedule ticks at the
      // display's rate, so a minimum interval would not slow it down.
      TimelineView(.animation(paused: !isRunning)) { context in
        let elapsed = DemoPlaybackClockModel.elapsed(
          since: start,
          at: context.date,
          duration: duration
        )
        let progress = DemoPlaybackClockModel.progress(
          elapsed: elapsed,
          duration: duration
        )

        LabeledContent {
          HStack(spacing: 6) {
            Text(
              Measurement(value: elapsed, unit: UnitDuration.seconds),
              format: .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(2))
              )
            )
            Text(progress, format: .percent.precision(.fractionLength(0)))
              .foregroundStyle(.secondary)
          }
          .monospacedDigit()
          .frame(width: Self.readoutWidth, alignment: .trailing)
        } label: {
          Text(
            "Elapsed",
            bundle: #bundle,
            comment: "Label before the playback timer readout."
          )
        }
      }
    }
  }

  /// The clock's arithmetic, kept apart from the view so it can be tested.
  enum DemoPlaybackClockModel {
    /// Elapsed playback time, clamped to the playback window.
    ///
    /// Clamping to the duration is what freezes the readout at the end
    /// instead of counting into the silence after the poof.
    static func elapsed(
      since start: Date?,
      at date: Date,
      duration: Double
    ) -> Double {
      guard let start else {
        return 0
      }

      return min(
        max(date.timeIntervalSince(start), 0),
        max(duration, 0)
      )
    }

    static func progress(
      elapsed: Double,
      duration: Double
    ) -> Double {
      guard duration > 0 else {
        return 0
      }

      return min(max(elapsed / duration, 0), 1)
    }
  }

  private struct AccessibilityStatus: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @Environment(\.accessibilityReduceTransparency)
    private var reducesTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
      // Bare literals here would resolve against Bundle.main, which for an SPM
      // executable never holds these strings.
      AccessibilityStatusRow(
        title: LocalizedStringResource("Reduce Motion", bundle: #bundle),
        isOn: reducesMotion
      )
      AccessibilityStatusRow(
        title: LocalizedStringResource("Reduce Transparency", bundle: #bundle),
        isOn: reducesTransparency
      )
      AccessibilityStatusRow(
        title: LocalizedStringResource("Increased Contrast", bundle: #bundle),
        isOn: colorSchemeContrast == .increased
      )

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

  private struct AccessibilityStatusRow: View {
    let title: LocalizedStringResource
    let isOn: Bool

    var body: some View {
      LabeledContent {
        Label {
          if isOn {
            Text(
              "On",
              bundle: #bundle,
              comment: "Status shown when an accessibility setting is enabled."
            )
          } else {
            Text(
              "Off",
              bundle: #bundle,
              comment: "Status shown when an accessibility setting is disabled."
            )
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

  enum DemoPoofStyle: CaseIterable, Hashable, Identifiable {
    case classic
    case bloom
    case snap

    var id: Self {
      self
    }

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

  enum DemoPalette: CaseIterable, Hashable, Identifiable {
    case automatic
    case pastel

    var id: Self {
      self
    }

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

  enum DemoPreviewMode: CaseIterable, Hashable, Identifiable {
    case animation
    case cloud
    case clusters
    case puffs
    case wisps
    case ringlets

    var id: Self {
      self
    }

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

  enum DemoAppearance: CaseIterable, Hashable, Identifiable {
    case system
    case light
    case dark

    var id: Self {
      self
    }

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

    var title: LocalizedStringResource {
      switch self {
      case .system:
        LocalizedStringResource("System", bundle: #bundle)
      case .light:
        LocalizedStringResource("Light", bundle: #bundle)
      case .dark:
        LocalizedStringResource("Dark", bundle: #bundle)
      }
    }
  }

  /// Carries the focused window's demo to the menu bar, so the Poof commands
  /// act on the window in front rather than on a global singleton.
  extension FocusedValues {
    @Entry var demoModel: DemoModel?
  }
#endif
