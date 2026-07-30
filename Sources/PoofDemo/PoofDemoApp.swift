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
      .defaultSize(width: 720, height: 660)
      .windowResizability(.contentSize)
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
