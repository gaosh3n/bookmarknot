import Application
import Combine
import Domain
import Foundation
import Testing

@MainActor
@Test
func generationUsesTheSelectedSafariSourceWhenItIsTheOnlyAvailableSource() throws {
  let services = SafariGenerationServices()
  services.safariRows = [
    try services.makeRow(browser: .safari, title: "Safari", url: "https://safari.example")
  ]
  let model = BookmarknotModel(services: services)
  model.refresh(.safari)
  model.refresh(.bookmarknot)

  #expect(model.canGenerate)

  model.beginGeneration()

  let session = try #require(model.generationSession)
  #expect(session.current == nil)
  #expect(session.incoming != nil)
  #expect(session.decisions.map(\.title) == ["Safari"])
}

@MainActor
@Test
func generationUsesSafariAsCurrentAndChromeAsIncomingWhenBothAreAvailable() throws {
  let services = SafariGenerationServices()
  services.chromeRows = [
    try services.makeRow(browser: .chrome, title: "Chrome", url: "https://chrome.example")
  ]
  services.safariRows = [
    try services.makeRow(browser: .safari, title: "Safari", url: "https://safari.example")
  ]
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.safari)
  model.refresh(.bookmarknot)

  #expect(model.canGenerate)

  model.beginGeneration()

  let session = try #require(model.generationSession)
  #expect(session.current == model.safariArtifacts.first?.artifact?.root.bookmarkNode)
  #expect(session.incoming == model.chromeArtifacts.first?.artifact?.root.bookmarkNode)
  #expect(session.decisions.contains(where: { $0.side == .current }))
  #expect(session.decisions.contains(where: { $0.side == .incoming }))
}

private final class SafariGenerationServices: BookmarknotServices {
  private let canonicalizer = ArtifactCanonicalizer { _ in "identity" }
  private let runtimeLogSubject = PassthroughSubject<String, Never>()
  private var runtimeLogContent = ""

  var chromeRows: [SourceArtifact] = []
  var safariRows: [SourceArtifact] = []

  var runtimeLogUpdates: AnyPublisher<String, Never> {
    runtimeLogSubject.eraseToAnyPublisher()
  }

  func makeRow(browser: BrowserKind, title: String, url: String) throws -> SourceArtifact {
    let artifact = try canonicalizer.canonicalize(
      .folder(title: "", children: [.leaf(title: title, url: url)])
    )
    return SourceArtifact(
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
  }

  func refreshSource(_ browser: BrowserKind) throws -> [SourceArtifact] {
    switch browser {
    case .chrome: return chromeRows
    case .safari: return safariRows
    }
  }

  func refreshSavedArtifacts() throws -> [SavedArtifact] { [] }

  func canonicalize(_ root: BookmarkNode) throws -> CanonicalArtifact {
    try canonicalizer.canonicalize(root)
  }

  func save(_ artifact: CanonicalArtifact) throws -> ArtifactSaveOutcome {
    .created(
      SavedArtifact(
        hash: "hash",
        createdAt: Date(),
        bookmarkCount: artifact.bookmarkCount,
        folderCount: artifact.folderCount,
        fileSize: Int64(artifact.data.count),
        artifact: artifact
      )
    )
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
