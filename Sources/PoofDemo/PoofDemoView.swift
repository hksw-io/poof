#if os(macOS)
  import Poof
  import SwiftUI

  struct PoofDemoView: View {
    @State private var appearance = DemoAppearance.system
    @State private var isItemVisible = true

    var body: some View {
      VStack(spacing: 28) {
        DemoStage(isItemVisible: isItemVisible)
        DemoControls(
          appearance: $appearance,
          isItemVisible: $isItemVisible
        )
        AccessibilityStatus()
      }
      .padding(36)
      .frame(minWidth: 520, minHeight: 440)
      .background {
        Rectangle()
          .fill(.tint)
          .opacity(0.06)
          .ignoresSafeArea()
      }
      .preferredColorScheme(appearance.colorScheme)
    }
  }

  private struct DemoStage: View {
    let isItemVisible: Bool

    var body: some View {
      ZStack {
        if isItemVisible {
          DemoItem()
            .transition(.poof())
        }
      }
      .frame(width: 240, height: 240)
      .background(.regularMaterial, in: .rect(cornerRadius: 32))
      .overlay {
        RoundedRectangle(cornerRadius: 32)
          .stroke(.quaternary, lineWidth: 1)
      }
    }
  }

  private struct DemoItem: View {
    var body: some View {
      Image(systemName: "shippingbox.fill")
        .font(.system(size: 64, weight: .semibold))
        .foregroundStyle(.tint)
        .frame(width: 116, height: 116)
        .background(.tint.opacity(0.12), in: .rect(cornerRadius: 26))
        .accessibilityLabel(
          Text(
            "Package",
            bundle: #bundle,
            comment: "Accessibility label for the demo item."
          )
        )
    }
  }

  private struct DemoControls: View {
    @Binding var appearance: DemoAppearance
    @Binding var isItemVisible: Bool

    var body: some View {
      VStack(spacing: 16) {
        Button(action: toggleItem) {
          if isItemVisible {
            Text(
              "Poof",
              bundle: #bundle,
              comment: "Button that removes the demo item with a poof."
            )
          } else {
            Text(
              "Restore",
              bundle: #bundle,
              comment: "Button that restores the removed demo item."
            )
          }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

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
        .labelsHidden()
        .frame(maxWidth: 260)
      }
    }

    private func toggleItem() {
      if isItemVisible {
        withAnimation(.poof) {
          isItemVisible = false
        }
      } else {
        isItemVisible = true
      }
    }
  }

  private struct AccessibilityStatus: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @Environment(\.accessibilityReduceTransparency)
    private var reducesTransparency

    var body: some View {
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
      }
      .foregroundStyle(.secondary)
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
