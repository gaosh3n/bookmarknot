import Application
import Combine
import CryptoKit
import Domain
import Foundation
import Testing

@testable import Infrastructure

@Test
func appendingRuntimeLogPublishesTheVisibleContentWithALevel() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  let services = InfrastructureServices(paths: fixture.paths)
  var updates: [String] = []
  let observation = services.runtimeLogUpdates.sink { updates.append($0) }
  defer { observation.cancel() }

  services.log(.info, "Started Chrome refresh.")

  #expect(updates.count == 1)
  #expect(updates[0].contains("[INFO] Started Chrome refresh."))
  #expect(updates[0] == services.runtimeLog())
}

@Test
func cleaningRuntimeLogPublishesEmptyContentAndRetainsTheFile() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  let services = InfrastructureServices(paths: fixture.paths)
  services.log(.warning, "Failure to remove")
  let originalHandle = try FileHandle(forReadingFrom: fixture.runtimeLogFile)
  defer { try? originalHandle.close() }
  let originalIdentifier = try fixture.fileResourceIdentifier(for: fixture.runtimeLogFile)
  var updates: [String] = []
  let observation = services.runtimeLogUpdates.sink { updates.append($0) }
  defer { observation.cancel() }

  try services.cleanRuntimeLog()

  #expect(updates == [""])
  #expect(services.runtimeLog().isEmpty)
  #expect(try fixture.fileResourceIdentifier(for: fixture.runtimeLogFile) == originalIdentifier)
  #expect(try originalHandle.seekToEnd() == 0)
  #expect(FileManager.default.fileExists(atPath: fixture.runtimeLogFile.path))
}

@Test
func unavailableRuntimeLogStorageIsHandledWithoutCrashingOrPublishingFalseContent() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  try fixture.blockApplicationSupportDirectory()
  let services = InfrastructureServices(paths: fixture.paths)
  var updates: [String] = []
  let observation = services.runtimeLogUpdates.sink { updates.append($0) }
  defer { observation.cancel() }

  #expect(services.runtimeLog().isEmpty)
  services.log(.error, "Cannot be written")
  #expect(updates.isEmpty)
  do {
    try services.cleanRuntimeLog()
    Issue.record("Expected cleaning unavailable runtime-log storage to fail")
  } catch {}
}

@Test
func chromeRefreshWritesConvertedCacheAndSavedArtifactsAreContentAddressed() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  try fixture.writeChromeBookmarks()
  let services = InfrastructureServices(paths: fixture.paths)

  let rows = try services.refreshSource(.chrome)
  #expect(rows.count == 1)
  #expect(rows[0].bookmarkCount == 1)
  #expect(FileManager.default.fileExists(atPath: fixture.cacheIndex.path))

  let artifact = try #require(rows[0].artifact)
  let first = try services.save(artifact)
  let second = try services.save(artifact)
  guard case .created(let created) = first, case .existing(let existing) = second else {
    Issue.record("Expected created then existing save outcomes")
    return
  }
  #expect(created.hash == existing.hash)
  #expect(try services.refreshSavedArtifacts().map(\.hash) == [created.hash])
}

@Test
func nonArtifactEntriesInvalidateTheSavedArtifactDirectory() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  let directory = fixture.paths.applicationSupport.appending(path: "artifacts")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  try Data("not an artifact".utf8).write(to: directory.appending(path: "notes.txt"))
  let services = InfrastructureServices(paths: fixture.paths)

  #expect(throws: InfrastructureError.self) {
    try services.refreshSavedArtifacts()
  }
}

@Test
func malformedSavedArtifactsInvalidateTheSavedArtifactDirectory() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  try fixture.writeSavedArtifact(named: Data("not json".utf8))
  let services = InfrastructureServices(paths: fixture.paths)

  #expect(throws: ArtifactError.self) {
    try services.refreshSavedArtifacts()
  }
}

