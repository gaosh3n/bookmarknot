import Application
import Combine
import Domain
import Foundation
import Testing

@MainActor
@Test
func mixedSourceGenerationCountsNestedSameURLConflictsWhileTheyRemainCollapsed() throws {
  let services = NestedConflictGenerationServices()
  services.chromeRows = [
    try services.makeReadyRow(browser: .chrome, root: incomingNestedConflictRoot())
  ]
  services.safariRows = [
    try services.makeReadyRow(browser: .safari, root: currentNestedConflictRoot())
  ]
  let model = BookmarknotModel(services: services)
  refreshForNestedConflictGeneration(model)
  model.beginGeneration()

  let decisions = try #require(model.generationSession?.decisions)
  #expect(decisions.map(\.title) == nestedConflictDecisionTitles())
  #expect(model.generationSession?.resolvedCount == 0)
  #expect(model.generationSession?.totalCount == 5)

  let currentFolder = try #require(
    decisions.first(where: { $0.side == .current && $0.title == "Shared Folder" })
  )
  let incomingFolder = try #require(
    decisions.first(where: { $0.side == .incoming && $0.title == "Shared Folder" })
  )

  model.resolveDecision(currentFolder.id, as: .accepted, recursively: true)
  #expect(model.generationSession?.resolvedCount == 3)

  model.resolveDecision(incomingFolder.id, as: .accepted, recursively: true)
  #expect(model.generationSession?.resolvedCount == 5)
  #expect(model.generationSession?.totalCount == 5)
}

@MainActor private func refreshForNestedConflictGeneration(_ model: BookmarknotModel) {
  model.refresh(.chrome)
  model.refresh(.safari)
  model.refresh(.bookmarknot)
}

private func currentNestedConflictRoot() -> BookmarkNode {
  .folder(
    title: "",
    children: [
      .folder(
        title: "Shared Folder",
        children: [.leaf(title: "Current Shared", url: "HTTPS://Example.COM:443/path")]
      )
    ])
}

private func incomingNestedConflictRoot() -> BookmarkNode {
  .folder(
    title: "",
    children: [
      .folder(
        title: "Shared Folder",
        children: [
          .leaf(title: "Incoming Shared", url: "https://example.com/path"),
          // swiftlint:disable:next trailing_comma
          .leaf(title: "Incoming Only", url: "https://incoming-only.example"),
        ]
      )
    ])
}

private func nestedConflictDecisionTitles() -> [String] {
  ["Shared Folder", "Current Shared", "Shared Folder", "Incoming Only", "Incoming Shared"]
}

private final class NestedConflictGenerationServices: BookmarknotServices {
  private let canonicalizer = ArtifactCanonicalizer { _ in "identity" }
  private let runtimeLogSubject = PassthroughSubject<String, Never>()
  private var runtimeLogContent = ""

  var chromeRows: [SourceArtifact] = []
  var safariRows: [SourceArtifact] = []

  var runtimeLogUpdates: AnyPublisher<String, Never> {
    runtimeLogSubject.eraseToAnyPublisher()
  }

  func makeReadyRow(browser: BrowserKind, root: BookmarkNode) throws -> SourceArtifact {
    let artifact = try canonicalizer.canonicalize(root)
    return SourceArtifact(
      id: browser.rawValue,
      browser: browser,
      path: browser == .safari ? "/Safari/Bookmarks.plist" : "/Chrome/Bookmarks",
      createdAt: Date(),
      bookmarkCount: artifact.bookmarkCount,
      folderCount: artifact.folderCount,
      fileSize: Int64(artifact.data.count),
      status: .ready,
      artifact: artifact
    )
  }

  func refreshSource(_ browser: BrowserKind) throws -> [SourceArtifact] {
    switch browser {
    case .chrome: chromeRows
    case .safari: safariRows
    }
  }

  func refreshSavedArtifacts() throws -> [SavedArtifact] { [] }
  func canonicalize(_ root: BookmarkNode) throws -> CanonicalArtifact {
    try canonicalizer.canonicalize(root)
  }
  func save(_ artifact: CanonicalArtifact) throws -> ArtifactSaveOutcome {
    fatalError("save not expected")
  }
  func runtimeLog() -> String { runtimeLogContent }
  func cleanRuntimeLog() throws {}

  func log(_ level: RuntimeLogLevel, _ message: String) {
    runtimeLogContent += "[\(level.rawValue)] \(message)\n"
    runtimeLogSubject.send(runtimeLogContent)
  }
}
