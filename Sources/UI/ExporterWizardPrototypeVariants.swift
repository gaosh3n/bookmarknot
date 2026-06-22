import SwiftUI

// swiftlint:disable file_length

struct GuidedRailVariant: View {
  @Binding var browser: PrototypeBrowser
  let state: PrototypeRunState
  let exportPath: String
  let perform: (PrototypeAction) -> Void

  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Import Bookmarks")
          .font(.title2.bold())
          .padding(.bottom, 14)

        RailStep(number: 1, title: "Review", status: reviewStatus)
        RailStep(number: 2, title: "Permissions", status: permissionStatus)
        RailStep(number: 3, title: "Import", status: importStatus)
        RailStep(number: 4, title: "Finish", status: finishStatus)

        Spacer()
        if state.locksWizard {
          Label("Wizard stays open during import", systemImage: "lock.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(26)
      .frame(width: 230, alignment: .topLeading)
      .background(Color(nsColor: .controlBackgroundColor))

      VStack(alignment: .leading, spacing: 20) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(stageTitle)
              .font(.title2.bold())
            Text(stageSubtitle)
              .foregroundStyle(.secondary)
          }
          Spacer()
          StatusBadge(state: state)
        }

        Divider()
        stageContent
        Spacer()
      }
      .padding(30)
    }
  }

  @ViewBuilder
  private var stageContent: some View {
    switch state {
    case .ready:
      VStack(alignment: .leading, spacing: 18) {
        BrowserPicker(browser: $browser)
          .frame(maxWidth: 380)
        ExportSummary(browser: browser, exportPath: exportPath)
          .padding(18)
          .background(
            Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        Text(browser.runExpectation)
          .foregroundStyle(.secondary)
        Button("Start Import") { perform(.startImport) }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
      }
    case .checkingPermissions:
      RunningIndicator(
        title: "Checking access",
        detail:
          "Bookmarknot is checking the selected export, browser, and required macOS permissions."
      )
    case .permissionRequired:
      VStack(alignment: .leading, spacing: 16) {
        Label(
          "Bookmarknot needs permission to control browser import UI.",
          systemImage: "hand.raised.fill"
        )
        .font(.title3.weight(.semibold))
        Text("Grant the requested access in System Settings, then return here and check again.")
          .foregroundStyle(.secondary)
        PermissionActions(perform: perform)
      }
    case .automationRunning:
      RunningIndicator(
        title: "Importing into \(browser.rawValue)",
        detail:
          "Keep the browser available. Bookmarknot will continue when the browser-owned operation finishes."
      )
    case .authorizationRequired:
      authorizationContent
    case .importCompleted:
      completionContent
    case .runtimeFailed:
      EmptyView()
    case .closed:
      closedContent
    }
  }

  private var authorizationContent: some View {
    VStack(spacing: 16) {
      Image(systemName: "touchid")
        .font(.system(size: 52))
        .foregroundStyle(.orange)
      Text("Safari needs your authorization")
        .font(.title2.weight(.semibold))
      Text(
        "Safari is trying to import browsing data. Use Touch ID or enter your password to allow this."
      )
      .multilineTextAlignment(.center)
      .foregroundStyle(.secondary)
      .frame(maxWidth: 460)
      Text("Bookmarknot will continue automatically.")
        .font(.callout.weight(.semibold))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var completionContent: some View {
    VStack(alignment: .leading, spacing: 18) {
      Label("Bookmarks imported", systemImage: "checkmark.circle.fill")
        .font(.title2.weight(.semibold))
        .foregroundStyle(.green)
      ExportSummary(browser: browser, exportPath: exportPath)
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
      Button("Close") { perform(.close) }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
  }

  private var closedContent: some View {
    ContentUnavailableView(
      "Wizard Closed",
      systemImage: "rectangle.slash",
      description: Text("The prototype keeps this shell visible so another scenario can be opened.")
    )
  }

  private var stageTitle: String {
    switch state {
    case .ready: "Review Import"
    case .checkingPermissions, .permissionRequired: "Prepare Access"
    case .automationRunning, .authorizationRequired: "Browser Import"
    case .importCompleted: "Import Completed"
    case .runtimeFailed: "Runtime Error"
    case .closed: "Wizard Closed"
    }
  }

  private var stageSubtitle: String {
    switch state {
    case .ready: "Confirm the export and target browser before Bookmarknot takes control."
    case .checkingPermissions: "No browser changes occur during this check."
    case .permissionRequired: "The current run is paused before browser automation."
    case .automationRunning: "The wizard cannot be closed while browser mutation is active."
    case .authorizationRequired: "Bookmarknot is waiting without interrupting Safari."
    case .importCompleted: "The automated browser-owned operation finished successfully."
    case .runtimeFailed: "The run stopped."
    case .closed: "The attached sheet would now be dismissed."
    }
  }

  private var reviewStatus: RailStatus {
    state == .ready ? .active : .complete
  }

  private var permissionStatus: RailStatus {
    switch state {
    case .checkingPermissions, .permissionRequired: .active
    case .ready: .pending
    default: .complete
    }
  }

  private var importStatus: RailStatus {
    switch state {
    case .automationRunning, .authorizationRequired: .active
    case .importCompleted, .closed: .complete
    default: .pending
    }
  }

  private var finishStatus: RailStatus {
    state == .importCompleted ? .active : (state == .closed ? .complete : .pending)
  }
}

private enum RailStatus {
  case pending
  case active
  case complete
}

private struct RailStep: View {
  let number: Int
  let title: String
  let status: RailStatus

  var body: some View {
    HStack(spacing: 11) {
      ZStack {
        Circle()
          .fill(circleColor)
          .frame(width: 28, height: 28)
        if status == .complete {
          Image(systemName: "checkmark")
            .font(.caption.bold())
            .foregroundStyle(.white)
        } else {
          Text("\(number)")
            .font(.caption.bold())
            .foregroundStyle(status == .active ? .white : .secondary)
        }
      }
      Text(title)
        .font(.callout.weight(status == .active ? .semibold : .regular))
        .foregroundStyle(status == .pending ? .secondary : .primary)
    }
    .padding(.vertical, 6)
  }

  private var circleColor: Color {
    switch status {
    case .pending: Color.secondary.opacity(0.14)
    case .active: .accentColor
    case .complete: .green
    }
  }
}

struct JourneyVariant: View {
  @Binding var browser: PrototypeBrowser
  let state: PrototypeRunState
  let exportPath: String
  let perform: (PrototypeAction) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Import Journey")
            .font(.system(size: 30, weight: .heavy, design: .serif))
          Text("One continuous view of what Bookmarknot owns and where the browser participates.")
            .foregroundStyle(.secondary)
        }
        Spacer()
        StatusBadge(state: state)
      }

      JourneyTrack(state: state)

      HStack(alignment: .top, spacing: 22) {
        VStack(alignment: .leading, spacing: 16) {
          Text("Import target")
            .font(.title3.bold())
          BrowserPicker(browser: $browser)
            .disabled(state != .ready)
          ExportSummary(browser: browser, exportPath: exportPath)
          Text(browser.runExpectation)
            .foregroundStyle(.secondary)
          if state == .ready {
            Button("Start Import") { perform(.startImport) }
              .buttonStyle(.borderedProminent)
              .controlSize(.large)
          }
        }
        .padding(22)
        .frame(width: 360, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))

        journeyStatus
          .padding(24)
          .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
          .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
      }
      Spacer()
    }
    .padding(28)
  }

  @ViewBuilder
  private var journeyStatus: some View {
    switch state {
    case .ready:
      statusMessage(
        icon: "arrow.right.circle",
        title: "Ready when you are",
        detail: "No browser action begins until Start Import is selected."
      )
    case .checkingPermissions:
      RunningIndicator(
        title: "Running preflight", detail: "Checking access without changing browser data.")
    case .permissionRequired:
      VStack(alignment: .leading, spacing: 16) {
        statusMessage(
          icon: "gear.badge.xmark",
          title: "Permission required",
          detail:
            "Grant access in System Settings. Bookmarknot will remain idle until you check again."
        )
        PermissionActions(perform: perform)
      }
    case .automationRunning:
      RunningIndicator(
        title: "Browser import in progress",
        detail: "Bookmarknot is driving \(browser.rawValue)'s own bookmark import flow."
      )
    case .authorizationRequired:
      statusMessage(
        icon: "touchid",
        title: "Authorize in Safari",
        detail:
          "Use Touch ID or enter your password. Bookmarknot is standing by and will continue automatically."
      )
    case .importCompleted:
      VStack(alignment: .leading, spacing: 18) {
        statusMessage(
          icon: "checkmark.seal.fill",
          title: "Import completed",
          detail: "Bookmarknot completed the browser-owned import operation for this export."
        )
        Button("Close") { perform(.close) }
          .buttonStyle(.borderedProminent)
      }
    case .runtimeFailed:
      EmptyView()
    case .closed:
      statusMessage(
        icon: "rectangle.slash",
        title: "Wizard closed",
        detail: "The attached sheet has ended. Use the prototype control to reopen it."
      )
    }
  }

  private func statusMessage(icon: String, title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 38))
        .foregroundStyle(state.tone)
      Text(title)
        .font(.title2.weight(.semibold))
      Text(detail)
        .foregroundStyle(.secondary)
    }
  }
}