@Test
func hashMismatchesInvalidateTheSavedArtifactDirectory() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  let services = InfrastructureServices(paths: fixture.paths)
  let artifact = try services.canonicalize(
    .folder(title: "", children: [.leaf(title: "Example", url: "https://example.com")])
  )
  try fixture.writeSavedArtifact(
    data: artifact.data, filenameHash: String(repeating: "0", count: 64))

  #expect(throws: InfrastructureError.self) {
    try services.refreshSavedArtifacts()
  }
}

@Test
func nonCanonicalSavedArtifactsInvalidateTheSavedArtifactDirectory() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  let services = InfrastructureServices(paths: fixture.paths)
  let artifact = try services.canonicalize(
    .folder(title: "", children: [.leaf(title: "Example", url: "https://example.com")])
  )
  let nonCanonical = artifact.data.replacing(
    Data("\n".utf8),
    with: Data(),
    maxReplacements: 1
  )
  try fixture.writeSavedArtifact(named: nonCanonical)

  #expect(throws: ArtifactError.self) {
    try services.refreshSavedArtifacts()
  }
}

@Test
func subdirectoriesInvalidateTheSavedArtifactDirectory() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  let directory = fixture.paths.applicationSupport.appending(path: "artifacts")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  try FileManager.default.createDirectory(
    at: directory.appending(path: "nested"),
    withIntermediateDirectories: true
  )
  let services = InfrastructureServices(paths: fixture.paths)

  #expect(throws: InfrastructureError.self) {
    try services.refreshSavedArtifacts()
  }
}

@Test
func missingSavedArtifactDirectoryIsCreatedAsAnEmptyValidState() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  let services = InfrastructureServices(paths: fixture.paths)
  let directory = fixture.paths.applicationSupport.appending(path: "artifacts")

  let artifacts = try services.refreshSavedArtifacts()

  #expect(artifacts.isEmpty)
  #expect(FileManager.default.fileExists(atPath: directory.path))
}

@Test
func safariRefreshExcludesSystemAreasAndProxyNodes() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  try fixture.writeSafariBookmarks()
  let services = InfrastructureServices(paths: fixture.paths)

  let rows = try services.refreshSource(.safari)

  #expect(rows.count == 1)
  #expect(rows[0].bookmarkCount == 1)
  #expect(rows[0].folderCount == 1)
}

@Test
func safariRefreshFailsWhenLeafTitleIsMissing() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  try fixture.writeSafariBookmarksWithoutLeafTitle()
  let services = InfrastructureServices(paths: fixture.paths)

  #expect(throws: InfrastructureError.self) {
    try services.refreshSource(.safari)
  }
}

@Test
func allFailedRefreshReplacesThePreviousConvertedCache() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  try fixture.writeChromeBookmarks()
  let services = InfrastructureServices(paths: fixture.paths)

  _ = try services.refreshSource(.chrome)
  #expect(FileManager.default.fileExists(atPath: fixture.cachedArtifact.path))

  try fixture.writeInvalidChromeBookmarks()
  #expect(throws: InfrastructureError.self) {
    try services.refreshSource(.chrome)
  }

  #expect(FileManager.default.fileExists(atPath: fixture.cacheIndex.path))
  #expect(!FileManager.default.fileExists(atPath: fixture.cachedArtifact.path))
  let index = try fixture.readChromeIndex()
  #expect(index.rows.isEmpty)
}

@Test
func sourceRowsUseFilesystemCreationTime() throws {
  let fixture = try Fixture()
  defer { fixture.clean() }
  try fixture.writeSafariBookmarks()
  let futureModificationDate = Date(timeIntervalSince1970: 2_000_000_000)
  try FileManager.default.setAttributes(
    [.modificationDate: futureModificationDate],
    ofItemAtPath: fixture.paths.safariBookmarks.path
  )
  let creationDate = try #require(
    fixture.paths.safariBookmarks.resourceValues(forKeys: [.creationDateKey]).creationDate
  )
  let services = InfrastructureServices(paths: fixture.paths)

  let rows = try services.refreshSource(.safari)

  #expect(rows[0].createdAt == creationDate)
  #expect(rows[0].createdAt != futureModificationDate)
}

