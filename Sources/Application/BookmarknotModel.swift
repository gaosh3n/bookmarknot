import Combine
import Domain
import Foundation

public enum ArtifactKind: CaseIterable, Hashable, Sendable {
  case chrome
  case safari
  case bookmarknot
}

public enum ArtifactListState: Equatable, Sendable {
  case notRefreshed
  case loaded
}

public enum SourceArtifactStatus: String, Equatable, Sendable {
  case ready = "Ready"
  case failed = "Failed"
}

public struct SourceArtifact: Identifiable, Equatable, Sendable {
  public let id: String
  public let browser: BrowserKind
  public let path: String
  public let createdAt: Date
  public let bookmarkCount: Int?
  public let folderCount: Int?
  public let fileSize: Int64
  public let status: SourceArtifactStatus
  public let artifact: CanonicalArtifact?
  public let errorDescription: String?

  public init(
    id: String,
    browser: BrowserKind,
    path: String,
    createdAt: Date,
    bookmarkCount: Int?,
    folderCount: Int?,
    fileSize: Int64,
    status: SourceArtifactStatus,
    artifact: CanonicalArtifact?,
    errorDescription: String? = nil
  ) {
    self.id = id
    self.browser = browser
    self.path = path
    self.createdAt = createdAt
    self.bookmarkCount = bookmarkCount
    self.folderCount = folderCount
    self.fileSize = fileSize
    self.status = status
    self.artifact = artifact
    self.errorDescription = errorDescription
  }
}

public struct SavedArtifact: Identifiable, Equatable, Sendable {
  public var id: String { hash }
  public let hash: String
  public let createdAt: Date
  public let bookmarkCount: Int
  public let folderCount: Int
  public let fileSize: Int64
  public let artifact: CanonicalArtifact

  public init(
    hash: String,
    createdAt: Date,
    bookmarkCount: Int,
    folderCount: Int,
    fileSize: Int64,
    artifact: CanonicalArtifact
  ) {
    self.hash = hash
    self.createdAt = createdAt
    self.bookmarkCount = bookmarkCount
    self.folderCount = folderCount
    self.fileSize = fileSize
    self.artifact = artifact
  }

  public var shortHash: String { String(hash.prefix(12)) }
}

public enum ArtifactSaveOutcome: Equatable, Sendable {
  case created(SavedArtifact)
  case existing(SavedArtifact)
}

public enum RuntimeLogLevel: String, Equatable, Sendable {
  case info = "INFO"
  case warning = "WARN"
  case error = "ERROR"
}

public protocol BookmarknotServices: AnyObject {
  var runtimeLogUpdates: AnyPublisher<String, Never> { get }

  func refreshSource(_ browser: BrowserKind) throws -> [SourceArtifact]
  func refreshSavedArtifacts() throws -> [SavedArtifact]
  func canonicalize(_ root: BookmarkNode) throws -> CanonicalArtifact
  func save(_ artifact: CanonicalArtifact) throws -> ArtifactSaveOutcome
  func runtimeLog() -> String
  func cleanRuntimeLog() throws
  func log(_ level: RuntimeLogLevel, _ message: String)
}

public enum UserDialog: String, Identifiable, Sendable {
  case cannotLoad = "Cannot load artifacts. See Runtime Log."
  case noChange = "No change in artifact."
  case generationAborted = "Generation aborted. See Runtime Log."

  public var id: String { rawValue }
}

@MainActor
public final class BookmarknotModel: ObservableObject {
  @Published public private(set) var chromeState: ArtifactListState = .notRefreshed
  @Published public private(set) var safariState: ArtifactListState = .notRefreshed
  @Published public private(set) var bookmarknotState: ArtifactListState = .notRefreshed
  @Published public private(set) var chromeArtifacts: [SourceArtifact] = []
  @Published public private(set) var safariArtifacts: [SourceArtifact] = []
  @Published public private(set) var bookmarknotArtifacts: [SavedArtifact] = []
  @Published public var selectedChromeID: SourceArtifact.ID?
  @Published public var selectedSafariID: SourceArtifact.ID?
  @Published public var selectedBookmarknotID: SavedArtifact.ID?
  @Published public private(set) var generationSession: GenerationSession?
  @Published public private(set) var runtimeLogContent = ""
  @Published public var dialog: UserDialog?

  private let services: BookmarknotServices
  private var runtimeLogObservation: AnyCancellable?
  private var localArtifactsAreValid = false

  public init(services: BookmarknotServices) {
    self.services = services
    runtimeLogContent = services.runtimeLog()
    runtimeLogObservation = services.runtimeLogUpdates.sink { [weak self] content in
      self?.runtimeLogContent = content
    }
  }

  public var canGenerate: Bool {
    localArtifactsAreValid && (selectedChromeArtifact != nil || selectedSafariArtifact != nil)
  }

