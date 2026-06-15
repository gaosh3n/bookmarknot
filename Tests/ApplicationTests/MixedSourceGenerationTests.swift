import Application
import Combine
import Domain
import Foundation
import Testing

@MainActor
@Test
func mixedSourceGenerationSessionStaysFrozenAfterBothSourcesRefreshAgain() throws {
  let services = MixedSourceGenerationServices()
  services.chromeRows = [try services.makeReadyRow(browser: .chrome, root: oldChromeRoot())]
  services.safariRows = [try services.makeReadyRow(browser: .safari, root: oldSafariRoot())]
  let model = BookmarknotModel(services: services)
  refreshForMixedSourceGeneration(model)
  model.beginGeneration()

  let initialDecisions = try #require(model.generationSession?.decisions)

  services.chromeRows = [try services.makeReadyRow(browser: .chrome, root: newChromeRoot())]
  services.safariRows = [try services.makeReadyRow(browser: .safari, root: newSafariRoot())]
  model.refresh(.chrome)
  model.refresh(.safari)

  #expect(model.generationSession?.decisions == initialDecisions)
}

@MainActor
@Test
func mixedSourceGenerationSavesResolvedOneSidedItemsInDeterministicOrder() throws {
  let services = MixedSourceGenerationServices()
  services.chromeRows = [
    try services.makeReadyRow(browser: .chrome, root: incomingMixedSourceRoot())
  ]
  services.safariRows = [
    try services.makeReadyRow(browser: .safari, root: currentMixedSourceRoot())
  ]
  let model = BookmarknotModel(services: services)
  refreshForMixedSourceGeneration(model)

  #expect(model.canGenerate)
  model.beginGeneration()

  let decisions = try #require(model.generationSession?.decisions)
  #expect(decisions.map(\.title) == mixedSourceDecisionTitles())
  try resolveMixedSourceDecisions(in: model, decisions: decisions)

  #expect(model.generationSession?.isResolved == true)
  #expect(model.generationSession?.resolvedCount == model.generationSession?.totalCount)
  model.completeGeneration()

  let canonicalizedInput = try #require(services.lastCanonicalizedRoot)
  #expect(canonicalizedInput == resolvedMixedSourceRoot())

  let savedRoot = try #require(services.lastSavedArtifact?.root.bookmarkNode)
  let expectedSavedRoot = try services.canonicalizedRoot(for: resolvedMixedSourceRoot())
  #expect(savedRoot == expectedSavedRoot)
  #expect(model.selectedBookmarknotID == model.bookmarknotArtifacts.first?.id)
}

@MainActor
@Test
func mixedSourceGenerationTracksHiddenProgressAndCancelsWithoutSaving() throws {
  let services = MixedSourceGenerationServices()
  services.chromeRows = [
    try services.makeReadyRow(browser: .chrome, root: incomingMixedSourceRoot())
  ]
  services.safariRows = [
    try services.makeReadyRow(browser: .safari, root: currentMixedSourceRoot())
  ]
  let model = BookmarknotModel(services: services)
  refreshForMixedSourceGeneration(model)
  model.beginGeneration()

  let decisions = try #require(model.generationSession?.decisions)
  let currentFolder = try #require(decisions.first(where: { $0.title == "Current Folder" }))
  let incomingLeaf = try #require(decisions.first(where: { $0.title == "Incoming Leaf" }))

  model.resolveDecision(currentFolder.id, as: .accepted, recursively: true)
  #expect(model.generationSession?.resolvedCount == 2)
  #expect(model.generationSession?.totalCount == 6)

  model.resolveDecision(incomingLeaf.id, as: .accepted, recursively: false)
  #expect(model.generationSession?.resolvedCount == 3)

  model.cancelGeneration()

  #expect(model.generationSession == nil)
  #expect(model.bookmarknotArtifacts.isEmpty)
  #expect(services.saveCallCount == 0)
}

