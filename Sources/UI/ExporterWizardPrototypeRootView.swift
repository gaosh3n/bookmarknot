import SwiftUI

struct ExporterWizardPrototypeRootView: View {
  @State private var variant: PrototypeVariant = .guidedRail
  @State private var browser: PrototypeBrowser = .chrome
  @State private var state: PrototypeRunState = .ready
  @State private var showsRuntimeError = false

  private let exportPath =
    "~/Library/Application Support/Bookmarknot/exports/3E4A1B89C2F7/bookmarks.html"

  var body: some View {
    ZStack(alignment: .bottom) {
      Group {
        switch variant {
        case .guidedRail:
          GuidedRailVariant(
            browser: $browser,
            state: state,
            exportPath: exportPath,
            perform: perform
          )
        case .journey:
          JourneyVariant(
            browser: $browser,
            state: state,
            exportPath: exportPath,
            perform: perform
          )
        case .focusedSheet:
          FocusedSheetVariant(
            browser: $browser,
            state: state,
            exportPath: exportPath,
            perform: perform
          )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.bottom, 132)

      VStack(spacing: 8) {
        PrototypeScenarioBar(browser: browser, state: state, perform: perform)
        PrototypeSwitcher(variant: $variant)
      }
      .padding(.bottom, 14)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .alert("Browser import stopped", isPresented: $showsRuntimeError) {
      Button("OK") {
        perform(.acknowledgeFailure)
      }
    } message: {
      Text("A runtime error occurred. See Runtime Log for details.")
    }
  }

  private func perform(_ action: PrototypeAction) {
    switch action {
    case .reset:
      browser = .chrome
      state = .ready
      showsRuntimeError = false
    case .startImport:
      state = .checkingPermissions
    case .requirePermission:
      state = .permissionRequired
    case .checkAgain:
      state = .checkingPermissions
    case .beginAutomation, .authorizationSatisfied:
      state = .automationRunning
    case .requireAuthorization:
      state = .authorizationRequired
    case .completeImport:
      state = .importCompleted
    case .failRuntime:
      state = .runtimeFailed
      showsRuntimeError = true
    case .acknowledgeFailure, .close:
      state = .closed
    }
  }
}
