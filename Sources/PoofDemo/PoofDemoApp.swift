#if os(macOS)
  import AppKit
  import SwiftUI

  @main
  struct PoofDemoApp: App {
    @NSApplicationDelegateAdaptor(PoofDemoApplicationDelegate.self)
    private var applicationDelegate

    var body: some Scene {
      WindowGroup {
        PoofDemoView()
      }
      .defaultSize(width: 880, height: 560)
      .commands {
        DemoCommands()
      }
    }
  }

  /// The Poof menu.
  ///
  /// The verbs the toolbar offers belong in the menu bar too, with the
  /// shortcuts a Mac user expects to find there.
  private struct DemoCommands: Commands {
    @FocusedValue(\.demoModel) private var model

    var body: some Commands {
      CommandMenu(Text("Poof")) {
        Button {
          model?.poof()
        } label: {
          Text("Poof")
        }
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(model?.canPoof != true)

        Button {
          model?.restore()
        } label: {
          Text("Restore")
        }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(model?.canRestore != true)
      }
    }
  }

  @MainActor
  private final class PoofDemoApplicationDelegate:
    NSObject,
    NSApplicationDelegate
  {
    func applicationDidFinishLaunching(_: Notification) {
      // SwiftPM starts the demo as a command-line executable, so opt into
      // normal app activation before bringing its first window forward.
      NSApplication.shared.setActivationPolicy(.regular)
      NSApplication.shared.activate()
    }
  }
#else
  @main
  enum PoofDemoApp {
    static func main() {}
  }
#endif
