import Application
import Domain
import Foundation
import Testing

@testable import Infrastructure

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

  func writeInvalidChromeBookmarks() throws {
    let bookmarks = paths.chromeRoot.appending(path: "Default/Bookmarks")
    try Data("not valid JSON".utf8).write(to: bookmarks, options: [.atomic])
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
}
