import Application
import CryptoKit
import Domain
import Foundation
import Testing

@testable import Infrastructure

@Test
func savedArtifactsAreReturnedNewestFirst() throws {
  let fixture = try SavedArtifactFixture()
  defer { fixture.clean() }
  let services = InfrastructureServices(paths: fixture.paths)
  let older = try services.canonicalize(
    .folder(title: "", children: [.leaf(title: "Older", url: "https://older.example.com")])
  )
  let newer = try services.canonicalize(
    .folder(title: "", children: [.leaf(title: "Newer", url: "https://newer.example.com")])
  )
  try fixture.writeSavedArtifact(named: older.data, creationDate: Date(timeIntervalSince1970: 1))
  try fixture.writeSavedArtifact(named: newer.data, creationDate: Date(timeIntervalSince1970: 2))

  let artifacts = try services.refreshSavedArtifacts()

  #expect(artifacts.map(\.hash) == [fixture.sha256(newer.data), fixture.sha256(older.data)])
}

@Test
func savingAnExistingArtifactLeavesTheFileUntouched() throws {
  let fixture = try SavedArtifactFixture()
  defer { fixture.clean() }
  let services = InfrastructureServices(paths: fixture.paths)
  let artifact = try services.canonicalize(
    .folder(title: "", children: [.leaf(title: "Example", url: "https://example.com")])
  )

  let created = try services.save(artifact)
  guard case .created(let saved) = created else {
    Issue.record("Expected the first save to create the artifact")
    return
  }
  let url = fixture.paths.applicationSupport.appending(path: "artifacts/\(saved.hash).json")
  let beforeValues = try url.resourceValues(
    forKeys: [.creationDateKey, .contentModificationDateKey]
  )
  let beforeData = try Data(contentsOf: url)

  let existing = try services.save(artifact)

  guard case .existing(let matched) = existing else {
    Issue.record("Expected the second save to reuse the artifact")
    return
  }
  let afterValues = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
  let afterData = try Data(contentsOf: url)

  #expect(matched.hash == saved.hash)
  #expect(afterData == beforeData)
  #expect(afterValues.creationDate == beforeValues.creationDate)
  #expect(afterValues.contentModificationDate == beforeValues.contentModificationDate)
}

@Test
func unreadableSavedArtifactDirectoryFailsRefresh() throws {
  let fixture = try SavedArtifactFixture()
  defer { fixture.clean() }
  let directory = fixture.paths.applicationSupport.appending(path: "artifacts")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: directory.path)
  defer {
    try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
  }
  let services = InfrastructureServices(paths: fixture.paths)

  #expect(throws: Error.self) {
    try services.refreshSavedArtifacts()
  }
}

private struct SavedArtifactFixture {
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

  func writeSavedArtifact(named data: Data, creationDate: Date) throws {
    let directory = paths.applicationSupport.appending(path: "artifacts")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appending(path: "\(sha256(data)).json")
    try data.write(to: url, options: [.atomic])
    try FileManager.default.setAttributes([.creationDate: creationDate], ofItemAtPath: url.path)
  }

  func clean() {
    try? FileManager.default.removeItem(at: root)
  }

  func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
