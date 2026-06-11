import Foundation

public enum SourceArtifactColumn: String, CaseIterable, Equatable, Sendable {
  case path
  case created
  case counts
  case size
  case status
}

public enum SavedArtifactColumn: String, CaseIterable, Equatable, Sendable {
  case shortHash
  case created
  case counts
  case size
}

public struct SourceArtifactTableLayout: Equatable, Sendable {
  public var showCreated: Bool
  public var showCounts: Bool
  public var showSize: Bool
  public var showStatus: Bool
  public var pathWidth: Double
  public var createdWidth: Double
  public var countsWidth: Double
  public var sizeWidth: Double
  public var statusWidth: Double

  public init(
    showCreated: Bool,
    showCounts: Bool,
    showSize: Bool,
    showStatus: Bool,
    pathWidth: Double,
    createdWidth: Double,
    countsWidth: Double,
    sizeWidth: Double,
    statusWidth: Double
  ) {
    self.showCreated = showCreated
    self.showCounts = showCounts
    self.showSize = showSize
    self.showStatus = showStatus
    self.pathWidth = pathWidth
    self.createdWidth = createdWidth
    self.countsWidth = countsWidth
    self.sizeWidth = sizeWidth
    self.statusWidth = statusWidth
  }

  public static let `default` = SourceArtifactTableLayout(
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

  public var visibleColumns: [SourceArtifactColumn] {
    var columns: [SourceArtifactColumn] = [.path]
    if showCreated { columns.append(.created) }
    if showCounts { columns.append(.counts) }
    if showSize { columns.append(.size) }
    if showStatus { columns.append(.status) }
    return columns
  }
}

public struct SavedArtifactTableLayout: Equatable, Sendable {
  public var showCreated: Bool
  public var showCounts: Bool
  public var showSize: Bool
  public var hashWidth: Double
  public var createdWidth: Double
  public var countsWidth: Double
  public var sizeWidth: Double

  public init(
    showCreated: Bool,
    showCounts: Bool,
    showSize: Bool,
    hashWidth: Double,
    createdWidth: Double,
    countsWidth: Double,
    sizeWidth: Double
  ) {
    self.showCreated = showCreated
    self.showCounts = showCounts
    self.showSize = showSize
    self.hashWidth = hashWidth
    self.createdWidth = createdWidth
    self.countsWidth = countsWidth
    self.sizeWidth = sizeWidth
  }

  public static let `default` = SavedArtifactTableLayout(
    showCreated: true,
    showCounts: true,
    showSize: true,
    hashWidth: 120,
    createdWidth: 120,
    countsWidth: 120,
    sizeWidth: 120
  )

  public var visibleColumns: [SavedArtifactColumn] {
    var columns: [SavedArtifactColumn] = [.shortHash]
    if showCreated { columns.append(.created) }
    if showCounts { columns.append(.counts) }
    if showSize { columns.append(.size) }
    return columns
  }
}

public struct ConfigurationLayout: Equatable, Sendable {
  public var firstDividerPosition: Double
  public var secondDividerPosition: Double
  public var chrome: SourceArtifactTableLayout
  public var safari: SourceArtifactTableLayout
  public var bookmarknot: SavedArtifactTableLayout

  public init(
    firstDividerPosition: Double,
    secondDividerPosition: Double,
    chrome: SourceArtifactTableLayout,
    safari: SourceArtifactTableLayout,
    bookmarknot: SavedArtifactTableLayout
  ) {
    self.firstDividerPosition = firstDividerPosition
    self.secondDividerPosition = secondDividerPosition
    self.chrome = chrome
    self.safari = safari
    self.bookmarknot = bookmarknot
  }

  public static let `default` = ConfigurationLayout(
    firstDividerPosition: 1.0 / 3.0,
    secondDividerPosition: 2.0 / 3.0,
    chrome: .default,
    safari: .default,
    bookmarknot: .default
  )
}

public final class ConfigurationLayoutStore {
  private struct SourceTableKeys {
    let created: String
    let counts: String
    let size: String
    let status: String
    let pathWidth: String
    let createdWidth: String
    let countsWidth: String
    let sizeWidth: String
    let statusWidth: String
  }

