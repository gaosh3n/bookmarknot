import Application
import Combine
import Domain
import Foundation
import Testing

@MainActor
@Test
func failedSaveAbortsGenerationWithoutChangingTheSavedArtifactHistory() throws {
  let services = SaveFailureServices()
  services.saveError = SaveFailureError.cannotSaveArtifact
  let seededArtifact = try services.canonicalize(
    .folder(title: "", children: [.leaf(title: "Existing", url: "https://existing.example")])
  )
  let existing = SavedArtifact(
    hash: "existing",
    createdAt: Date(timeIntervalSince1970: 1),
    bookmarkCount: 1,
    folderCount: 0,
    fileSize: Int64(seededArtifact.data.count),
    artifact: seededArtifact
  )
  services.setSavedArtifacts([existing])
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.bookmarknot)
  let previousArtifacts = model.bookmarknotArtifacts
  let previousSelection = model.selectedBookmarknotID
  model.beginGeneration()
  for decision in try #require(model.generationSession).decisions {
    model.resolveDecision(decision.id, as: .accepted, recursively: decision.kind == .folder)
  }

  model.completeGeneration()

  #expect(model.generationSession == nil)
  #expect(model.bookmarknotArtifacts == previousArtifacts)
  #expect(model.selectedBookmarknotID == previousSelection)
  #expect(model.dialog == .generationAborted)
  #expect(model.runtimeLogContent.contains("Generation failed: cannotSaveArtifact"))
}

private enum SaveFailureError: Error {
  case cannotSaveArtifact
}

private final class SaveFailureServices: BookmarknotServices {
  private let canonicalizer = ArtifactCanonicalizer { _ in "identity" }
  private let runtimeLogSubject = PassthroughSubject<String, Never>()
  private var runtimeLogContent = ""
  private var saved: [SavedArtifact] = []
  var saveError: Error?

  var runtimeLogUpdates: AnyPublisher<String, Never> {
    runtimeLogSubject.eraseToAnyPublisher()
  }

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

  func refreshSavedArtifacts() throws -> [SavedArtifact] { saved }

  func canonicalize(_ root: BookmarkNode) throws -> CanonicalArtifact {
    try canonicalizer.canonicalize(root)
  }

  func save(_ artifact: CanonicalArtifact) throws -> ArtifactSaveOutcome {
    if let saveError { throw saveError }
    let result = SavedArtifact(
      hash: "hash",
      createdAt: Date(),
      bookmarkCount: artifact.bookmarkCount,
      folderCount: artifact.folderCount,
      fileSize: Int64(artifact.data.count),
      artifact: artifact
    )
    saved = [result]
    return .created(result)
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
