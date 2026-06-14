import Combine
import Domain
import Foundation
import Testing

@testable import Application

@MainActor
@Test
func generationSessionDoesNotChangeAfterChromeRefreshesAgain() throws {
  let services = FakeServices()
  services.sourceArtifactFactory = {
    SourceArtifact(
      id: "chrome",
      browser: .chrome,
      path: "/Chrome/Bookmarks",
      createdAt: Date(),
      bookmarkCount: 1,
      folderCount: 0,
      fileSize: 1,
      status: .ready,
      artifact: try ArtifactCanonicalizer { _ in "identity" }.canonicalize(
        .folder(title: "", children: [.leaf(title: "Old", url: "https://old.example")])
      )
    )
  }
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.bookmarknot)
  model.beginGeneration()

  let initialTitle = try #require(model.generationSession?.decisions.first?.title)

  services.sourceArtifactFactory = {
    SourceArtifact(
      id: "chrome",
      browser: .chrome,
      path: "/Chrome/Bookmarks",
      createdAt: Date(),
      bookmarkCount: 1,
      folderCount: 0,
      fileSize: 1,
      status: .ready,
      artifact: try ArtifactCanonicalizer { _ in "identity" }.canonicalize(
        .folder(title: "", children: [.leaf(title: "New", url: "https://new.example")])
      )
    )
  }
  model.refresh(.chrome)

  #expect(try #require(model.generationSession?.decisions.first?.title) == initialTitle)
}
