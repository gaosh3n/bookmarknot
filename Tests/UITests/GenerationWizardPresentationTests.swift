import Domain
import Testing

@testable import UI

@Test
func generationWizardStartsCollapsedAndExpandsDescendantsOneFolderAtATime() throws {
  let tree = BookmarkNode.folder(
    title: "",
    children: [
      .folder(
        title: "Folder",
        children: [
          .folder(
            title: "Nested",
            children: [.leaf(title: "Leaf", url: "https://example.com")]
          )
        ]
      )
    ]
  )
  let session = GenerationSession(current: nil, incoming: tree)
  let decisions = session.decisions

  #expect(
    GenerationWizardPresentation.visibleDecisions(
      from: decisions,
      expandedFolderIDs: []
    ).map(\.title) == ["Folder"]
  )

  let outerFolderID = try #require(decisions.first(where: { $0.title == "Folder" })?.id)
  #expect(
    GenerationWizardPresentation.visibleDecisions(
      from: decisions,
      expandedFolderIDs: [outerFolderID]
    ).map(\.title) == ["Folder", "Nested"]
  )

  let nestedFolderID = try #require(decisions.first(where: { $0.title == "Nested" })?.id)
  #expect(
    GenerationWizardPresentation.visibleDecisions(
      from: decisions,
      expandedFolderIDs: [outerFolderID, nestedFolderID]
    ).map(\.title) == ["Folder", "Nested", "Leaf"]
  )
}

@Test
func generationWizardUsesCurrentAndIncomingPresentationRoles() {
  #expect(GenerationWizardPresentation.sideLabel(for: .current) == "Current")
  #expect(GenerationWizardPresentation.sideLabel(for: .incoming) == "Incoming")
  #expect(GenerationWizardPresentation.tone(for: .current) == .current)
  #expect(GenerationWizardPresentation.tone(for: .incoming) == .incoming)
}

@Test
func generationWizardUsesTheSpecifiedAbortConfirmationCopy() {
  #expect(
    GenerationWizardPresentation.abortConfirmationMessage
      == "Abort generation? Unresolved progress will be lost and no artifact will be saved."
  )
  #expect(GenerationWizardPresentation.continueGenerationLabel == "Continue Generation")
  #expect(GenerationWizardPresentation.abortLabel == "Abort")
}
