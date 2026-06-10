import Application
import Domain
import Infrastructure
import SwiftUI

// The configuration, table, wizard, and log views are kept together because they share one model.
// swiftlint:disable file_length

private enum PanelLayout {
  static let spacing = 12.0
  static let headerHeight = 32.0
  static let minimumSectionHeight = 150.0
  static let separatorHeight = 12.0
  static let horizontalInset = 12.0
  static let tableHeaderHeight = 30.0
}

private enum PanelCopy {
  static let refreshHint = "Refresh the list if it is empty now."
}

private struct PanelSeparator: View {
  var body: some View {
    Rectangle()
      .fill(Color(nsColor: .separatorColor))
      .frame(height: 1)
      .padding(.horizontal, PanelLayout.horizontalInset)
      .frame(height: PanelLayout.separatorHeight)
      .contentShape(Rectangle())
  }
}

struct RootView: View {
  private enum Destination: Hashable {
    case configuration
    case runtimeLog
  }

  @StateObject private var model = BookmarknotModel(services: InfrastructureServices())
  @State private var destination: Destination? = .configuration

  var body: some View {
    NavigationSplitView {
      List(selection: $destination) {
        Label("Configuration", systemImage: "gearshape").tag(Destination.configuration)
        Label("Runtime Log", systemImage: "doc.plaintext").tag(Destination.runtimeLog)
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    } detail: {
      switch destination {
      case .configuration, .none:
        ConfigurationView(model: model)
      case .runtimeLog:
        RuntimeLogView(model: model)
      }
    }
    .alert(item: $model.dialog) { dialog in
      Alert(title: Text(dialog.rawValue), dismissButton: .default(Text("OK")))
    }
    .sheet(
      isPresented: Binding(
        get: { model.generationSession != nil },
        set: { if !$0 { model.cancelGeneration() } }
      )
    ) {
      GenerationWizard(model: model)
    }
    .frame(minWidth: 900, minHeight: 600)
  }
}

private struct ConfigurationView: View {
  @ObservedObject var model: BookmarknotModel
  @GestureState private var firstDividerOffset = 0.0
  @GestureState private var secondDividerOffset = 0.0
  @AppStorage("layout.firstDivider") private var firstDividerPosition = 1.0 / 3.0
  @AppStorage("layout.secondDivider") private var secondDividerPosition = 2.0 / 3.0

  var body: some View {
    GeometryReader { geometry in
      let height = max(geometry.size.height, 1)
      let minimum = min(PanelLayout.minimumSectionHeight / height, 1.0 / 3.0)
      let first = clamped(
        firstDividerPosition + firstDividerOffset / height,
        minimum: minimum,
        maximum: secondDividerPosition - minimum
      )
      let second = clamped(
        secondDividerPosition + secondDividerOffset / height,
        minimum: first + minimum,
        maximum: 1 - minimum
      )

      VStack(spacing: 0) {
        VStack(spacing: 0) {
          SourceSection(
            title: "Chrome Artifacts",
            kind: .chrome,
            state: model.chromeState,
            artifacts: model.chromeArtifacts,
            selection: $model.selectedChromeID,
            model: model
          )
        }
        .frame(height: height * first)

        VStack(spacing: 0) {
          PanelSeparator().gesture(firstGesture(height: height, minimum: minimum))
          SourceSection(
            title: "Safari Artifacts",
            kind: .safari,
            state: model.safariState,
            artifacts: model.safariArtifacts,
            selection: $model.selectedSafariID,
            model: model
          )
        }
        .frame(height: height * (second - first))

        VStack(spacing: 0) {
          PanelSeparator().gesture(secondGesture(height: height, minimum: minimum))
          SavedSection(model: model)
        }
        .frame(height: height * (1 - second))
      }
    }
  }

  private func firstGesture(height: Double, minimum: Double) -> some Gesture {
    DragGesture(minimumDistance: 1)
      .updating($firstDividerOffset) { value, state, _ in state = value.translation.height }
      .onEnded { value in
        firstDividerPosition = clamped(
          firstDividerPosition + value.translation.height / height,
          minimum: minimum,
          maximum: secondDividerPosition - minimum
        )
      }
  }

