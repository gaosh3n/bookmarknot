import Foundation
import Testing

@testable import Infrastructure

@Test
func safariRefreshExcludesRootSystemAreasFromTheImportedArtifact() throws {
  let fixture = try SafariImportFixture()
  defer { fixture.clean() }
  try fixture.writeSystemAreaAndProxyBookmarks()
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
            children: [.leaf(title: "Example", url: "https://example.com")]
          )
        ]
      )
  )
}

@Test
func safariRefreshExcludesTheNativeRootReadingListSubtree() throws {
  let fixture = try SafariImportFixture()
  defer { fixture.clean() }
  try fixture.writeNativeReadingListBookmarks()
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
            children: [.leaf(title: "Example", url: "https://example.com")]
          )
        ]
      )
  )
}

@Test
func safariRefreshAppliesNormalizationAndDuplicateRulesDuringImport() throws {
  let fixture = try SafariImportFixture()
  defer { fixture.clean() }
  try fixture.writeDuplicateNormalizationBookmarks()
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
            children: [.leaf(title: "Example", url: "HTTP://Example.com:80/path")]
          )
        ]
      )
  )
  #expect(rows[0].bookmarkCount == 1)
  #expect(rows[0].folderCount == 1)
}

@Test
func safariRefreshReplacesTheCacheDirectoryWithTheNewSnapshot() throws {
  let fixture = try SafariImportFixture()
  defer { fixture.clean() }
  try fixture.writeInitialCacheBookmarks()
  let services = InfrastructureServices(paths: fixture.paths)

  _ = try services.refreshSource(.safari)
  try Data("stale".utf8).write(to: fixture.safariCacheDirectory.appending(path: "stale.txt"))
  let originalArtifact = try Data(
    contentsOf: fixture.safariCacheDirectory.appending(path: "artifact-0.json"))

  try fixture.writeReplacementCacheBookmarks()
  let rows = try services.refreshSource(.safari)

  #expect(rows.count == 1)
  #expect(FileManager.default.fileExists(atPath: fixture.safariCacheDirectory.path))
  #expect(
    !FileManager.default.fileExists(
      atPath: fixture.safariCacheDirectory.appending(path: "stale.txt").path))
  #expect(try fixture.cacheDirectoryFilenames() == ["artifact-0.json", "index.json"])
  #expect(
    try Data(contentsOf: fixture.safariCacheDirectory.appending(path: "artifact-0.json"))
      != originalArtifact)
  let artifact = try #require(rows[0].artifact)
  #expect(
    artifact.root.bookmarkNode
      == .folder(
        title: "",
        children: [
          .folder(
            title: "Second", children: [.leaf(title: "Second", url: "https://second.example.com")])
        ]
      )
  )
}

private struct SafariImportFixture {
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

  var safariCacheDirectory: URL {
    paths.applicationSupport.appending(path: "sources/Safari")
  }

  // swiftlint:disable trailing_comma
  func writeSystemAreaAndProxyBookmarks() throws {
    let plist: [String: Any] = [
      "Children": [
        [
          "WebBookmarkType": "WebBookmarkTypeList",
          "Title": "BookmarksBar",
          "Children": [],
        ],
        [
          "WebBookmarkType": "WebBookmarkTypeList",
          "Title": "BookmarksMenu",
          "Children": [
            [
              "WebBookmarkType": "WebBookmarkTypeLeaf",
              "URLString": "https://menu.example",
              "URIDictionary": ["title": "Menu"],
            ]
          ],
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
    try writeSafariBookmarks(plist)
  }

  func writeNativeReadingListBookmarks() throws {
    let plist: [String: Any] = [
      "Children": [
        [
          "WebBookmarkType": "WebBookmarkTypeList",
          "Title": "com.apple.ReadingList",
          "Children": [
            [
              "WebBookmarkType": "WebBookmarkTypeList",
              "Title": "Nested Native Reading List Folder",
              "Children": [
                [
                  "WebBookmarkType": "WebBookmarkTypeLeaf",
                  "URLString": "https://root-reading-list.example",
                  "URIDictionary": ["title": "Root Reading List"],
                ]
              ],
            ]
          ],
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
    try writeSafariBookmarks(plist)
  }

  func writeDuplicateNormalizationBookmarks() throws {
    let plist: [String: Any] = [
      "Children": [
        [
          "WebBookmarkType": "WebBookmarkTypeList",
          "Title": "Keep",
          "Children": [
            [
              "WebBookmarkType": "WebBookmarkTypeLeaf",
              "URLString": "HTTP://Example.com:80/path",
              "URIDictionary": ["title": "Example"],
            ]
          ],
        ],
        [
          "WebBookmarkType": "WebBookmarkTypeList",
          "Title": "keep",
          "Children": [
            [
              "WebBookmarkType": "WebBookmarkTypeLeaf",
              "URLString": "http://example.com/path",
              "URIDictionary": ["title": "Example duplicate"],
            ]
          ],
        ],
      ]
    ]
    try writeSafariBookmarks(plist)
  }

  func writeInitialCacheBookmarks() throws {
    let plist: [String: Any] = [
      "Children": [
        [
          "WebBookmarkType": "WebBookmarkTypeList",
          "Title": "First",
          "Children": [
            [
              "WebBookmarkType": "WebBookmarkTypeLeaf",
              "URLString": "https://first.example.com",
              "URIDictionary": ["title": "First"],
            ]
          ],
        ]
      ]
    ]
    try writeSafariBookmarks(plist)
  }

  func writeReplacementCacheBookmarks() throws {
    let plist: [String: Any] = [
      "Children": [
        [
          "WebBookmarkType": "WebBookmarkTypeList",
          "Title": "Second",
          "Children": [
            [
              "WebBookmarkType": "WebBookmarkTypeLeaf",
              "URLString": "https://second.example.com",
              "URIDictionary": ["title": "Second"],
            ]
          ],
        ]
      ]
    ]
    try writeSafariBookmarks(plist)
  }
  // swiftlint:enable trailing_comma

  func clean() {
    try? FileManager.default.removeItem(at: root)
  }

  func cacheDirectoryFilenames() throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: safariCacheDirectory.path).sorted()
  }

  private func writeSafariBookmarks(_ plist: [String: Any]) throws {
    let parent = paths.safariBookmarks.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    let data = try PropertyListSerialization.data(
      fromPropertyList: plist, format: .binary, options: 0)
    try data.write(to: paths.safariBookmarks)
  }
}
