import Application
import Combine
import CryptoKit
import Domain
import Foundation

public struct InfrastructurePaths: Sendable {
  public let chromeRoot: URL
  public let safariBookmarks: URL
  public let applicationSupport: URL

  public init(chromeRoot: URL, safariBookmarks: URL, applicationSupport: URL) {
    self.chromeRoot = chromeRoot
    self.safariBookmarks = safariBookmarks
    self.applicationSupport = applicationSupport
  }

  public static var live: InfrastructurePaths {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return InfrastructurePaths(
      chromeRoot: home.appending(path: "Library/Application Support/Google/Chrome"),
      safariBookmarks: home.appending(path: "Library/Safari/Bookmarks.plist"),
      applicationSupport: home.appending(path: "Library/Application Support/Bookmarknot")
    )
  }
}

public enum InfrastructureError: Error, CustomStringConvertible {
  case invalidChrome(String)
  case invalidSafari(String)
  case allImportsFailed(BrowserKind)
  case invalidArtifactDirectory(String)
  case hashMismatch(String)

  public var description: String {
    switch self {
    case .invalidChrome(let detail): "Invalid Chrome bookmarks: \(detail)"
    case .invalidSafari(let detail): "Invalid Safari bookmarks: \(detail)"
    case .allImportsFailed(let browser): "Every discovered \(browser.rawValue) artifact failed."
    case .invalidArtifactDirectory(let detail): "Invalid artifact directory: \(detail)"
    case .hashMismatch(let filename): "Artifact hash does not match filename: \(filename)"
    }
  }
}

public final class InfrastructureServices: BookmarknotServices {
  private let fileManager: FileManager
  private let paths: InfrastructurePaths
  private let canonicalizer: ArtifactCanonicalizer
  private let runtimeLogStore: RuntimeLogStore

  public var runtimeLogUpdates: AnyPublisher<String, Never> {
    runtimeLogStore.updates
  }

  public init(paths: InfrastructurePaths = .live, fileManager: FileManager = .default) {
    self.paths = paths
    self.fileManager = fileManager
    runtimeLogStore = RuntimeLogStore(
      fileManager: fileManager,
      file: paths.applicationSupport.appending(path: "logs/runtime.log")
    )
    canonicalizer = ArtifactCanonicalizer(md5: { Self.md5($0) })
  }

  public func refreshSource(_ browser: BrowserKind) throws -> [SourceArtifact] {
    let sourceURLs = try discover(browser)
    var rows: [SourceArtifact] = []
    for url in sourceURLs {
      do {
        rows.append(try importSource(url, browser: browser))
      } catch {
        log(.warning, "\(browser.rawValue) import failed for \(url.path): \(error)")
        rows.append(failedRow(for: url, browser: browser, error: error))
      }
    }
    rows.sort { $0.createdAt > $1.createdAt }
    let successful = rows.filter { $0.status == .ready }
    if !rows.isEmpty && successful.isEmpty {
      try replaceSourceCache(for: browser, rows: [])
      throw InfrastructureError.allImportsFailed(browser)
    }
    if successful.count != rows.count {
      let failedCount = rows.count - successful.count
      log(
        .warning,
        "\(browser.rawValue) refresh completed with \(successful.count) successful rows and \(failedCount) failed rows."
      )
    }
    try replaceSourceCache(for: browser, rows: rows)
    return rows
  }