  private func secondGesture(height: Double, minimum: Double) -> some Gesture {
    DragGesture(minimumDistance: 1)
      .updating($secondDividerOffset) { value, state, _ in state = value.translation.height }
      .onEnded { value in
        secondDividerPosition = clamped(
          secondDividerPosition + value.translation.height / height,
          minimum: firstDividerPosition + minimum,
          maximum: 1 - minimum
        )
      }
  }

  private func clamped(_ value: Double, minimum: Double, maximum: Double) -> Double {
    min(max(value, minimum), maximum)
  }
}

private struct SourceSection: View {
  let title: String
  let kind: ArtifactKind
  let state: ArtifactListState
  let artifacts: [SourceArtifact]
  @Binding var selection: SourceArtifact.ID?
  @ObservedObject var model: BookmarknotModel

  var body: some View {
    VStack(spacing: PanelLayout.spacing) {
      HStack {
        Text(title).font(.headline)
        Spacer()
        RefreshButton { model.refresh(kind) }
        Color.clear.frame(width: 150)
      }
      .frame(height: PanelLayout.headerHeight)

      SourceArtifactTable(
        storagePrefix: kind == .chrome ? "chrome" : "safari",
        state: state,
        artifacts: artifacts,
        selection: $selection
      )
    }
    .padding(.horizontal, PanelLayout.horizontalInset)
    .padding(.vertical, PanelLayout.spacing)
  }
}

private struct SavedSection: View {
  @ObservedObject var model: BookmarknotModel

  var body: some View {
    VStack(spacing: PanelLayout.spacing) {
      HStack {
        Text("Bookmarknot Artifacts").font(.headline)
        Spacer()
        RefreshButton { model.refresh(.bookmarknot) }
        Button("Generate") { model.beginGeneration() }
          .disabled(!model.canGenerate)
          .frame(width: 150, alignment: .leading)
      }
      .frame(height: PanelLayout.headerHeight)

      SavedArtifactTable(
        state: model.bookmarknotState,
        artifacts: model.bookmarknotArtifacts,
        selection: $model.selectedBookmarknotID
      )
    }
    .padding(.horizontal, PanelLayout.horizontalInset)
    .padding(.vertical, PanelLayout.spacing)
  }
}

private struct RefreshButton: View {
  let action: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Button("Refresh", action: action)
        .help(PanelCopy.refreshHint)
      TipIcon(label: "Refresh help")
    }
    .frame(width: 150, alignment: .leading)
  }
}

private struct TipIcon: View {
  let label: String
  @State private var isShowingHint = false

  var body: some View {
    Button {
      isShowingHint = true
    } label: {
      Image(systemName: "info.circle")
        .foregroundStyle(isShowingHint ? .primary : .secondary)
        .frame(width: 24, height: 24)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(PanelCopy.refreshHint)
    .accessibilityLabel(label)
    .onHover { isShowingHint = $0 }
    .popover(isPresented: $isShowingHint, arrowEdge: .bottom) {
      Text(PanelCopy.refreshHint)
        .font(.callout)
        .padding(PanelLayout.spacing)
    }
  }
}

private struct SourceArtifactTable: View {
  let state: ArtifactListState
  let artifacts: [SourceArtifact]
  @Binding var selection: SourceArtifact.ID?
  @AppStorage private var showCreated: Bool
  @AppStorage private var showCounts: Bool
  @AppStorage private var showSize: Bool
  @AppStorage private var showStatus: Bool
  @AppStorage private var pathWidth: Double
  @AppStorage private var createdWidth: Double
  @AppStorage private var countsWidth: Double
  @AppStorage private var sizeWidth: Double
  @AppStorage private var statusWidth: Double

