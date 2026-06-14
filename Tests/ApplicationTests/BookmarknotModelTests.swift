import Combine
import Domain
import Foundation
import Testing

@testable import Application

@MainActor
@Test
func runtimeLogUpdatesAppearWithoutRefreshing() {
  let services = FakeServices()
  let model = BookmarknotModel(services: services)

  services.emitRuntimeLogUpdate("[2026-06-11T00:00:00Z] [ERROR] A new runtime failure\n")

  #expect(model.runtimeLogContent == "[2026-06-11T00:00:00Z] [ERROR] A new runtime failure\n")
}

@MainActor
@Test
func runtimeLogCleanFailureStaysInTheLogWithoutShowingADialog() {
  let services = FakeServices()
  services.cleanRuntimeLogError = FakeError.cannotCleanRuntimeLog
  let model = BookmarknotModel(services: services)

  model.cleanRuntimeLog()

  #expect(model.runtimeLogContent.contains("Runtime log clean failed"))
  #expect(model.dialog == nil)
}

@MainActor
@Test
func bookmarknotRefreshLogsANormalActivityInfoEntry() {
  let services = FakeServices()
  let model = BookmarknotModel(services: services)

  model.refresh(.bookmarknot)

  #expect(
    services.loggedEntries.contains {
      $0.level == .info && $0.message == "Completed Bookmarknot refresh with 0 rows."
    })
}

@MainActor
@Test
func generationAbortLogsAnInfoEntry() {
  let services = FakeServices()
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.bookmarknot)

  model.beginGeneration()
  model.cancelGeneration()
  model.cancelGeneration()

  #expect(
    services.loggedEntries.contains {
      $0.level == .info && $0.message == "Started generation."
    })
  #expect(
    services.loggedEntries.filter {
      $0.level == .info && $0.message == "Aborted generation."
    }.count == 1)
}

@MainActor
@Test
func generationCreatedRouteLogsStartAndCompletion() throws {
  let services = FakeServices()
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.bookmarknot)

  model.beginGeneration()
  for decision in try #require(model.generationSession).decisions {
    model.resolveDecision(decision.id, as: .accepted, recursively: decision.kind == .folder)
  }
  model.completeGeneration()

  #expect(
    services.loggedEntries.contains {
      $0.level == .info && $0.message == "Started generation."
    })
  #expect(
    services.loggedEntries.contains {
      $0.level == .info && $0.message == "Completed generation with artifact hash."
    })
}

@MainActor
@Test
func generationExistingRouteLogsTheMatchOutcome() throws {
  let services = FakeServices()
  services.saveAsExisting = true
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.bookmarknot)

  model.beginGeneration()
  for decision in try #require(model.generationSession).decisions {
    model.resolveDecision(decision.id, as: .accepted, recursively: decision.kind == .folder)
  }
  model.completeGeneration()

  #expect(
    services.loggedEntries.contains {
      $0.level == .info && $0.message == "Generation matched existing artifact hash."
    })
}

@MainActor
@Test
func generationFailureRouteLogsAnError() {
  let services = FakeServices()
  services.sourceArtifactFactory = {
    SourceArtifact(
      id: "broken",
      browser: .chrome,
      path: "/Chrome/Bookmarks",
      createdAt: Date(),
      bookmarkCount: 0,
      folderCount: 0,
      fileSize: 1,
      status: .ready,
      artifact: try ArtifactCanonicalizer { _ in "identity" }.canonicalize(
        .folder(title: "", children: [])
      )
    )
  }
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.bookmarknot)

  model.beginGeneration()

  #expect(model.dialog == .generationAborted)
  #expect(
    services.loggedEntries.contains {
      $0.level == .error
        && $0.message == "Generation failed: selected sources contain no supported bookmarks."
    })
}

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
  #expect(model.dialog == nil)
}

@MainActor
@Test
func generationUsesOnlyTheSelectedChromeSource() throws {
  let services = FakeServices()
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.bookmarknot)

  model.beginGeneration()

  let session = try #require(model.generationSession)
  #expect(session.current == nil)
  #expect(session.incoming != nil)
  #expect(session.decisions.count == 1)
  #expect(session.decisions.first?.side == .incoming)
  #expect(session.decisions.first?.title == "Example")
  #expect(!session.isResolved)

  session.decisions.first.map { model.resolveDecision($0.id, as: .accepted, recursively: false) }
  #expect(model.generationSession?.isResolved == true)
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
func failedBookmarknotRefreshClearsStaleArtifactsAndDisablesGeneration() throws {
  let services = FakeServices()
  let seededArtifact = try services.canonicalize(
    .folder(title: "", children: [.leaf(title: "Example", url: "https://example.com")])
  )
  services.setSavedArtifacts([
    SavedArtifact(
      hash: "hash",
      createdAt: Date(),
      bookmarkCount: 1,
      folderCount: 0,
      fileSize: Int64(seededArtifact.data.count),
      artifact: seededArtifact
    )
  ])
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.bookmarknot)
  #expect(model.canGenerate)

  services.failSavedArtifactRefresh(with: FakeError.cannotRefreshSavedArtifacts)
  model.refresh(.bookmarknot)

  #expect(model.bookmarknotArtifacts.isEmpty)
  #expect(model.selectedBookmarknotID == nil)
  #expect(!model.canGenerate)
  #expect(model.dialog == .cannotLoad)
  #expect(
    services.loggedEntries.contains {
      $0.level == .error
        && $0.message == "Bookmarknot refresh failed: cannotRefreshSavedArtifacts"
    })
  #expect(
    model.runtimeLogContent.contains("Bookmarknot refresh failed: cannotRefreshSavedArtifacts"))
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
  case cannotCleanRuntimeLog
  case cannotRefreshSavedArtifacts
}

final class FakeServices: BookmarknotServices {
  struct LoggedEntry: Equatable {
    let level: RuntimeLogLevel
    let message: String
  }

  private let canonicalizer = ArtifactCanonicalizer { _ in "identity" }
  private let runtimeLogSubject = PassthroughSubject<String, Never>()
  private var runtimeLogContent = ""
  private var saved: [SavedArtifact] = []
  private var savedArtifactRefreshError: Error?
  var sourceArtifactFactory: (() throws -> SourceArtifact)?
  var failSavedArtifactRefreshAfterSave = false
  var saveAsExisting = false
  var cleanRuntimeLogError: Error?
  var saveCallCount = 0
  var loggedEntries: [LoggedEntry] = []

  var runtimeLogUpdates: AnyPublisher<String, Never> {
    runtimeLogSubject.eraseToAnyPublisher()
  }

  func emitRuntimeLogUpdate(_ content: String) {
    runtimeLogContent = content
    runtimeLogSubject.send(content)
  }

  func setSavedArtifacts(_ artifacts: [SavedArtifact]) {
    saved = artifacts
  }

  func failSavedArtifactRefresh(with error: Error) {
    savedArtifactRefreshError = error
  }

  func refreshSource(_ browser: BrowserKind) throws -> [SourceArtifact] {
    if let sourceArtifactFactory {
      return [try sourceArtifactFactory()]
    }
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
    saveCallCount += 1
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

  func runtimeLog() -> String { runtimeLogContent }
  func cleanRuntimeLog() throws {
    if let cleanRuntimeLogError { throw cleanRuntimeLogError }
    emitRuntimeLogUpdate("")
  }

  func log(_ level: RuntimeLogLevel, _ message: String) {
    loggedEntries.append(LoggedEntry(level: level, message: message))
    emitRuntimeLogUpdate(runtimeLogContent + "[\(level.rawValue)] " + message + "\n")
  }
}
