import Domain

enum GenerationWizardPresentation {
  static let abortConfirmationMessage =
    "Abort generation? Unresolved progress will be lost and no artifact will be saved."
  static let continueGenerationLabel = "Continue Generation"
  static let abortLabel = "Abort"

  static func visibleDecisions(
    from decisions: [DecisionOccurrence],
    expandedFolderIDs: Set<String>
  ) -> [DecisionOccurrence] {
    decisions.filter { decision in
      guard decision.path.count > 1 else { return true }
      for length in 1..<decision.path.count {
        let parentPath = Array(decision.path.prefix(length))
        let parent = decisions.first {
          $0.side == decision.side && $0.path == parentPath && $0.kind == .folder
        }
        if let parent, !expandedFolderIDs.contains(parent.id) { return false }
      }
      return true
    }
  }
}