  init(
    storagePrefix: String,
    state: ArtifactListState,
    artifacts: [SourceArtifact],
    selection: Binding<SourceArtifact.ID?>
  ) {
    self.state = state
    self.artifacts = artifacts
    _selection = selection
    _showCreated = AppStorage(wrappedValue: true, "columns.\(storagePrefix).created")
    _showCounts = AppStorage(wrappedValue: true, "columns.\(storagePrefix).counts")
    _showSize = AppStorage(wrappedValue: true, "columns.\(storagePrefix).size")
    _showStatus = AppStorage(wrappedValue: true, "columns.\(storagePrefix).status")
    _pathWidth = AppStorage(wrappedValue: 320, "columns.\(storagePrefix).pathWidth")
    _createdWidth = AppStorage(wrappedValue: 145, "columns.\(storagePrefix).createdWidth")
    _countsWidth = AppStorage(wrappedValue: 140, "columns.\(storagePrefix).countsWidth")
    _sizeWidth = AppStorage(wrappedValue: 80, "columns.\(storagePrefix).sizeWidth")
    _statusWidth = AppStorage(wrappedValue: 80, "columns.\(storagePrefix).statusWidth")
  }

  var body: some View {
    TableShell(state: state, isEmpty: artifacts.isEmpty) {
      HStack(spacing: 12) {
        ResizableHeader(title: "Path", width: $pathWidth)
        if showCreated { ResizableHeader(title: "Created", width: $createdWidth) }
        if showCounts { ResizableHeader(title: "Bookmarks / Folders", width: $countsWidth) }
        if showSize { ResizableHeader(title: "Size", width: $sizeWidth) }
        if showStatus { ResizableHeader(title: "Status", width: $statusWidth) }
        ColumnMenu(
          showCreated: $showCreated,
          showCounts: $showCounts,
          showSize: $showSize,
          showStatus: $showStatus
        )
      }
    } rows: {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(artifacts) { artifact in
            HStack(spacing: 12) {
              Text(artifact.path).lineLimit(1).frame(width: pathWidth, alignment: .leading)
              if showCreated {
                Text(artifact.createdAt, format: .dateTime)
                  .frame(width: createdWidth, alignment: .leading)
              }
              if showCounts {
                Text(counts(artifact)).frame(width: countsWidth, alignment: .leading)
              }
              if showSize {
                Text(byteCount(artifact.fileSize)).frame(width: sizeWidth, alignment: .leading)
              }
              if showStatus {
                HStack(spacing: 4) {
                  Text(artifact.status.rawValue)
                }
                .foregroundStyle(artifact.status == .failed ? .orange : .primary)
                .frame(width: statusWidth, alignment: .leading)
              }
              Spacer(minLength: 0)
              if artifact.status == .failed {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
              }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(selection == artifact.id ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { selection = artifact.id }
          }
        }
      }
    }
  }

  private func counts(_ artifact: SourceArtifact) -> String {
    guard let bookmarks = artifact.bookmarkCount, let folders = artifact.folderCount else {
      return "-"
    }
    return "\(bookmarks) / \(folders)"
  }
}

private struct SavedArtifactTable: View {
  let state: ArtifactListState
  let artifacts: [SavedArtifact]
  @Binding var selection: SavedArtifact.ID?
  @AppStorage("columns.bookmarknot.created") private var showCreated = true
  @AppStorage("columns.bookmarknot.counts") private var showCounts = true
  @AppStorage("columns.bookmarknot.size") private var showSize = true
  @AppStorage("columns.bookmarknot.hashWidth") private var hashWidth = 150.0
  @AppStorage("columns.bookmarknot.createdWidth") private var createdWidth = 160.0
  @AppStorage("columns.bookmarknot.countsWidth") private var countsWidth = 140.0
  @AppStorage("columns.bookmarknot.sizeWidth") private var sizeWidth = 80.0