private struct Fixture {
  let root: URL
  let paths: InfrastructurePaths

  init() throws {
    root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    paths = InfrastructurePaths(
      chromeRoot: root.appending(path: "Chrome"),
      safariBookmarks: root.appending(path: "Safari/Bookmarks.plist"),
      applicationSupport: root.appending(path: "Bookmarknot")
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  var cacheIndex: URL {
    paths.applicationSupport.appending(path: "sources/Chrome/index.json")
  }

  var cachedArtifact: URL {
    paths.applicationSupport.appending(path: "sources/Chrome/artifact-0.json")
  }

  var runtimeLogFile: URL {
    paths.applicationSupport.appending(path: "logs/runtime.log")
  }

  func writeChromeBookmarks() throws {
    let profile = paths.chromeRoot.appending(path: "Default")
    try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
    let json = """
      {
        "roots": {
          "bookmark_bar": {
            "children": [
              {"type": "url", "name": "Example", "url": "https://example.com"}
            ]
          },
          "other": {"children": [{"type": "url", "name": "Ignored", "url": "https://ignored.example"}]}
        }
      }
      """
    try Data(json.utf8).write(to: profile.appending(path: "Bookmarks"))
  }

  func blockApplicationSupportDirectory() throws {
    try Data("not a directory".utf8).write(to: paths.applicationSupport)
  }

  func fileResourceIdentifier(for url: URL) throws -> Data {
    let identifier = try #require(
      url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? Data
    )
    return identifier
  }

  func writeInvalidChromeBookmarks() throws {
    let bookmarks = paths.chromeRoot.appending(path: "Default/Bookmarks")
    try Data("not valid JSON".utf8).write(to: bookmarks, options: [.atomic])
  }

  func readChromeIndex() throws -> TestSourceIndex {
    let data = try Data(contentsOf: cacheIndex)
    return try JSONDecoder().decode(TestSourceIndex.self, from: data)
  }

  func writeSavedArtifact(named data: Data) throws {
    try writeSavedArtifact(data: data, filenameHash: sha256(data))
  }

  func writeSavedArtifact(data: Data, filenameHash: String) throws {
    let directory = paths.applicationSupport.appending(path: "artifacts")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: directory.appending(path: "\(filenameHash).json"), options: [.atomic])
  }

  // swiftlint:disable trailing_comma
  func writeSafariBookmarks() throws {
    let parent = paths.safariBookmarks.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    let plist: [String: Any] = [
      "Children": [
        [
          "WebBookmarkType": "WebBookmarkTypeList",
          "Title": "BookmarksBar",
          "Children": [],
        ],
        [
          "WebBookmarkType": "WebBookmarkTypeProxy",
          "Title": "History",
        ],
        [
          "WebBookmarkType": "WebBookmarkTypeList",
          "Title": "Keep",
          "Children": [
            [
              "WebBookmarkType": "WebBookmarkTypeLeaf",
              "URLString": "https://example.com",
              "URIDictionary": ["title": "Example"],
            ]
          ],
        ],
      ]
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: plist, format: .binary, options: 0)
    try data.write(to: paths.safariBookmarks)
  }

  func writeSafariBookmarksWithoutLeafTitle() throws {
    let parent = paths.safariBookmarks.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    let plist: [String: Any] = [
      "Children": [
        [
          "WebBookmarkType": "WebBookmarkTypeLeaf",
          "URLString": "https://example.com",
          "URIDictionary": [:],
        ]
      ]
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: plist, format: .binary, options: 0)
    try data.write(to: paths.safariBookmarks)
  }
  // swiftlint:enable trailing_comma

  func clean() {
    try? FileManager.default.removeItem(at: root)
  }

  private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}

private struct TestSourceIndex: Decodable {
  let rows: [TestSourceIndexRow]
}

private struct TestSourceIndexRow: Decodable {
  let id: String
}