  public func refreshSavedArtifacts() throws -> [SavedArtifact] {
    let directory = artifactDirectory
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let entries = try fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .fileSizeKey],
      options: []
    )
    var artifacts: [SavedArtifact] = []
    for entry in entries {
      let values = try entry.resourceValues(
        forKeys: [.isDirectoryKey, .creationDateKey, .fileSizeKey]
      )
      guard values.isDirectory == false, entry.pathExtension == "json" else {
        throw InfrastructureError.invalidArtifactDirectory(entry.lastPathComponent)
      }
      let expectedHash = entry.deletingPathExtension().lastPathComponent
      let data = try Data(contentsOf: entry)
      guard Self.sha256(data) == expectedHash else {
        throw InfrastructureError.hashMismatch(entry.lastPathComponent)
      }
      let artifact = try canonicalizer.decodeAndValidate(data)
      artifacts.append(
        SavedArtifact(
          hash: expectedHash,
          createdAt: values.creationDate ?? .distantPast,
          bookmarkCount: artifact.bookmarkCount,
          folderCount: artifact.folderCount,
          fileSize: Int64(values.fileSize ?? data.count),
          artifact: artifact
        )
      )
    }
    return artifacts.sorted { $0.createdAt > $1.createdAt }
  }

  public func canonicalize(_ root: BookmarkNode) throws -> CanonicalArtifact {
    try canonicalizer.canonicalize(root)
  }

  public func save(_ artifact: CanonicalArtifact) throws -> ArtifactSaveOutcome {
    let directory = artifactDirectory
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let hash = Self.sha256(artifact.data)
    let url = directory.appending(path: hash + ".json")
    if fileManager.fileExists(atPath: url.path) {
      let existingData = try Data(contentsOf: url)
      guard existingData == artifact.data else {
        throw InfrastructureError.hashMismatch(url.lastPathComponent)
      }
      let existing = try savedArtifact(hash: hash, url: url, artifact: artifact)
      return .existing(existing)
    }
    try artifact.data.write(to: url, options: [.atomic])
    return .created(try savedArtifact(hash: hash, url: url, artifact: artifact))
  }

  public func runtimeLog() -> String {
    runtimeLogStore.read()
  }

  public func cleanRuntimeLog() throws {
    try runtimeLogStore.clean()
  }

  public func log(_ level: RuntimeLogLevel, _ message: String) {
    do {
      try runtimeLogStore.append(level: level, message: message)
    } catch {
      // Logging must never turn a recoverable app operation into a crash.
    }
  }

  private var artifactDirectory: URL { paths.applicationSupport.appending(path: "artifacts") }

  private func discover(_ browser: BrowserKind) throws -> [URL] {
    switch browser {
    case .chrome:
      guard fileManager.fileExists(atPath: paths.chromeRoot.path) else { return [] }
      return try fileManager.contentsOfDirectory(
        at: paths.chromeRoot,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      .filter { url in
        let name = url.lastPathComponent
        return name == "Default" || name.hasPrefix("Profile ")
      }
      .map { $0.appending(path: "Bookmarks") }
      .filter { fileManager.fileExists(atPath: $0.path) }
    case .safari:
      return fileManager.fileExists(atPath: paths.safariBookmarks.path)
        ? [paths.safariBookmarks] : []
    }
  }

  private func importSource(_ url: URL, browser: BrowserKind) throws -> SourceArtifact {
    let data = try Data(contentsOf: url)
    let root: BookmarkNode
    switch browser {
    case .chrome: root = try ChromeImporter.importBookmarks(data)
    case .safari: root = try SafariImporter.importBookmarks(data)
    }
    let artifact = try canonicalizer.canonicalize(root)
    let values = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
    return SourceArtifact(
      id: url.path,
      browser: browser,
      path: url.path,
      createdAt: values.creationDate ?? .distantPast,
      bookmarkCount: artifact.bookmarkCount,
      folderCount: artifact.folderCount,
      fileSize: Int64(values.fileSize ?? data.count),
      status: .ready,
      artifact: artifact
    )
  }

  private func failedRow(for url: URL, browser: BrowserKind, error: Error) -> SourceArtifact {
    let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
    return SourceArtifact(
      id: url.path,
      browser: browser,
      path: url.path,
      createdAt: values?.creationDate ?? .distantPast,
      bookmarkCount: nil,
      folderCount: nil,
      fileSize: Int64(values?.fileSize ?? 0),
      status: .failed,
      artifact: nil,
      errorDescription: String(describing: error)
    )
  }

  private func replaceSourceCache(for browser: BrowserKind, rows: [SourceArtifact]) throws {
    let sources = paths.applicationSupport.appending(path: "sources")
    try fileManager.createDirectory(at: sources, withIntermediateDirectories: true)
    let destination = sources.appending(path: browser.rawValue)
    let temporary = sources.appending(path: ".\(browser.rawValue)-\(UUID().uuidString)")
    try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)
    do {
      var indexRows: [SourceIndexRow] = []
      for (position, row) in rows.enumerated() {
        var filename: String?
        if let artifact = row.artifact {
          let artifactFilename = "artifact-\(position).json"
          filename = artifactFilename
          try artifact.data.write(
            to: temporary.appending(path: artifactFilename), options: [.atomic])
        }
        indexRows.append(SourceIndexRow(row: row, artifactFilename: filename))
      }
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      encoder.dateEncodingStrategy = .iso8601
      let indexData = try encoder.encode(SourceIndex(rows: indexRows))
      try indexData.write(to: temporary.appending(path: "index.json"), options: [.atomic])
      let backup = sources.appending(path: ".\(browser.rawValue)-backup-\(UUID().uuidString)")
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.moveItem(at: destination, to: backup)
      }
      do {
        try fileManager.moveItem(at: temporary, to: destination)
        try? fileManager.removeItem(at: backup)
      } catch {
        if fileManager.fileExists(atPath: backup.path) {
          try? fileManager.moveItem(at: backup, to: destination)
        }
        throw error
      }
    } catch {
      try? fileManager.removeItem(at: temporary)
      throw error
    }
  }

  private func savedArtifact(
    hash: String,
    url: URL,
    artifact: CanonicalArtifact
  ) throws -> SavedArtifact {
    let values = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
    return SavedArtifact(
      hash: hash,
      createdAt: values.creationDate ?? Date(),
      bookmarkCount: artifact.bookmarkCount,
      folderCount: artifact.folderCount,
      fileSize: Int64(values.fileSize ?? artifact.data.count),
      artifact: artifact
    )
  }

  private static func md5(_ data: Data) -> String {
    Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}