  private enum Key {
    static let firstDivider = "layout.firstDivider"
    static let secondDivider = "layout.secondDivider"
    static let chromeCreated = "columns.chrome.created"
    static let chromeCounts = "columns.chrome.counts"
    static let chromeSize = "columns.chrome.size"
    static let chromeStatus = "columns.chrome.status"
    static let chromePathWidth = "columns.chrome.pathWidth"
    static let chromeCreatedWidth = "columns.chrome.createdWidth"
    static let chromeCountsWidth = "columns.chrome.countsWidth"
    static let chromeSizeWidth = "columns.chrome.sizeWidth"
    static let chromeStatusWidth = "columns.chrome.statusWidth"
    static let safariCreated = "columns.safari.created"
    static let safariCounts = "columns.safari.counts"
    static let safariSize = "columns.safari.size"
    static let safariStatus = "columns.safari.status"
    static let safariPathWidth = "columns.safari.pathWidth"
    static let safariCreatedWidth = "columns.safari.createdWidth"
    static let safariCountsWidth = "columns.safari.countsWidth"
    static let safariSizeWidth = "columns.safari.sizeWidth"
    static let safariStatusWidth = "columns.safari.statusWidth"
    static let bookmarknotCreated = "columns.bookmarknot.created"
    static let bookmarknotCounts = "columns.bookmarknot.counts"
    static let bookmarknotSize = "columns.bookmarknot.size"
    static let bookmarknotHashWidth = "columns.bookmarknot.hashWidth"
    static let bookmarknotCreatedWidth = "columns.bookmarknot.createdWidth"
    static let bookmarknotCountsWidth = "columns.bookmarknot.countsWidth"
    static let bookmarknotSizeWidth = "columns.bookmarknot.sizeWidth"
  }

  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func load() -> ConfigurationLayout {
    sanitize(
      ConfigurationLayout(
        firstDividerPosition: double(
          forKey: Key.firstDivider, fallback: ConfigurationLayout.default.firstDividerPosition),
        secondDividerPosition: double(
          forKey: Key.secondDivider, fallback: ConfigurationLayout.default.secondDividerPosition),
        chrome: sourceTableLayout(
          keys: SourceTableKeys(
            created: Key.chromeCreated,
            counts: Key.chromeCounts,
            size: Key.chromeSize,
            status: Key.chromeStatus,
            pathWidth: Key.chromePathWidth,
            createdWidth: Key.chromeCreatedWidth,
            countsWidth: Key.chromeCountsWidth,
            sizeWidth: Key.chromeSizeWidth,
            statusWidth: Key.chromeStatusWidth
          )
        ),
        safari: sourceTableLayout(
          keys: SourceTableKeys(
            created: Key.safariCreated,
            counts: Key.safariCounts,
            size: Key.safariSize,
            status: Key.safariStatus,
            pathWidth: Key.safariPathWidth,
            createdWidth: Key.safariCreatedWidth,
            countsWidth: Key.safariCountsWidth,
            sizeWidth: Key.safariSizeWidth,
            statusWidth: Key.safariStatusWidth
          )
        ),
        bookmarknot: savedTableLayout()
      )
    )
  }

  @discardableResult
  public func save(_ layout: ConfigurationLayout) -> ConfigurationLayout {
    let sanitized = sanitize(layout)
    defaults.set(sanitized.firstDividerPosition, forKey: Key.firstDivider)
    defaults.set(sanitized.secondDividerPosition, forKey: Key.secondDivider)
    save(sanitized.chrome, prefix: "chrome")
    save(sanitized.safari, prefix: "safari")
    defaults.set(sanitized.bookmarknot.showCreated, forKey: Key.bookmarknotCreated)
    defaults.set(sanitized.bookmarknot.showCounts, forKey: Key.bookmarknotCounts)
    defaults.set(sanitized.bookmarknot.showSize, forKey: Key.bookmarknotSize)
    defaults.set(sanitized.bookmarknot.hashWidth, forKey: Key.bookmarknotHashWidth)
    defaults.set(sanitized.bookmarknot.createdWidth, forKey: Key.bookmarknotCreatedWidth)
    defaults.set(sanitized.bookmarknot.countsWidth, forKey: Key.bookmarknotCountsWidth)
    defaults.set(sanitized.bookmarknot.sizeWidth, forKey: Key.bookmarknotSizeWidth)
    return sanitized
  }

  private func sourceTableLayout(keys: SourceTableKeys) -> SourceArtifactTableLayout {
    SourceArtifactTableLayout(
      showCreated: bool(
        forKey: keys.created, fallback: SourceArtifactTableLayout.default.showCreated),
      showCounts: bool(
        forKey: keys.counts, fallback: SourceArtifactTableLayout.default.showCounts),
      showSize: bool(forKey: keys.size, fallback: SourceArtifactTableLayout.default.showSize),
      showStatus: bool(
        forKey: keys.status, fallback: SourceArtifactTableLayout.default.showStatus),
      pathWidth: double(
        forKey: keys.pathWidth, fallback: SourceArtifactTableLayout.default.pathWidth),
      createdWidth: double(
        forKey: keys.createdWidth, fallback: SourceArtifactTableLayout.default.createdWidth),
      countsWidth: double(
        forKey: keys.countsWidth, fallback: SourceArtifactTableLayout.default.countsWidth),
      sizeWidth: double(
        forKey: keys.sizeWidth, fallback: SourceArtifactTableLayout.default.sizeWidth),
      statusWidth: double(
        forKey: keys.statusWidth, fallback: SourceArtifactTableLayout.default.statusWidth)
    )
  }

