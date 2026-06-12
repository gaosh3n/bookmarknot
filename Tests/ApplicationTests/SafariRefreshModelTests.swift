import Combine
import Domain
import Foundation
import Testing

@testable import Application

@MainActor
@Test
func safariRefreshSelectsTheNewestSuccessfulRow() throws {
  let services = SafariModelFakeServices()
  let readyArtifact = try services.canonicalize(
    .folder(title: "", children: [.leaf(title: "Example", url: "https://example.com")])
  )
  let failedRow = SourceArtifact(
    id: "failed",
    browser: .safari,
    path: "/Safari/Bookmarks.plist",
    createdAt: Date(timeIntervalSince1970: 2),
    bookmarkCount: nil,
    folderCount: nil,
    fileSize: 1,
    status: .failed,
    artifact: nil,
    errorDescription: "bad plist"
  )
  let readyRow = SourceArtifact(
    id: "ready",
    browser: .safari,
    path: "/Safari/Bookmarks.plist",
    createdAt: Date(timeIntervalSince1970: 1),
    bookmarkCount: 1,
    folderCount: 0,
    fileSize: 1,
    status: .ready,
    artifact: readyArtifact
  )
  services.safariRows = [failedRow, readyRow]
  let model = BookmarknotModel(services: services)

  model.refresh(.safari)

  #expect(model.safariState == .loaded)
  #expect(model.selectedSafariID == "ready")
  #expect(model.dialog == nil)
}

@MainActor
@Test
func failedSafariRefreshClearsRowsSelectionAndShowsLoadFailure() {
  let services = SafariModelFakeServices()
  services.safariRows = [
    SourceArtifact(
      id: "existing",
      browser: .safari,
      path: "/Safari/Bookmarks.plist",
      createdAt: Date(),
      bookmarkCount: nil,
      folderCount: nil,
      fileSize: 1,
      status: .failed,
      artifact: nil,
      errorDescription: "old failure"
    )
  ]
  let model = BookmarknotModel(services: services)
  model.refresh(.safari)
  services.safariRefreshError = SafariModelFakeError.cannotRefreshSafari

  model.refresh(.safari)

  #expect(model.safariArtifacts.isEmpty)
  #expect(model.selectedSafariID == nil)
  #expect(model.dialog == .cannotLoad)
  #expect(
    services.loggedEntries.contains {
      $0.level == .error && $0.message == "Safari refresh failed: cannotRefreshSafari"
    }
  )
}

private enum SafariModelFakeError: Error {
  case cannotRefreshSafari
}

private final class SafariModelFakeServices: BookmarknotServices {
  struct LoggedEntry: Equatable {
    let level: RuntimeLogLevel
    let message: String
  }

  private let canonicalizer = ArtifactCanonicalizer { _ in "identity" }
  private let runtimeLogSubject = PassthroughSubject<String, Never>()
  private var runtimeLogContent = ""

  var safariRows: [SourceArtifact] = []
  var safariRefreshError: Error?
  var loggedEntries: [LoggedEntry] = []

  var runtimeLogUpdates: AnyPublisher<String, Never> {
    runtimeLogSubject.eraseToAnyPublisher()
  }

  func refreshSource(_ browser: BrowserKind) throws -> [SourceArtifact] {
    switch browser {
    case .safari:
      if let safariRefreshError { throw safariRefreshError }
      return safariRows
    case .chrome:
      return []
    }
  }

  func refreshSavedArtifacts() throws -> [SavedArtifact] { [] }

  func canonicalize(_ root: BookmarkNode) throws -> CanonicalArtifact {
    try canonicalizer.canonicalize(root)
  }

  func save(_ artifact: CanonicalArtifact) throws -> ArtifactSaveOutcome {
    let saved = SavedArtifact(
      hash: "hash",
      createdAt: Date(),
      bookmarkCount: artifact.bookmarkCount,
      folderCount: artifact.folderCount,
      fileSize: Int64(artifact.data.count),
      artifact: artifact
    )
    return .created(saved)
  }

  func runtimeLog() -> String { runtimeLogContent }

  func cleanRuntimeLog() throws {
    runtimeLogContent = ""
    runtimeLogSubject.send("")
  }

  func log(_ level: RuntimeLogLevel, _ message: String) {
    loggedEntries.append(LoggedEntry(level: level, message: message))
    runtimeLogContent += "[\(level.rawValue)] \(message)\n"
    runtimeLogSubject.send(runtimeLogContent)
  }
}