  public func refresh(_ kind: ArtifactKind) {
    services.log(.info, "Started \(kind.logName) refresh.")
    switch kind {
    case .chrome: refreshChrome()
    case .safari: refreshSafari()
    case .bookmarknot: refreshBookmarknot()
    }
    runtimeLogContent = services.runtimeLog()
  }

  public func beginGeneration() {
    guard canGenerate else { return }
    services.log(.info, "Started generation.")
    let current = selectedSafariArtifact?.artifact?.root.bookmarkNode
    let incoming = selectedChromeArtifact?.artifact?.root.bookmarkNode
    let session = GenerationSession(current: current, incoming: incoming)
    guard session.totalCount > 0 || session.hasAcceptedContent else {
      services.log(.error, "Generation failed: selected sources contain no supported bookmarks.")
      runtimeLogContent = services.runtimeLog()
      dialog = .generationAborted
      return
    }
    generationSession = session
  }

  public func resolveDecision(_ id: String, as state: DecisionState, recursively: Bool) {
    generationSession?.resolve(id, as: state, recursively: recursively)
  }

  public func cancelGeneration() {
    guard generationSession != nil else { return }
    services.log(.info, "Aborted generation.")
    generationSession = nil
  }

  public func completeGeneration() {
    guard let root = generationSession?.resolvedRoot() else { return }
    do {
      let artifact = try services.canonicalize(root)
      let outcome = try services.save(artifact)
      generationSession = nil
      guard refreshBookmarknot() else { return }
      switch outcome {
      case .created(let saved):
        selectedBookmarknotID = saved.id
        services.log(.info, "Completed generation with artifact \(saved.shortHash).")
      case .existing(let saved):
        selectedBookmarknotID = saved.id
        services.log(.info, "Generation matched existing artifact \(saved.shortHash).")
        dialog = .noChange
      }
    } catch {
      services.log(.error, "Generation failed: \(error)")
      generationSession = nil
      runtimeLogContent = services.runtimeLog()
      dialog = .generationAborted
    }
  }

  public func cleanRuntimeLog() {
    do {
      try services.cleanRuntimeLog()
      runtimeLogContent = ""
    } catch {
      services.log(.error, "Runtime log clean failed: \(error)")
      runtimeLogContent = services.runtimeLog()
    }
  }

  private var selectedChromeArtifact: SourceArtifact? {
    chromeArtifacts.first { $0.id == selectedChromeID && $0.status == .ready }
  }

  private var selectedSafariArtifact: SourceArtifact? {
    safariArtifacts.first { $0.id == selectedSafariID && $0.status == .ready }
  }

  private func refreshChrome() {
    do {
      chromeArtifacts = try services.refreshSource(.chrome)
      chromeState = .loaded
      selectedChromeID = defaultSourceSelection(in: chromeArtifacts)
      services.log(.info, "Completed Chrome refresh with \(chromeArtifacts.count) rows.")
    } catch {
      chromeArtifacts = []
      chromeState = .loaded
      selectedChromeID = nil
      services.log(.error, "Chrome refresh failed: \(error)")
      dialog = .cannotLoad
    }
  }

  private func refreshSafari() {
    do {
      safariArtifacts = try services.refreshSource(.safari)
      safariState = .loaded
      selectedSafariID = defaultSourceSelection(in: safariArtifacts)
      services.log(.info, "Completed Safari refresh with \(safariArtifacts.count) rows.")
    } catch {
      safariArtifacts = []
      safariState = .loaded
      selectedSafariID = nil
      services.log(.error, "Safari refresh failed: \(error)")
      dialog = .cannotLoad
    }
  }

  @discardableResult
  private func refreshBookmarknot() -> Bool {
    do {
      bookmarknotArtifacts = try services.refreshSavedArtifacts()
      bookmarknotState = .loaded
      localArtifactsAreValid = true
      selectedBookmarknotID = bookmarknotArtifacts.first?.id
      services.log(.info, "Completed Bookmarknot refresh with \(bookmarknotArtifacts.count) rows.")
      return true
    } catch {
      bookmarknotArtifacts = []
      bookmarknotState = .loaded
      selectedBookmarknotID = nil
      localArtifactsAreValid = false
      services.log(.error, "Bookmarknot refresh failed: \(error)")
      dialog = .cannotLoad
      return false
    }
  }

  private func defaultSourceSelection(in artifacts: [SourceArtifact]) -> SourceArtifact.ID? {
    artifacts.first(where: { $0.status == .ready })?.id ?? artifacts.first?.id
  }
}

extension ArtifactKind {
  fileprivate var logName: String {
    switch self {
    case .chrome: "Chrome"
    case .safari: "Safari"
    case .bookmarknot: "Bookmarknot"
    }
  }
}
