import SwiftUI

// swiftlint:disable trailing_comma

struct StatusBadge: View {
  let state: PrototypeRunState

  var body: some View {
    HStack(spacing: 7) {
      Circle()
        .fill(state.tone)
        .frame(width: 8, height: 8)
      Text(state.rawValue)
        .font(.callout.weight(.semibold))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
    .overlay {
      Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1)
    }
  }
}

struct ExportSummary: View {
  let browser: PrototypeBrowser
  let exportPath: String
  var compact = false

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 5 : 9) {
      HStack {
        Label(browser.rawValue, systemImage: browser == .chrome ? "globe" : "safari")
          .font(.headline)
        Spacer()
        Text(browser.importMode)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      Text(exportPath)
        .font(.system(compact ? .caption : .callout, design: .monospaced))
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .textSelection(.enabled)
    }
  }
}

struct BrowserPicker: View {
  @Binding var browser: PrototypeBrowser

  var body: some View {
    Picker("Target browser", selection: $browser) {
      ForEach(PrototypeBrowser.allCases) { browser in
        Text(browser.rawValue).tag(browser)
      }
    }
    .pickerStyle(.segmented)
  }
}

struct RunningIndicator: View {
  let title: String
  let detail: String

  var body: some View {
    VStack(spacing: 14) {
      ProgressView()
        .controlSize(.large)
      Text(title)
        .font(.title3.weight(.semibold))
      Text(detail)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 440)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct PermissionActions: View {
  let perform: (PrototypeAction) -> Void

  var body: some View {
    HStack(spacing: 8) {
      Button("Open System Settings") {}
        .buttonStyle(.bordered)
      Button("Check Again") {
        perform(.checkAgain)
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

struct PrototypeSwitcher: View {
  @Binding var variant: PrototypeVariant

  var body: some View {
    HStack(spacing: 10) {
      Button(action: previous) {
        Image(systemName: "arrow.left")
      }
      .keyboardShortcut(.leftArrow, modifiers: [])

      Text("\(variant.key) - \(variant.rawValue)")
        .font(.callout.weight(.semibold))
        .frame(minWidth: 180)

      Button(action: next) {
        Image(systemName: "arrow.right")
      }
      .keyboardShortcut(.rightArrow, modifiers: [])
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(Color.black.opacity(0.9), in: Capsule())
    .foregroundStyle(.white)
  }

  private func previous() {
    guard let index = PrototypeVariant.allCases.firstIndex(of: variant) else { return }
    let newIndex = index == 0 ? PrototypeVariant.allCases.count - 1 : index - 1
    variant = PrototypeVariant.allCases[newIndex]
  }

  private func next() {
    guard let index = PrototypeVariant.allCases.firstIndex(of: variant) else { return }
    let newIndex = index == PrototypeVariant.allCases.count - 1 ? 0 : index + 1
    variant = PrototypeVariant.allCases[newIndex]
  }
}

struct PrototypeScenarioBar: View {
  let browser: PrototypeBrowser
  let state: PrototypeRunState
  let perform: (PrototypeAction) -> Void

  var body: some View {
    HStack(spacing: 8) {
      Text("PROTOTYPE")
        .font(.caption2.weight(.black))
        .foregroundStyle(.orange)
      ForEach(buttons) { button in
        Button(button.title, action: button.action)
          .buttonStyle(.bordered)
          .controlSize(.small)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
    .background(.regularMaterial, in: Capsule())
    .overlay {
      Capsule().stroke(Color.orange.opacity(0.35), lineWidth: 1)
    }
  }

  private var buttons: [PrototypeButton] {
    switch state {
    case .ready:
      [PrototypeButton("Reset", action: { perform(.reset) })]
    case .checkingPermissions:
      [
        PrototypeButton("Permission Missing", action: { perform(.requirePermission) }),
        PrototypeButton("Preflight Passed", action: { perform(.beginAutomation) }),
        PrototypeButton("Runtime Error", action: { perform(.failRuntime) }),
      ]
    case .permissionRequired:
      [PrototypeButton("Runtime Error", action: { perform(.failRuntime) })]
    case .automationRunning:
      browser == .safari
        ? [
          PrototypeButton("Authorization Appears", action: { perform(.requireAuthorization) }),
          PrototypeButton("Import Completed", action: { perform(.completeImport) }),
          PrototypeButton("Runtime Error", action: { perform(.failRuntime) }),
        ]
        : [
          PrototypeButton("Import Completed", action: { perform(.completeImport) }),
          PrototypeButton("Runtime Error", action: { perform(.failRuntime) }),
        ]
    case .authorizationRequired:
      [PrototypeButton("Authorization Satisfied", action: { perform(.authorizationSatisfied) })]
    case .importCompleted:
      [PrototypeButton("Reset", action: { perform(.reset) })]
    case .runtimeFailed:
      []
    case .closed:
      [PrototypeButton("Reopen", action: { perform(.reset) })]
    }
  }
}

// swiftlint:enable trailing_comma
