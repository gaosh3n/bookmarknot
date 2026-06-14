import Application
import Combine
import Domain
import Foundation
import Testing

@MainActor
@Test
func safariOnlyGenerationUsesSafariWhenChromeSelectionIsNotUsable() throws {
  let services = SafariOnlyGenerationServices()
  services.chromeRows = [services.makeFailedChromeRow()]
  services.safariRows = [
    try services.makeReadyRow(
      browser: .safari,
      root: .folder(
        title: "",
        children: [
          .leaf(title: "Safari", url: "https://safari.example")
        ]))
  ]
  let model = BookmarknotModel(services: services)

  model.refresh(.chrome)
  model.refresh(.safari)
  #expect(!model.canGenerate)

  model.refresh(.bookmarknot)
  #expect(model.canGenerate)

  model.beginGeneration()

  let session = try #require(model.generationSession)
  #expect(session.current == nil)
  #expect(session.incoming == model.safariArtifacts.first?.artifact?.root.bookmarkNode)
  #expect(session.decisions.map(\.side) == [.incoming])
  #expect(session.decisions.map(\.title) == ["Safari"])
}

@MainActor
@Test
func safariOnlyGenerationSessionStaysFrozenAfterSafariRefreshesAgain() throws {
  let services = SafariOnlyGenerationServices()
  services.safariRows = [
    try services.makeReadyRow(
      browser: .safari,
      root: .folder(
        title: "",
        children: [
          .leaf(title: "Old", url: "https://old.example")
        ]))
  ]
  let model = BookmarknotModel(services: services)
  model.refresh(.safari)
  model.refresh(.bookmarknot)
  model.beginGeneration()

  let initialTitle = try #require(model.generationSession?.decisions.first?.title)

  services.safariRows = [
    try services.makeReadyRow(
      browser: .safari,
      root: .folder(
        title: "",
        children: [
          .leaf(title: "New", url: "https://new.example")
        ]))
  ]
  model.refresh(.safari)

  #expect(try #require(model.generationSession?.decisions.first?.title) == initialTitle)
}

@MainActor
@Test
func safariOnlyGenerationSavesTheCreatedArtifactAndSelectsIt() throws {
  let services = SafariOnlyGenerationServices()
  services.safariRows = [
    try services.makeReadyRow(
      browser: .safari,
      root: .folder(
        title: "",
        children: [
          .folder(
            title: "Folder",
            children: [
              .leaf(title: "Leaf", url: "https://leaf.example")
            ])
        ]))
  ]
  let model = BookmarknotModel(services: services)
  model.refresh(.safari)
  model.refresh(.bookmarknot)
  model.beginGeneration()

  for decision in try #require(model.generationSession).decisions {
    model.resolveDecision(decision.id, as: .accepted, recursively: decision.kind == .folder)
  }
  model.completeGeneration()

  #expect(model.generationSession == nil)
  #expect(model.bookmarknotArtifacts.count == 1)
  #expect(model.selectedBookmarknotID == model.bookmarknotArtifacts.first?.id)
  #expect(model.dialog == nil)
}

@MainActor
@Test
func safariOnlyGenerationShowsTheNoChangeOutcomeForAnExistingArtifact() throws {
  let services = SafariOnlyGenerationServices()
  let root = BookmarkNode.folder(
    title: "",
    children: [
      .leaf(title: "Safari", url: "https://safari.example")
    ])
  let selectedArtifact = try services.canonicalize(root)
  let existing = SavedArtifact(
    hash: "existing",
    createdAt: Date(timeIntervalSince1970: 1),
    bookmarkCount: selectedArtifact.bookmarkCount,
    folderCount: selectedArtifact.folderCount,
    fileSize: Int64(selectedArtifact.data.count),
    artifact: selectedArtifact
  )
  let newerArtifact = try services.canonicalize(
    .folder(title: "", children: [.leaf(title: "Newer", url: "https://newer.example")])
  )
  let newer = SavedArtifact(
    hash: "newer",
    createdAt: Date(timeIntervalSince1970: 2),
    bookmarkCount: newerArtifact.bookmarkCount,
    folderCount: newerArtifact.folderCount,
    fileSize: Int64(newerArtifact.data.count),
    artifact: newerArtifact
  )
  services.safariRows = [
    try services.makeReadyRow(browser: .safari, root: root)
  ]
  services.savedArtifacts = [newer, existing]
  services.saveOutcome = .existing(existing)
  let model = BookmarknotModel(services: services)
  model.refresh(.safari)
  model.refresh(.bookmarknot)
  model.beginGeneration()

  for decision in try #require(model.generationSession).decisions {
    model.resolveDecision(decision.id, as: .accepted, recursively: decision.kind == .folder)
  }
  model.completeGeneration()

  #expect(model.generationSession == nil)
  #expect(model.dialog == .noChange)
  #expect(model.selectedBookmarknotID == existing.id)
  #expect(model.bookmarknotArtifacts.map(\.id) == [newer.id, existing.id])
}

