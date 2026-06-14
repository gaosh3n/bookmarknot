import Application
import Combine
import Domain
import Foundation
import Testing

@MainActor
@Test
func generationExistingRouteKeepsTheExistingArtifactSelectedAfterRefresh() throws {
  let canonicalizer = ArtifactCanonicalizer { _ in "identity" }
  let incomingArtifact = try canonicalizer.canonicalize(
    .folder(title: "", children: [.leaf(title: "Example", url: "https://example.com")])
  )
  let existingArtifact = try canonicalizer.canonicalize(
    .folder(title: "", children: [.leaf(title: "Older", url: "https://older.example.com")])
  )
  let newerArtifact = try canonicalizer.canonicalize(
    .folder(title: "", children: [.leaf(title: "Newer", url: "https://newer.example.com")])
  )
  let existing = SavedArtifact(
    hash: "existing",
    createdAt: Date(timeIntervalSince1970: 1),
    bookmarkCount: 1,
    folderCount: 0,
    fileSize: Int64(existingArtifact.data.count),
    artifact: existingArtifact
  )
  let newer = SavedArtifact(
    hash: "newer",
    createdAt: Date(timeIntervalSince1970: 2),
    bookmarkCount: 1,
    folderCount: 0,
    fileSize: Int64(newerArtifact.data.count),
    artifact: newerArtifact
  )
  let services = ExistingSelectionServices(
    selectedArtifact: incomingArtifact,
    savedArtifacts: [newer, existing],
    existing: existing
  )
  let model = BookmarknotModel(services: services)

  model.refresh(.chrome)
  model.refresh(.bookmarknot)
  model.beginGeneration()
  for decision in try #require(model.generationSession).decisions {
    model.resolveDecision(decision.id, as: .accepted, recursively: decision.kind == .folder)
  }
  model.completeGeneration()

  #expect(model.dialog == .noChange)
  #expect(model.selectedBookmarknotID == existing.id)
  #expect(model.bookmarknotArtifacts.map(\.id) == [newer.id, existing.id])
}

private final class ExistingSelectionServices: BookmarknotServices {
  private let canonicalizer = ArtifactCanonicalizer { _ in "identity" }
  private let selectedArtifact: CanonicalArtifact
  private let savedArtifacts: [SavedArtifact]
  private let existing: SavedArtifact
  private let runtimeLogSubject = PassthroughSubject<String, Never>()
  private var runtimeLogContent = ""

  init(
    selectedArtifact: CanonicalArtifact,
    savedArtifacts: [SavedArtifact],
    existing: SavedArtifact
  ) {
    self.selectedArtifact = selectedArtifact
    self.savedArtifacts = savedArtifacts
    self.existing = existing
  }

  var runtimeLogUpdates: AnyPublisher<String, Never> {
    runtimeLogSubject.eraseToAnyPublisher()
  }

  func refreshSource(_ browser: BrowserKind) throws -> [SourceArtifact] {
    [
      SourceArtifact(
        id: browser.rawValue,
        browser: browser,
        path: "/\(browser.rawValue)/Bookmarks",
        createdAt: Date(),
        bookmarkCount: 1,
        folderCount: 0,
        fileSize: 1,
        status: .ready,
        artifact: selectedArtifact
      )
    ]
  }

  func refreshSavedArtifacts() throws -> [SavedArtifact] {
    savedArtifacts
  }

  func canonicalize(_ root: BookmarkNode) throws -> CanonicalArtifact {
    try canonicalizer.canonicalize(root)
  }

  func save(_ artifact: CanonicalArtifact) throws -> ArtifactSaveOutcome {
    return .existing(existing)
  }

  func runtimeLog() -> String { runtimeLogContent }

  func cleanRuntimeLog() throws {
    runtimeLogContent = ""
    runtimeLogSubject.send("")
  }

  func log(_ level: RuntimeLogLevel, _ message: String) {
    runtimeLogContent += "[\(level.rawValue)] \(message)\n"
    runtimeLogSubject.send(runtimeLogContent)
  }
}
