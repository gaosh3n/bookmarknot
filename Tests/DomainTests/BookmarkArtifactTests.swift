import Foundation
import Testing

@testable import Domain

private let canonicalizer = ArtifactCanonicalizer { data in
  "md5[\(String(data: data, encoding: .utf8) ?? "")]"
}

@Test
func canonicalizationMergesFoldersRemovesDuplicateURLsAndUsesStableOrder() throws {
  var sourceChildren: [BookmarkNode] = []
  sourceChildren.append(.leaf(title: "", url: "HTTPS://Example.COM:443/path"))
  sourceChildren.append(
    .folder(title: "zeta", children: [.leaf(title: "B", url: "https://b.example")])
  )
  sourceChildren.append(
    .folder(title: "ZETA", children: [.leaf(title: "Duplicate", url: "https://example.com/path")])
  )
  sourceChildren.append(.folder(title: "Alpha", children: []))
  let root = BookmarkNode.folder(title: "", children: sourceChildren)

  let artifact = try canonicalizer.canonicalize(root)
  let json = try #require(String(data: artifact.data, encoding: .utf8))

  #expect(artifact.bookmarkCount == 2)
  #expect(artifact.folderCount == 2)
  guard case .folder(_, _, let children) = artifact.root else {
    Issue.record("Expected canonical root folder")
    return
  }
  #expect(children.map(\.title) == ["Alpha", "zeta"])
  #expect(json.contains("md5[folder:zeta]"))
  #expect(json.hasSuffix("}\n"))
  #expect(try canonicalizer.decodeAndValidate(artifact.data) == artifact)
}

@Test
func urlIdentityUsesOnlyMinimalNormalization() {
  #expect(
    BookmarkNormalization.urlIdentity("HTTP://Example.COM:80/a?x=1#f")
      == "http://example.com/a?x=1#f"
  )
  #expect(BookmarkNormalization.urlIdentity("https://Example.COM:443/") == "https://example.com/")
  #expect(BookmarkNormalization.urlIdentity("custom:value") == "custom:value")
}

@Test
func emptyFolderTitlesFailAndEmptyLeafTitlesFallBackToURL() throws {
  #expect(throws: ArtifactError.emptyFolderTitle) {
    try canonicalizer.canonicalize(
      .folder(title: "", children: [.folder(title: "  ", children: [])]))
  }

  let artifact = try canonicalizer.canonicalize(
    .folder(title: "", children: [.leaf(title: " \n", url: "https://example.com")])
  )
  let json = try #require(String(data: artifact.data, encoding: .utf8))
  #expect(json.contains("\"title\": \"https://example.com\""))
}

@Test
func generationResolvesFoldersRecursivelyAndPreventsSameURLFromBothSides() {
  let current = BookmarkNode.folder(
    title: "",
    children: [
      .folder(title: "Current", children: [.leaf(title: "A", url: "https://example.com")])
    ])
  let incoming = BookmarkNode.folder(
    title: "",
    children: [
      .leaf(title: "Incoming", url: "HTTPS://EXAMPLE.COM:443")
    ])
  var session = GenerationSession(current: current, incoming: incoming)

  guard
    let currentFolder = session.decisions.first(where: {
      $0.side == .current && $0.kind == .folder
    })
  else {
    Issue.record("Expected a current folder decision")
    return
  }
  session.resolve(currentFolder.id, as: .accepted, recursively: true)
  guard let incomingLeaf = session.decisions.first(where: { $0.side == .incoming }) else {
    Issue.record("Expected an incoming leaf decision")
    return
  }
  session.resolve(incomingLeaf.id, as: .accepted)

  #expect(session.isResolved)
  #expect(session.decisions.first { $0.side == .current && $0.kind == .leaf }?.state == .rejected)
  #expect(session.resolvedRoot() != nil)
}
