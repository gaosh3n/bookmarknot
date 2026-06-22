import AppKit
import SwiftUI

private enum LaunchSurface {
  case mainApp
  case exporterWizardPrototype

  static var current: LaunchSurface {
    ProcessInfo.processInfo.arguments.contains("--prototype-exporter-wizard")
      ? .exporterWizardPrototype
      : .mainApp
  }
}

private final class WindowToolbarSuppressorView: NSView {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    suppressToolbar()
    perform(#selector(suppressToolbar), with: nil, afterDelay: 0)
  }

  @objc private func suppressToolbar() {
    window?.toolbar?.isVisible = false
  }
}

private struct WindowToolbarSuppressor: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    WindowToolbarSuppressorView()
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    nsView.window?.toolbar?.isVisible = false
  }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate()
  }
}

@main
struct BookmarknotApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Window("Bookmarknot", id: "main") {
      Group {
        switch LaunchSurface.current {
        case .mainApp:
          RootView()
        case .exporterWizardPrototype:
          ExporterWizardPrototypeRootView()
        }
      }
      .background(WindowToolbarSuppressor())
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 960, height: 720)
    .commands {
      CommandGroup(replacing: .newItem) {}
    }
  }
}