private struct SourceIndex: Encodable {
  let rows: [SourceIndexRow]
}

private struct SourceIndexRow: Encodable {
  let id: String
  let path: String
  let createdAt: Date
  let bookmarkCount: Int?
  let folderCount: Int?
  let fileSize: Int64
  let status: String
  let artifactFilename: String?
  let errorDescription: String?

  init(row: SourceArtifact, artifactFilename: String?) {
    id = row.id
    path = row.path
    createdAt = row.createdAt
    bookmarkCount = row.bookmarkCount
    folderCount = row.folderCount
    fileSize = row.fileSize
    status = row.status.rawValue
    self.artifactFilename = artifactFilename
    errorDescription = row.errorDescription
  }
}

private enum ChromeImporter {
  static func importBookmarks(_ data: Data) throws -> BookmarkNode {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let roots = object["roots"] as? [String: Any],
      let bar = roots["bookmark_bar"] as? [String: Any],
      let children = bar["children"] as? [[String: Any]]
    else {
      throw InfrastructureError.invalidChrome("missing roots.bookmark_bar.children")
    }
    return .folder(title: "", children: try children.map(parseNode))
  }

  private static func parseNode(_ object: [String: Any]) throws -> BookmarkNode {
    guard let type = object["type"] as? String else {
      throw InfrastructureError.invalidChrome("node is missing type")
    }
    switch type {
    case "folder":
      guard let title = object["name"] as? String,
        let children = object["children"] as? [[String: Any]]
      else { throw InfrastructureError.invalidChrome("folder is missing name or children") }
      return .folder(title: title, children: try children.map(parseNode))
    case "url":
      guard let title = object["name"] as? String, let url = object["url"] as? String else {
        throw InfrastructureError.invalidChrome("URL node is missing name or url")
      }
      return .leaf(title: title, url: url)
    default:
      throw InfrastructureError.invalidChrome("unknown node type \(type)")
    }
  }
}

private enum SafariImporter {
  static func importBookmarks(_ data: Data) throws -> BookmarkNode {
    guard
      let root = try PropertyListSerialization.propertyList(from: data, format: nil)
        as? [String: Any],
      let children = root["Children"] as? [[String: Any]]
    else { throw InfrastructureError.invalidSafari("root is missing Children") }
    let imported = try children.compactMap { child -> BookmarkNode? in
      if let title = child["Title"] as? String, isExcludedRootTitle(title) { return nil }
      return try parseNode(child)
    }
    return .folder(title: "", children: imported)
  }

  private static func isExcludedRootTitle(_ title: String) -> Bool {
    title == "BookmarksBar" || title == "BookmarksMenu" || title == "com.apple.ReadingList"
  }

  private static func parseNode(_ object: [String: Any]) throws -> BookmarkNode? {
    guard let type = object["WebBookmarkType"] as? String else {
      throw InfrastructureError.invalidSafari("node is missing WebBookmarkType")
    }
    switch type {
    case "WebBookmarkTypeProxy":
      return nil
    case "WebBookmarkTypeList":
      guard let title = object["Title"] as? String,
        let children = object["Children"] as? [[String: Any]]
      else { throw InfrastructureError.invalidSafari("list node is missing Title or Children") }
      return .folder(title: title, children: try children.compactMap(parseNode))
    case "WebBookmarkTypeLeaf":
      guard let url = object["URLString"] as? String,
        let uri = object["URIDictionary"] as? [String: Any],
        let title = uri["title"] as? String
      else {
        throw InfrastructureError.invalidSafari(
          "leaf node is missing URLString or URIDictionary.title")
      }
      return .leaf(title: title, url: url)
    default:
      throw InfrastructureError.invalidSafari("unknown node type \(type)")
    }
  }
}
