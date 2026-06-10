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
func generationAllowsSharedContentWithoutExplicitDecisions() throws {
  let services = FakeServices()
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.safari)
  model.refresh(.bookmarknot)

  model.beginGeneration()

  let session = try #require(model.generationSession)
  #expect(session.decisions.isEmpty)
  #expect(session.isResolved)
  #expect(session.hasAcceptedContent)

  model.completeGeneration()

  #expect(model.bookmarknotArtifacts.count == 1)
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

@MainActor
@Test
func bookmarknotRefreshSelectsTheNewestArtifact() throws {
  let services = FakeServices()
  let artifact = try services.canonicalize(
    .folder(title: "", children: [.leaf(title: "Example", url: "https://example.com")])
  )
  let newest = SavedArtifact(
    hash: "newest",
    createdAt: Date(timeIntervalSince1970: 2),
    bookmarkCount: 1,
    folderCount: 0,
    fileSize: 1,
    artifact: artifact
  )
  let older = SavedArtifact(
    hash: "older",
    createdAt: Date(timeIntervalSince1970: 1),
    bookmarkCount: 1,
    folderCount: 0,
    fileSize: 1,
    artifact: artifact
  )
  services.setSavedArtifacts([newest, older])
  let model = BookmarknotModel(services: services)

  model.refresh(.bookmarknot)
  model.selectedBookmarknotID = older.id
  model.refresh(.bookmarknot)

  #expect(model.selectedBookmarknotID == newest.id)
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

  func setSavedArtifacts(_ artifacts: [SavedArtifact]) {
    saved = artifacts
  }

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
