// swiftlint:disable trailing_comma
import Application
import Domain
import Foundation
import Testing

@testable import UI

@Test
func sourceArtifactOptionalColumnsExcludeTheIdentityColumnFromTheMenu() {
  #expect(
    SourceArtifactOptionalColumn.allCases.map(\.rawValue) == [
      "Created", "Counts", "Size", "Status",
    ]
  )
}

@Test
func savedArtifactOptionalColumnsExcludeTheIdentityColumnFromTheMenu() {
  #expect(SavedArtifactOptionalColumn.allCases.map(\.rawValue) == ["Created", "Counts", "Size"])
}

@Test
func narrowSourceArtifactColumnsRequireATallerRowToAvoidClippingContent() {
  let artifact = SourceArtifact(
    id: "chrome-1",
    browser: .chrome,
    path: [
      "/Users/gaoshen/Library/Application Support/Google/Chrome/Default/Bookmarks",
      "Very/Long/Nested/Folder/Bookmarks.json",
    ].joined(separator: "/"),
    createdAt: Date(timeIntervalSinceReferenceDate: 0),
    bookmarkCount: 42,
    folderCount: 7,
    fileSize: 1024,
    status: .ready,
    artifact: nil
  )
  let layout = SourceArtifactTableLayout(
    showCreated: true,
    showCounts: true,
    showSize: true,
    showStatus: true,
    pathWidth: 120,
    createdWidth: 120,
    countsWidth: 120,
    sizeWidth: 120,
    statusWidth: 120
  )

  #expect(
    ConfigurationTablePresentation.sourceArtifactRowHeight(artifact: artifact, layout: layout)
      > ConfigurationTablePresentation.minimumRowHeight)
}

@Test
func shortSavedArtifactRowsKeepTheBaseHeight() {
  let artifact = SavedArtifact(
    hash: "0123456789abcdef",
    createdAt: Date(timeIntervalSinceReferenceDate: 0),
    bookmarkCount: 2,
    folderCount: 1,
    fileSize: 256,
    artifact: canonicalArtifact()
  )
  let layout = SavedArtifactTableLayout(
    showCreated: false,
    showCounts: false,
    showSize: false,
    hashWidth: 180,
    createdWidth: 120,
    countsWidth: 120,
    sizeWidth: 120
  )

  #expect(
    ConfigurationTablePresentation.savedArtifactRowHeight(artifact: artifact, layout: layout)
      == ConfigurationTablePresentation.minimumRowHeight)
}

private func canonicalArtifact() -> CanonicalArtifact {
  CanonicalArtifact(
    root: .folder(uuid: "root", title: "", children: []),
    data: Data("{}".utf8)
  )
}
// swiftlint:enable trailing_comma
