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
      .defaultSize(width: 560, height: 480)
      .windowResizability(.contentSize)
    }
  }

  @MainActor
  private final class PoofDemoApplicationDelegate:
    NSObject,
    NSApplicationDelegate
  {
    func applicationDidFinishLaunching(_: Notification) {
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
