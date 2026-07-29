#if os(macOS)
  import SwiftUI

  @main
  struct PoofDemoApp: App {
    var body: some Scene {
      WindowGroup {
        PoofDemoView()
      }
      .defaultSize(width: 560, height: 480)
      .windowResizability(.contentSize)
    }
  }
#else
  @main
  enum PoofDemoApp {
    static func main() {}
  }
#endif
