import Domain
import Testing

@testable import UI

@Test
func sameURLConflictPresentationKeepsCurrentAndIncomingCandidatesDistinct() throws {
  let current = BookmarkNode.folder(
    title: "",
    children: [
      .folder(
        title: "Current Folder",
        children: [.leaf(title: "Shared", url: "HTTPS://Example.COM:443/path")]
      )
    ])
  let incoming = BookmarkNode.folder(
    title: "",
    children: [
      .folder(
        title: "Incoming Folder",
        children: [.leaf(title: "Shared", url: "https://example.com/path")]
      )
    ])
  let session = GenerationSession(current: current, incoming: incoming)
  let decisions = session.decisions

  let currentFolderID = try #require(decisions.first(where: { $0.title == "Current Folder" })?.id)
  let incomingFolderID = try #require(decisions.first(where: { $0.title == "Incoming Folder" })?.id)
  let visible = GenerationWizardPresentation.visibleDecisions(
    from: decisions,
    expandedFolderIDs: [currentFolderID, incomingFolderID]
  )

  let sameURLLeaves = visible.filter { $0.title == "Shared" }
  #expect(sameURLLeaves.count == 2)
  #expect(sameURLLeaves.map(\.side) == [.current, .incoming])
  #expect(
    sameURLLeaves.map { GenerationWizardPresentation.sideLabel(for: $0.side) }
      == ["Current", "Incoming"]
  )
  #expect(
    sameURLLeaves.map { GenerationWizardPresentation.tone(for: $0.side) }
      == [.current, .incoming]
  )
}
