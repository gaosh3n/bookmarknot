import Combine
import Domain
import Foundation
import Testing

@testable import Application

@MainActor
@Test
func cancelGenerationDiscardsProgressWithoutSavingAnything() throws {
  let services = FakeServices()
  let model = BookmarknotModel(services: services)
  model.refresh(.chrome)
  model.refresh(.bookmarknot)
  model.beginGeneration()
  let decision = try #require(model.generationSession?.decisions.first)
  model.resolveDecision(decision.id, as: .accepted, recursively: decision.kind == .folder)

  model.cancelGeneration()

  #expect(model.generationSession == nil)
  #expect(model.bookmarknotArtifacts.isEmpty)
  #expect(services.saveCallCount == 0)
}
