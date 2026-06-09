import Domain
import Foundation
import Testing

@testable import Application

@MainActor
@Test
func generationRequiresValidLocalStateAndAUsableSelectedSource() throws {
  let services = FakeServices()
  let model = BookmarknotModel(services: services)

  model.refresh(.chrome)
  #expect(!model.canGenerate)
  model.refresh(.bookmarknot)
  #expect(model.canGenerate)

  model.beginGeneration()
  for decision in try #require(model.generationSession).decisions {
    model.resolveDecision(decision.id, as: .accepted, recursively: decision.kind == .folder)
  }
  model.completeGeneration()

  #expect(model.generationSession == nil)
  #expect(model.bookmarknotArtifacts.count == 1)
  #expect(model.selectedBookmarknotID == model.bookmarknotArtifacts.first?.id)
}

@MainActor
@Test
func failedPostSaveRefreshKeepsTheLoadErrorAndClearsSelection() throws {
  let services = FakeServices()
  services.failSavedArtifactRefreshAfterSave = true
  services.saveAsExisting = true
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.bookmarknot)
  model.beginGeneration()
  for decision in try #require(model.generationSession).decisions {
    model.resolveDecision(decision.id, as: .accepted, recursively: decision.kind == .folder)
  }

  model.completeGeneration()

  #expect(model.generationSession == nil)
  #expect(model.bookmarknotArtifacts.isEmpty)
  #expect(model.selectedBookmarknotID == nil)
  #expect(model.dialog == .cannotLoad)
}

private enum FakeError: Error {
  case cannotRefreshSavedArtifacts
}

private final class FakeServices: BookmarknotServices {
  private let canonicalizer = ArtifactCanonicalizer { _ in "identity" }
  private var saved: [SavedArtifact] = []
  private var savedArtifactRefreshError: Error?
  var failSavedArtifactRefreshAfterSave = false
  var saveAsExisting = false

  func refreshSource(_ browser: BrowserKind) throws -> [SourceArtifact] {
    let artifact = try canonicalizer.canonicalize(
      .folder(title: "", children: [.leaf(title: "Example", url: "https://example.com")])
    )
    return [
      SourceArtifact(
        id: browser.rawValue,
        browser: browser,
        path: "/\(browser.rawValue)/Bookmarks",
        createdAt: Date(),
        bookmarkCount: 1,
        folderCount: 0,
        fileSize: 1,
        status: .ready,
        artifact: artifact
      )
    ]
  }

  func refreshSavedArtifacts() throws -> [SavedArtifact] {
    if let savedArtifactRefreshError { throw savedArtifactRefreshError }
    return saved
  }

  func canonicalize(_ root: BookmarkNode) throws -> CanonicalArtifact {
    try canonicalizer.canonicalize(root)
  }

  func save(_ artifact: CanonicalArtifact) throws -> ArtifactSaveOutcome {
    let result = SavedArtifact(
      hash: "hash",
      createdAt: Date(),
      bookmarkCount: artifact.bookmarkCount,
      folderCount: artifact.folderCount,
      fileSize: Int64(artifact.data.count),
      artifact: artifact
    )
    saved = [result]
    if failSavedArtifactRefreshAfterSave {
      savedArtifactRefreshError = FakeError.cannotRefreshSavedArtifacts
    }
    return saveAsExisting ? .existing(result) : .created(result)
  }

  func runtimeLog() -> String { "" }
  func cleanRuntimeLog() throws {}
  func log(_ message: String) {}
}