@MainActor
@Test
func mixedSourceGenerationShowsTheNoChangeOutcomeForAnExistingArtifact() throws {
  let services = MixedSourceGenerationServices()
  services.chromeRows = [
    try services.makeReadyRow(browser: .chrome, root: incomingMixedSourceRoot())
  ]
  services.safariRows = [
    try services.makeReadyRow(browser: .safari, root: currentMixedSourceRoot())
  ]
  let existingArtifact = try services.canonicalize(resolvedMixedSourceRoot())
  let existing = SavedArtifact(
    hash: "existing",
    createdAt: Date(timeIntervalSince1970: 1),
    bookmarkCount: existingArtifact.bookmarkCount,
    folderCount: existingArtifact.folderCount,
    fileSize: Int64(existingArtifact.data.count),
    artifact: existingArtifact
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
  services.savedArtifacts = [newer, existing]
  services.saveOutcome = .existing(existing)
  let model = BookmarknotModel(services: services)
  refreshForMixedSourceGeneration(model)
  model.beginGeneration()

  let decisions = try #require(model.generationSession?.decisions)
  try resolveMixedSourceDecisions(in: model, decisions: decisions)
  model.completeGeneration()

  #expect(model.generationSession == nil)
  #expect(model.dialog == .noChange)
  #expect(model.selectedBookmarknotID == existing.id)
  #expect(model.bookmarknotArtifacts.map(\.id) == [newer.id, existing.id])
}

@MainActor
@Test
func mixedSourceGenerationFailureAbortsAndKeepsTheLastValidSavedHistory() throws {
  let services = MixedSourceGenerationServices()
  services.chromeRows = [
    try services.makeReadyRow(browser: .chrome, root: incomingMixedSourceRoot())
  ]
  services.safariRows = [
    try services.makeReadyRow(browser: .safari, root: currentMixedSourceRoot())
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
  services.saveError = MixedSourceGenerationError.cannotSaveArtifact
  let model = BookmarknotModel(services: services)
  refreshForMixedSourceGeneration(model)
  let previousArtifacts = model.bookmarknotArtifacts
  let previousSelection = model.selectedBookmarknotID
  model.beginGeneration()

  let decisions = try #require(model.generationSession?.decisions)
  try resolveMixedSourceDecisions(in: model, decisions: decisions)
  model.completeGeneration()

  #expect(model.generationSession == nil)
  #expect(model.bookmarknotArtifacts == previousArtifacts)
  #expect(model.selectedBookmarknotID == previousSelection)
  #expect(model.dialog == .generationAborted)
  #expect(model.runtimeLogContent.contains("Generation failed: cannotSaveArtifact"))
}

private enum MixedSourceGenerationError: Error {
  case cannotSaveArtifact
}

@MainActor private func refreshForMixedSourceGeneration(_ model: BookmarknotModel) {
  model.refresh(.chrome)
  model.refresh(.safari)
  model.refresh(.bookmarknot)
}

@MainActor private func resolveMixedSourceDecisions(
  in model: BookmarknotModel,
  decisions: [DecisionOccurrence]
) throws {
  let currentFolder = try #require(decisions.first(where: { $0.title == "Current Folder" }))
  let currentLeaf = try #require(decisions.first(where: { $0.title == "Current Leaf" }))
  let incomingFolder = try #require(decisions.first(where: { $0.title == "Incoming Folder" }))
  let incomingLeaf = try #require(decisions.first(where: { $0.title == "Incoming Leaf" }))
  model.resolveDecision(currentFolder.id, as: .accepted, recursively: true)
  model.resolveDecision(currentLeaf.id, as: .rejected, recursively: false)
  model.resolveDecision(incomingFolder.id, as: .accepted, recursively: true)
  model.resolveDecision(incomingLeaf.id, as: .accepted, recursively: false)
}

private func mixedSourceDecisionTitles() -> [String] {
  [
    "Current Folder",
    "Current Child",
    "Current Leaf",
    "Incoming Folder",
    "Incoming Child",
    // swiftlint:disable:next trailing_comma
    "Incoming Leaf",
  ]
}

private func oldChromeRoot() -> BookmarkNode {
  .folder(title: "", children: [.leaf(title: "Chrome Old", url: "https://chrome-old.example")])
}

private func oldSafariRoot() -> BookmarkNode {
  .folder(title: "", children: [.leaf(title: "Safari Old", url: "https://safari-old.example")])
}

private func newChromeRoot() -> BookmarkNode {
  .folder(title: "", children: [.leaf(title: "Chrome New", url: "https://chrome-new.example")])
}

private func newSafariRoot() -> BookmarkNode {
  .folder(title: "", children: [.leaf(title: "Safari New", url: "https://safari-new.example")])
}

private func currentMixedSourceRoot() -> BookmarkNode {
  .folder(
    title: "",
    children: [
      .leaf(title: "Shared", url: "https://shared.example"),
      .folder(
        title: "Current Folder",
        children: [.leaf(title: "Current Child", url: "https://current-child.example")]
      ),
      // swiftlint:disable:next trailing_comma
      .leaf(title: "Current Leaf", url: "https://current-leaf.example"),
    ])
}

private func incomingMixedSourceRoot() -> BookmarkNode {
  .folder(
    title: "",
    children: [
      .leaf(title: "Shared", url: "https://shared.example"),
      .folder(
        title: "Incoming Folder",
        children: [.leaf(title: "Incoming Child", url: "https://incoming-child.example")]
      ),
      // swiftlint:disable:next trailing_comma
      .leaf(title: "Incoming Leaf", url: "https://incoming-leaf.example"),
    ])
}

private func resolvedMixedSourceRoot() -> BookmarkNode {
  .folder(
    title: "",
    children: [
      .folder(
        title: "Current Folder",
        children: [.leaf(title: "Current Child", url: "https://current-child.example")]
      ),
      .leaf(title: "Shared", url: "https://shared.example"),
      .folder(
        title: "Incoming Folder",
        children: [.leaf(title: "Incoming Child", url: "https://incoming-child.example")]
      ),
      // swiftlint:disable:next trailing_comma
      .leaf(title: "Incoming Leaf", url: "https://incoming-leaf.example"),
    ])
}

private final class MixedSourceGenerationServices: BookmarknotServices {
  private let canonicalizer = ArtifactCanonicalizer { _ in "identity" }
  private let runtimeLogSubject = PassthroughSubject<String, Never>()
  private var runtimeLogContent = ""

  var chromeRows: [SourceArtifact] = []
  var safariRows: [SourceArtifact] = []
  var savedArtifacts: [SavedArtifact] = []
  var lastCanonicalizedRoot: BookmarkNode?
  var lastSavedArtifact: CanonicalArtifact?
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

  func refreshSource(_ browser: BrowserKind) throws -> [SourceArtifact] {
    switch browser {
    case .chrome: chromeRows
    case .safari: safariRows
    }
  }

  func refreshSavedArtifacts() throws -> [SavedArtifact] {
    savedArtifacts
  }

  func canonicalize(_ root: BookmarkNode) throws -> CanonicalArtifact {
    lastCanonicalizedRoot = root
    return try canonicalizer.canonicalize(root)
  }

  func canonicalizedRoot(for root: BookmarkNode) throws -> BookmarkNode {
    try canonicalizer.canonicalize(root).root.bookmarkNode
  }

  func save(_ artifact: CanonicalArtifact) throws -> ArtifactSaveOutcome {
    saveCallCount += 1
    if let saveError { throw saveError }
    lastSavedArtifact = artifact
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