  var body: some View {
    TableShell(state: state, isEmpty: artifacts.isEmpty) {
      HStack(spacing: 12) {
        ResizableHeader(title: "Short Hash", width: $hashWidth)
        if showCreated { ResizableHeader(title: "Created", width: $createdWidth) }
        if showCounts { ResizableHeader(title: "Bookmarks / Folders", width: $countsWidth) }
        if showSize { ResizableHeader(title: "Size", width: $sizeWidth) }
        Menu("Columns") {
          Toggle("Created", isOn: $showCreated)
          Toggle("Counts", isOn: $showCounts)
          Toggle("Size", isOn: $showSize)
        }
        .menuStyle(.borderlessButton)
      }
    } rows: {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(artifacts) { artifact in
            HStack(spacing: 12) {
              Text(artifact.shortHash).monospaced().frame(width: hashWidth, alignment: .leading)
              if showCreated {
                Text(artifact.createdAt, format: .dateTime)
                  .frame(width: createdWidth, alignment: .leading)
              }
              if showCounts {
                Text("\(artifact.bookmarkCount) / \(artifact.folderCount)")
                  .frame(width: countsWidth, alignment: .leading)
              }
              if showSize {
                Text(byteCount(artifact.fileSize)).frame(width: sizeWidth, alignment: .leading)
              }
              Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(selection == artifact.id ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { selection = artifact.id }
          }
        }
      }
    }
  }
}

private struct TableShell<Header: View, Rows: View>: View {
  let state: ArtifactListState
  let isEmpty: Bool
  @ViewBuilder let header: Header
  @ViewBuilder let rows: Rows

  var body: some View {
    ZStack {
      ScrollView(.horizontal) {
        VStack(spacing: 0) {
          header
            .font(.caption.bold())
            .padding(8)
          Divider()
          rows
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, maxHeight: .infinity, alignment: .leading)
      }

      VStack(spacing: 0) {
        Color.clear.frame(height: PanelLayout.tableHeaderHeight)
        if state == .notRefreshed {
          TablePlaceholder(
            title: "Not refreshed",
            systemImage: "arrow.clockwise",
            description: "Use Refresh to load artifacts."
          )
        } else if isEmpty {
          TablePlaceholder(title: "No artifacts", systemImage: "tray")
        } else {
          Color.clear
        }
      }
      .allowsHitTesting(false)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .textBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay { RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)) }
  }
}

private struct TablePlaceholder: View {
  let title: String
  let systemImage: String
  var description: String?

  var body: some View {
    VStack(spacing: PanelLayout.spacing) {
      Image(systemName: systemImage)
        .font(.title2)
        .foregroundStyle(.secondary)
      Text(title)
        .font(.headline)
      if let description {
        Text(description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .multilineTextAlignment(.center)
    .lineLimit(2)
    .minimumScaleFactor(0.75)
    .padding(PanelLayout.spacing)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }
}

private struct ResizableHeader: View {
  let title: String
  @Binding var width: Double
  @GestureState private var dragOffset = 0.0

  var body: some View {
    Text(title)
      .frame(width: max(120, width + dragOffset), alignment: .leading)
      .overlay(alignment: .trailing) {
        Rectangle().fill(Color.secondary.opacity(0.35)).frame(width: 1, height: 18)
          .frame(width: 10).contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 1)
              .updating($dragOffset) { value, state, _ in state = value.translation.width }
              .onEnded { value in width = max(120, width + value.translation.width) }
          )
      }
  }
}

private struct ColumnMenu: View {
  @Binding var showCreated: Bool
  @Binding var showCounts: Bool
  @Binding var showSize: Bool
  @Binding var showStatus: Bool

  var body: some View {
    Menu("Columns") {
      Toggle("Created", isOn: $showCreated)
      Toggle("Counts", isOn: $showCounts)
      Toggle("Size", isOn: $showSize)
      Toggle("Status", isOn: $showStatus)
    }
    .menuStyle(.borderlessButton)
  }
}

private struct GenerationWizard: View {
  @ObservedObject var model: BookmarknotModel
  @State private var expandedFolders = Set<String>()
  @State private var confirmAbort = false

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Text("Generate Bookmarknot Artifact").font(.title2.bold())
        Spacer()
        if let session = model.generationSession {
          Text(
            "\(session.resolvedCount) of \(session.totalCount) resolved (\(percentage(session))%)"
          )
          .foregroundStyle(.secondary)
        }
      }

      ScrollView {
        LazyVStack(spacing: 6) {
          ForEach(visibleDecisions) { decision in
            DecisionRow(
              decision: decision,
              isExpanded: expandedFolders.contains(decision.id),
              toggleExpanded: { toggleExpanded(decision.id) },
              resolve: { state in
                model.resolveDecision(decision.id, as: state, recursively: decision.kind == .folder)
              }
            )
          }
        }
      }
      .frame(minWidth: 720, minHeight: 460)