  private func savedTableLayout() -> SavedArtifactTableLayout {
    SavedArtifactTableLayout(
      showCreated: bool(
        forKey: Key.bookmarknotCreated, fallback: SavedArtifactTableLayout.default.showCreated),
      showCounts: bool(
        forKey: Key.bookmarknotCounts, fallback: SavedArtifactTableLayout.default.showCounts),
      showSize: bool(
        forKey: Key.bookmarknotSize, fallback: SavedArtifactTableLayout.default.showSize),
      hashWidth: double(
        forKey: Key.bookmarknotHashWidth, fallback: SavedArtifactTableLayout.default.hashWidth),
      createdWidth: double(
        forKey: Key.bookmarknotCreatedWidth, fallback: SavedArtifactTableLayout.default.createdWidth
      ),
      countsWidth: double(
        forKey: Key.bookmarknotCountsWidth, fallback: SavedArtifactTableLayout.default.countsWidth),
      sizeWidth: double(
        forKey: Key.bookmarknotSizeWidth, fallback: SavedArtifactTableLayout.default.sizeWidth)
    )
  }

  private func save(_ layout: SourceArtifactTableLayout, prefix: String) {
    defaults.set(layout.showCreated, forKey: "columns.\(prefix).created")
    defaults.set(layout.showCounts, forKey: "columns.\(prefix).counts")
    defaults.set(layout.showSize, forKey: "columns.\(prefix).size")
    defaults.set(layout.showStatus, forKey: "columns.\(prefix).status")
    defaults.set(layout.pathWidth, forKey: "columns.\(prefix).pathWidth")
    defaults.set(layout.createdWidth, forKey: "columns.\(prefix).createdWidth")
    defaults.set(layout.countsWidth, forKey: "columns.\(prefix).countsWidth")
    defaults.set(layout.sizeWidth, forKey: "columns.\(prefix).sizeWidth")
    defaults.set(layout.statusWidth, forKey: "columns.\(prefix).statusWidth")
  }

  private func sanitize(_ layout: ConfigurationLayout) -> ConfigurationLayout {
    var sanitized = layout
    sanitized.firstDividerPosition = fraction(
      layout.firstDividerPosition, fallback: ConfigurationLayout.default.firstDividerPosition)
    sanitized.secondDividerPosition = fraction(
      layout.secondDividerPosition, fallback: ConfigurationLayout.default.secondDividerPosition)
    if sanitized.firstDividerPosition >= sanitized.secondDividerPosition {
      sanitized.firstDividerPosition = ConfigurationLayout.default.firstDividerPosition
      sanitized.secondDividerPosition = ConfigurationLayout.default.secondDividerPosition
    }
    sanitized.chrome = sanitize(layout.chrome)
    sanitized.safari = sanitize(layout.safari)
    sanitized.bookmarknot = sanitize(layout.bookmarknot)
    return sanitized
  }

  private func sanitize(_ layout: SourceArtifactTableLayout) -> SourceArtifactTableLayout {
    var sanitized = layout
    sanitized.pathWidth = width(
      layout.pathWidth, fallback: SourceArtifactTableLayout.default.pathWidth)
    sanitized.createdWidth = width(
      layout.createdWidth, fallback: SourceArtifactTableLayout.default.createdWidth)
    sanitized.countsWidth = width(
      layout.countsWidth, fallback: SourceArtifactTableLayout.default.countsWidth)
    sanitized.sizeWidth = width(
      layout.sizeWidth, fallback: SourceArtifactTableLayout.default.sizeWidth)
    sanitized.statusWidth = width(
      layout.statusWidth, fallback: SourceArtifactTableLayout.default.statusWidth)
    return sanitized
  }

  private func sanitize(_ layout: SavedArtifactTableLayout) -> SavedArtifactTableLayout {
    var sanitized = layout
    sanitized.hashWidth = width(
      layout.hashWidth, fallback: SavedArtifactTableLayout.default.hashWidth)
    sanitized.createdWidth = width(
      layout.createdWidth, fallback: SavedArtifactTableLayout.default.createdWidth)
    sanitized.countsWidth = width(
      layout.countsWidth, fallback: SavedArtifactTableLayout.default.countsWidth)
    sanitized.sizeWidth = width(
      layout.sizeWidth, fallback: SavedArtifactTableLayout.default.sizeWidth)
    return sanitized
  }

  private func bool(forKey key: String, fallback: Bool) -> Bool {
    guard let value = defaults.object(forKey: key) else { return fallback }
    return value as? Bool ?? fallback
  }

  private func double(forKey key: String, fallback: Double) -> Double {
    guard let value = defaults.object(forKey: key) else { return fallback }
    return value as? Double ?? fallback
  }

  private func width(_ value: Double, fallback: Double) -> Double {
    guard value.isFinite, value >= 120 else { return fallback }
    return value
  }

  private func fraction(_ value: Double, fallback: Double) -> Double {
    guard value.isFinite, value > 0, value < 1 else { return fallback }
    return value
  }
}