@MainActor
@Test
func safariOnlyGenerationCanBeCancelledWithoutSaving() throws {
  let services = SafariOnlyGenerationServices()
  services.safariRows = [
    try services.makeReadyRow(
      browser: .safari,
      root: .folder(
        title: "",
        children: [
          .leaf(title: "Safari", url: "https://safari.example")
        ]))
  ]
  let model = BookmarknotModel(services: services)
  model.refresh(.safari)
  model.refresh(.bookmarknot)
  model.beginGeneration()
  let decision = try #require(model.generationSession?.decisions.first)
  model.resolveDecision(decision.id, as: .accepted, recursively: false)

  model.cancelGeneration()

  #expect(model.generationSession == nil)
  #expect(model.bookmarknotArtifacts.isEmpty)
  #expect(services.saveCallCount == 0)
}

@MainActor
@Test
func safariOnlyGenerationFailureAbortsAndKeepsTheLastValidSavedHistory() throws {
  let services = SafariOnlyGenerationServices()
  services.safariRows = [
    try services.makeReadyRow(
      browser: .safari,
      root: .folder(
        title: "",
        children: [
          .leaf(title: "Safari", url: "https://safari.example")
        ]))
  ]
  let existingArtifact = try services.canonicalize(
    .folder(title: "", children: [.leaf(title: "Existing", url: "https://existing.example")])
  )
  let existing = SavedArtifact(
    hash: "existing",
    createdAt: Date(timeIntervalSince1970: 1),
    bookmarkCount: existingArtifact.bookmarkCount,
    folderCount: existingArtifact.folderCount,
    fileSize: Int64(existingArtifact.data.count),
    artifact: existingArtifact
  )
  services.savedArtifacts = [existing]
  services.saveError = SafariOnlyGenerationError.cannotSaveArtifact
  let model = BookmarknotModel(services: services)
  model.refresh(.safari)
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

private enum SafariOnlyGenerationError: Error {
  case cannotSaveArtifact
}

private final class SafariOnlyGenerationServices: BookmarknotServices {
  private let canonicalizer = ArtifactCanonicalizer { _ in "identity" }
  private let runtimeLogSubject = PassthroughSubject<String, Never>()
  private var runtimeLogContent = ""

  var chromeRows: [SourceArtifact] = []
  var safariRows: [SourceArtifact] = []
  var savedArtifacts: [SavedArtifact] = []
  var saveOutcome: ArtifactSaveOutcome?
  var saveError: Error?
  var saveCallCount = 0

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

  func makeFailedChromeRow() -> SourceArtifact {
    SourceArtifact(
      id: "chrome-failed",
      browser: .chrome,
      path: "/Chrome/Bookmarks",
      createdAt: Date(),
      bookmarkCount: nil,
      folderCount: nil,
      fileSize: 1,
      status: .failed,
      artifact: nil,
      errorDescription: "bad chrome source"
    )
  }

  func refreshSource(_ browser: BrowserKind) throws -> [SourceArtifact] {
    switch browser {
    case .chrome: return chromeRows
    case .safari: return safariRows
    }
  }

  func refreshSavedArtifacts() throws -> [SavedArtifact] { savedArtifacts }

  func canonicalize(_ root: BookmarkNode) throws -> CanonicalArtifact {
    try canonicalizer.canonicalize(root)
  }

  func save(_ artifact: CanonicalArtifact) throws -> ArtifactSaveOutcome {
    saveCallCount += 1
    if let saveError { throw saveError }
    if let saveOutcome { return saveOutcome }
    let saved = SavedArtifact(
      hash: "hash",
      createdAt: Date(),
      bookmarkCount: artifact.bookmarkCount,
      folderCount: artifact.folderCount,
      fileSize: Int64(artifact.data.count),
      artifact: artifact
    )
    savedArtifacts = [saved]
    return .created(saved)
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