private struct JourneyTrack: View {
  let state: PrototypeRunState

  private let labels = ["Review", "Preflight", "Browser", "Finish"]

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
        HStack(spacing: 0) {
          VStack(spacing: 7) {
            Circle()
              .fill(index <= activeIndex ? state.tone : Color.secondary.opacity(0.18))
              .frame(width: 12, height: 12)
            Text(label)
              .font(.caption.weight(index == activeIndex ? .semibold : .regular))
              .foregroundStyle(index <= activeIndex ? .primary : .secondary)
          }
          if index < labels.count - 1 {
            Rectangle()
              .fill(index < activeIndex ? state.tone : Color.secondary.opacity(0.18))
              .frame(height: 2)
              .padding(.horizontal, 8)
              .padding(.bottom, 22)
          }
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  private var activeIndex: Int {
    switch state {
    case .ready: 0
    case .checkingPermissions, .permissionRequired: 1
    case .automationRunning, .authorizationRequired: 2
    case .importCompleted, .closed: 3
    case .runtimeFailed: 2
    }
  }
}

struct FocusedSheetVariant: View {
  @Binding var browser: PrototypeBrowser
  let state: PrototypeRunState
  let exportPath: String
  let perform: (PrototypeAction) -> Void

  var body: some View {
    VStack {
      Spacer(minLength: 18)
      VStack(spacing: 0) {
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text("Import Bookmarks")
              .font(.title2.bold())
            Text(state.rawValue)
              .font(.callout)
              .foregroundStyle(state.tone)
          }
          Spacer()
          if state.locksWizard {
            Image(systemName: "lock.fill")
              .foregroundStyle(.secondary)
              .help("The wizard cannot be closed during an active import")
          }
        }
        .padding(22)

        Divider()

        focusedContent
          .padding(24)
          .frame(maxWidth: .infinity, minHeight: 310, alignment: .topLeading)

        if state == .ready || state == .permissionRequired || state == .importCompleted {
          Divider()
          footer
            .padding(18)
        }
      }
      .frame(width: 570)
      .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.primary.opacity(0.12), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.09), radius: 22, y: 8)
      Spacer(minLength: 18)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.primary.opacity(0.035))
  }

  @ViewBuilder
  private var focusedContent: some View {
    switch state {
    case .ready:
      VStack(alignment: .leading, spacing: 18) {
        Text("Choose where to import the selected export.")
          .font(.headline)
        BrowserPicker(browser: $browser)
        ExportSummary(browser: browser, exportPath: exportPath, compact: true)
          .padding(15)
          .background(
            Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        Text(browser.runExpectation)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    case .checkingPermissions:
      RunningIndicator(
        title: "Checking permissions", detail: "This check does not change browser data.")
    case .permissionRequired:
      VStack(alignment: .leading, spacing: 14) {
        Image(systemName: "hand.raised.fill")
          .font(.system(size: 34))
          .foregroundStyle(.orange)
        Text("Allow browser control")
          .font(.title3.bold())
        Text("Grant Automation and Accessibility access in System Settings, then check again.")
          .foregroundStyle(.secondary)
      }
    case .automationRunning:
      RunningIndicator(
        title: "Importing into \(browser.rawValue)",
        detail: "Bookmarknot is controlling the browser-owned import flow."
      )
    case .authorizationRequired:
      VStack(spacing: 15) {
        Image(systemName: "touchid")
          .font(.system(size: 52))
          .foregroundStyle(.orange)
        Text("Authorize the Safari import")
          .font(.title3.bold())
        Text(
          "Use Touch ID or enter your password in Safari. This wizard will continue automatically."
        )
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .importCompleted:
      VStack(spacing: 16) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 48))
          .foregroundStyle(.green)
        Text("Import completed")
          .font(.title2.bold())
        ExportSummary(browser: browser, exportPath: exportPath, compact: true)
          .padding(15)
          .background(
            Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
      }
      .frame(maxWidth: .infinity)
    case .runtimeFailed:
      EmptyView()
    case .closed:
      ContentUnavailableView("Wizard Closed", systemImage: "rectangle.slash")
    }
  }

  @ViewBuilder
  private var footer: some View {
    HStack {
      Spacer()
      switch state {
      case .ready:
        Button("Start Import") { perform(.startImport) }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
      case .permissionRequired:
        PermissionActions(perform: perform)
      case .importCompleted:
        Button("Close") { perform(.close) }
          .buttonStyle(.borderedProminent)
      default:
        EmptyView()
      }
    }
  }
}

// swiftlint:enable file_length
