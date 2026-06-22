import SwiftUI

// PROTOTYPE - three automated-import wizard variants in one runnable surface.
// Run with: swift run bookmarknot --prototype-exporter-wizard

enum PrototypeVariant: String, CaseIterable, Identifiable {
  case guidedRail = "Guided Rail"
  case journey = "Journey"
  case focusedSheet = "Focused Sheet"

  var id: String { rawValue }

  var key: String {
    switch self {
    case .guidedRail: "A"
    case .journey: "B"
    case .focusedSheet: "C"
    }
  }
}

enum PrototypeBrowser: String, CaseIterable, Identifiable {
  case chrome = "Chrome"
  case safari = "Safari"

  var id: String { rawValue }

  var importMode: String {
    switch self {
    case .chrome: "Full automation"
    case .safari: "Assisted import"
    }
  }

  var runExpectation: String {
    switch self {
    case .chrome:
      "Bookmarknot completes the browser-owned import after required macOS permissions are available."
    case .safari:
      "Safari may ask for Touch ID or your password. Bookmarknot waits and continues automatically."
    }
  }
}

enum PrototypeRunState: String, CaseIterable, Identifiable {
  case ready = "Ready"
  case checkingPermissions = "Checking Permissions"
  case permissionRequired = "Permission Required"
  case automationRunning = "Importing"
  case authorizationRequired = "Authorization Required"
  case importCompleted = "Import Completed"
  case runtimeFailed = "Runtime Error"
  case closed = "Wizard Closed"

  var id: String { rawValue }

  var tone: Color {
    switch self {
    case .ready: .secondary
    case .checkingPermissions, .automationRunning: .blue
    case .permissionRequired, .authorizationRequired: .orange
    case .importCompleted: .green
    case .runtimeFailed: .red
    case .closed: .gray
    }
  }

  var locksWizard: Bool {
    switch self {
    case .checkingPermissions, .automationRunning, .authorizationRequired:
      true
    default:
      false
    }
  }
}

enum PrototypeAction {
  case reset
  case startImport
  case requirePermission
  case checkAgain
  case beginAutomation
  case requireAuthorization
  case authorizationSatisfied
  case completeImport
  case failRuntime
  case acknowledgeFailure
  case close
}

struct PrototypeButton: Identifiable {
  let id = UUID()
  let title: String
  let action: () -> Void

  init(_ title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }
}
