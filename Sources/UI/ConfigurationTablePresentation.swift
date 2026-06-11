import AppKit
import Application
import Foundation

enum SourceArtifactOptionalColumn: String, CaseIterable {
  case created = "Created"
  case counts = "Counts"
  case size = "Size"
  case status = "Status"
}

enum SavedArtifactOptionalColumn: String, CaseIterable {
  case created = "Created"
  case counts = "Counts"
  case size = "Size"
}

enum ConfigurationTablePresentation {
  static let minimumRowHeight = 28.0
  static let resizeHandleWidth = 10.0

  static func sourceArtifactRowHeight(
    artifact: SourceArtifact,
    layout: SourceArtifactTableLayout
  ) -> Double {
    var heights = [textHeight(artifact.path, width: layout.pathWidth)]
    if layout.showCreated {
      heights.append(textHeight(createdString(artifact.createdAt), width: layout.createdWidth))
    }
    if layout.showCounts {
      heights.append(textHeight(sourceCountsString(artifact), width: layout.countsWidth))
    }
    if layout.showSize {
      heights.append(textHeight(byteCount(artifact.fileSize), width: layout.sizeWidth))
    }
    if layout.showStatus {
      heights.append(textHeight(artifact.status.rawValue, width: layout.statusWidth))
    }
    return max(minimumRowHeight, heights.max() ?? minimumRowHeight)
  }

  static func savedArtifactRowHeight(
    artifact: SavedArtifact,
    layout: SavedArtifactTableLayout
  ) -> Double {
    var heights = [textHeight(artifact.shortHash, width: layout.hashWidth, monospaced: true)]
    if layout.showCreated {
      heights.append(textHeight(createdString(artifact.createdAt), width: layout.createdWidth))
    }
    if layout.showCounts {
      heights.append(
        textHeight(
          "\(artifact.bookmarkCount) / \(artifact.folderCount)",
          width: layout.countsWidth
        )
      )
    }
    if layout.showSize {
      heights.append(textHeight(byteCount(artifact.fileSize), width: layout.sizeWidth))
    }
    return max(minimumRowHeight, heights.max() ?? minimumRowHeight)
  }

  private static func createdString(_ value: Date) -> String {
    value.formatted(date: .numeric, time: .shortened)
  }

  private static func sourceCountsString(_ artifact: SourceArtifact) -> String {
    guard let bookmarks = artifact.bookmarkCount, let folders = artifact.folderCount else {
      return "-"
    }
    return "\(bookmarks) / \(folders)"
  }

  private static func byteCount(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
  }

  private static func textHeight(
    _ value: String,
    width: Double,
    monospaced: Bool = false
  ) -> Double {
    let availableWidth = max(width - resizeHandleWidth, 1)
    let font =
      monospaced
      ? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
      : NSFont.systemFont(ofSize: NSFont.systemFontSize)
    let bounds = (value as NSString).boundingRect(
      with: NSSize(width: availableWidth, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: font]
    )
    return ceil(bounds.height)
  }
}