      HStack {
        Button("Cancel") { confirmAbort = true }
        Spacer()
        Button("Done") { model.completeGeneration() }
          .keyboardShortcut(.defaultAction)
          .disabled(
            !(model.generationSession?.isResolved ?? false)
              || !(model.generationSession?.hasAcceptedContent ?? false))
      }
    }
    .padding(20)
    .interactiveDismissDisabled()
    .alert(
      "Abort generation? Unresolved progress will be lost and no artifact will be saved.",
      isPresented: $confirmAbort
    ) {
      Button("Continue Generation", role: .cancel) {}
      Button("Abort", role: .destructive) { model.cancelGeneration() }
    }
  }

  private var visibleDecisions: [DecisionOccurrence] {
    guard let decisions = model.generationSession?.decisions else { return [] }
    return decisions.filter { decision in
      guard decision.path.count > 1 else { return true }
      for length in 1..<decision.path.count {
        let parentPath = Array(decision.path.prefix(length))
        let parent = decisions.first {
          $0.side == decision.side && $0.path == parentPath && $0.kind == .folder
        }
        if let parent, !expandedFolders.contains(parent.id) { return false }
      }
      return true
    }
  }

  private func toggleExpanded(_ id: String) {
    if expandedFolders.contains(id) {
      expandedFolders.remove(id)
    } else {
      expandedFolders.insert(id)
    }
  }

  private func percentage(_ session: GenerationSession) -> Int {
    guard session.totalCount > 0 else { return 0 }
    return Int((Double(session.resolvedCount) / Double(session.totalCount) * 100).rounded())
  }
}

private struct DecisionRow: View {
  let decision: DecisionOccurrence
  let isExpanded: Bool
  let toggleExpanded: () -> Void
  let resolve: (DecisionState) -> Void

  var body: some View {
    HStack(spacing: 10) {
      Color.clear.frame(width: Double(decision.depth) * 18)
      if decision.kind == .folder {
        Button(action: toggleExpanded) {
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
        }
        .buttonStyle(.plain)
      } else {
        Color.clear.frame(width: 12)
      }
      Image(systemName: decision.kind == .folder ? "folder" : "bookmark")
      VStack(alignment: .leading, spacing: 2) {
        Text(decision.title).lineLimit(1)
        if let url = decision.url {
          Text(url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      Spacer()
      Text(decision.side == .current ? "Current" : "Incoming")
        .foregroundStyle(decision.side == .current ? .red : .green)
      Button("Accept") { resolve(.accepted) }
        .buttonStyle(.borderedProminent)
        .tint(.green)
      Button("Reject") { resolve(.rejected) }
        .buttonStyle(.borderedProminent)
        .tint(.red)
      Image(systemName: stateIcon).frame(width: 16)
    }
    .padding(8)
    .background(sideColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
  }

  private var sideColor: Color { decision.side == .current ? .red : .green }

  private var stateIcon: String {
    switch decision.state {
    case .unresolved: "circle"
    case .accepted: "checkmark.circle.fill"
    case .rejected: "xmark.circle.fill"
    }
  }
}

private struct RuntimeLogView: View {
  @ObservedObject var model: BookmarknotModel

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: PanelLayout.spacing) {
        HStack {
          Text("Runtime Log").font(.headline)
          Spacer()
          Button("Clean") { model.cleanRuntimeLog() }.frame(width: 150, alignment: .leading)
          Color.clear.frame(width: 150)
        }
        .frame(height: PanelLayout.headerHeight)

        Group {
          if model.runtimeLogContent.isEmpty {
            TablePlaceholder(title: "No runtime log entries", systemImage: "doc.plaintext")
          } else {
            ScrollView {
              Text(model.runtimeLogContent)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(PanelLayout.spacing)
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay { RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)) }
      }
      .padding(.horizontal, PanelLayout.horizontalInset)
      .padding(.vertical, PanelLayout.spacing)
    }
  }
}

private func byteCount(_ count: Int64) -> String {
  ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
}
