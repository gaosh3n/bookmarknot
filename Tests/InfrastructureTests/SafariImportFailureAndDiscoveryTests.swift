import Foundation
import Testing

@testable import Infrastructure

@Test
func safariRefreshPreservesNonRootUserFoldersNamedLikeReadingList() throws {
  let fixture = try SafariFailureFixture()
  defer { fixture.clean() }
  try fixture.writeUserFolderNamedReadingListBookmarks()
  let services = InfrastructureServices(paths: fixture.paths)

  let rows = try services.refreshSource(.safari)

  #expect(rows.count == 1)
  let artifact = try #require(rows[0].artifact)
  #expect(
    artifact.root.bookmarkNode
      == .folder(
        title: "",
        children: [
          .folder(
            title: "Keep",
            children: [
              .folder(
                title: "com.apple.ReadingList",
                children: [.leaf(title: "Saved", url: "https://saved.example.com")]
              ),
              // swiftlint:disable:next trailing_comma
              .leaf(title: "Keep me", url: "https://kept.example.com"),
            ]
          )
        ]
      )
  )
}

@Test
func safariRefreshDiscoversOnlyTheNativeSafariBookmarksPlist() throws {
  let fixture = try SafariFailureFixture()
  defer { fixture.clean() }
  let services = InfrastructureServices(paths: fixture.paths)

  #expect(try services.refreshSource(.safari).isEmpty)

  try fixture.writeInitialCacheBookmarks()
  let rows = try services.refreshSource(.safari)

  #expect(rows.count == 1)
  #expect(rows[0].path == fixture.paths.safariBookmarks.path)
}

@Test
func safariRefreshFailsForUnknownSafariNodeTypes() throws {
  let fixture = try SafariFailureFixture()
  defer { fixture.clean() }
  try fixture.writeUnknownNodeBookmarks()
  let services = InfrastructureServices(paths: fixture.paths)

  #expect(throws: InfrastructureError.self) {
    try services.refreshSource(.safari)
  }
}

@Test
func safariRefreshFailsWhenTheRootChildrenFieldIsMissing() throws {
  let fixture = try SafariFailureFixture()
  defer { fixture.clean() }
  try fixture.writeSafariBookmarks(["Title": "No children"])
  let services = InfrastructureServices(paths: fixture.paths)

  #expect(throws: InfrastructureError.self) {
    try services.refreshSource(.safari)
  }
}

@Test
func safariRefreshFailsWhenLeafURLIsMissing() throws {
  let fixture = try SafariFailureFixture()
  defer { fixture.clean() }
  try fixture.writeLeafMissingURLBookmarks()
  let services = InfrastructureServices(paths: fixture.paths)

  #expect(throws: InfrastructureError.self) {
    try services.refreshSource(.safari)
  }
}

@Test
func safariRefreshFailsWhenAListNodeIsMissingRequiredFields() throws {
  let fixture = try SafariFailureFixture()
  defer { fixture.clean() }
  try fixture.writeListMissingChildrenBookmarks()
  let services = InfrastructureServices(paths: fixture.paths)

  #expect(throws: InfrastructureError.self) {
    try services.refreshSource(.safari)
  }
}

private struct SafariFailureFixture {
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

  func writeUserFolderNamedReadingListBookmarks() throws {
    let readingListLeaf: [String: Any] = [
      "WebBookmarkType": "WebBookmarkTypeLeaf",
      "URLString": "https://saved.example.com",
      // swiftlint:disable:next trailing_comma
      "URIDictionary": ["title": "Saved"],
    ]
    let keptLeaf: [String: Any] = [
      "WebBookmarkType": "WebBookmarkTypeLeaf",
      "URLString": "https://kept.example.com",
      // swiftlint:disable:next trailing_comma
      "URIDictionary": ["title": "Keep me"],
    ]
    let readingListFolder: [String: Any] = [
      "WebBookmarkType": "WebBookmarkTypeList",
      "Title": "com.apple.ReadingList",
      // swiftlint:disable:next trailing_comma
      "Children": [readingListLeaf],
    ]
    let keepFolder: [String: Any] = [
      "WebBookmarkType": "WebBookmarkTypeList",
      "Title": "Keep",
      // swiftlint:disable:next trailing_comma
      "Children": [readingListFolder, keptLeaf],
    ]
    try writeSafariBookmarks(["Children": [keepFolder]])
  }

  func writeInitialCacheBookmarks() throws {
    let leaf: [String: Any] = [
      "WebBookmarkType": "WebBookmarkTypeLeaf",
      "URLString": "https://first.example.com",
      // swiftlint:disable:next trailing_comma
      "URIDictionary": ["title": "First"],
    ]
    let firstFolder: [String: Any] = [
      "WebBookmarkType": "WebBookmarkTypeList",
      "Title": "First",
      // swiftlint:disable:next trailing_comma
      "Children": [leaf],
    ]
    try writeSafariBookmarks(["Children": [firstFolder]])
  }

  func writeUnknownNodeBookmarks() throws {
    let unknownNode: [String: Any] = [
      "WebBookmarkType": "WebBookmarkTypeMystery",
      // swiftlint:disable:next trailing_comma
      "Title": "Unknown",
    ]
    try writeSafariBookmarks(["Children": [unknownNode]])
  }

  func writeListMissingChildrenBookmarks() throws {
    let brokenList: [String: Any] = [
      "WebBookmarkType": "WebBookmarkTypeList",
      // swiftlint:disable:next trailing_comma
      "Title": "Broken",
    ]
    try writeSafariBookmarks(["Children": [brokenList]])
  }

  func writeLeafMissingURLBookmarks() throws {
    let brokenLeaf: [String: Any] = [
      "WebBookmarkType": "WebBookmarkTypeLeaf",
      // swiftlint:disable:next trailing_comma
      "URIDictionary": ["title": "Broken"],
    ]
    try writeSafariBookmarks(["Children": [brokenLeaf]])
  }

  func clean() {
    try? FileManager.default.removeItem(at: root)
  }

  fileprivate func writeSafariBookmarks(_ plist: [String: Any]) throws {
    let parent = paths.safariBookmarks.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    let data = try PropertyListSerialization.data(
      fromPropertyList: plist, format: .binary, options: 0)
    try data.write(to: paths.safariBookmarks)
  }
}
