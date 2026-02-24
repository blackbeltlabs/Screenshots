import Cocoa
import SwiftUI
import Screenshots

@main
class AppDelegate: NSObject, NSApplicationDelegate {

  private var window: NSWindow?

  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    ScreenshotCLI.requestNeededPermissions()

    let contentView = ContentView()

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 640, height: 507),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Screenshots Example"
    window.contentView = NSHostingView(rootView: contentView)
    window.center()

    self.window = window

    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}
