import Foundation

public enum BrowserKind: String, CaseIterable, Codable, Hashable, Sendable {
  case chrome = "Chrome"
  case safari = "Safari"
}

public indirect enum BookmarkNode: Equatable, Sendable {
  case folder(title: String, children: [BookmarkNode])
  case leaf(title: String, url: String)

  public var title: String {
    switch self {
    case .folder(let title, _), .leaf(let title, _): title
    }
  }
}

public indirect enum CanonicalBookmarkNode: Equatable, Sendable {
  case folder(uuid: String, title: String, children: [CanonicalBookmarkNode])
  case leaf(uuid: String, url: String, title: String)

  public var uuid: String {
    switch self {
    case .folder(let uuid, _, _), .leaf(let uuid, _, _): uuid
    }
  }

  public var title: String {
    switch self {
    case .folder(_, let title, _), .leaf(_, _, let title): title
    }
  }

  public var bookmarkCount: Int {
    switch self {
    case .leaf: 1
    case .folder(_, _, let children): children.reduce(0) { $0 + $1.bookmarkCount }
    }
  }

  public var folderCount: Int {
    switch self {
    case .leaf: 0
    case .folder(_, _, let children):
      children.reduce(0) { $0 + $1.folderCount + ($1.isFolder ? 1 : 0) }
    }
  }

  private var isFolder: Bool {
    if case .folder = self { return true }
    return false
  }

  public var bookmarkNode: BookmarkNode {
    switch self {
    case .folder(_, let title, let children):
      .folder(title: title, children: children.map(\.bookmarkNode))
    case .leaf(_, let url, let title):
      .leaf(title: title, url: url)
    }
  }
}

public struct CanonicalArtifact: Equatable, Sendable {
  public let root: CanonicalBookmarkNode
  public let data: Data

  public init(root: CanonicalBookmarkNode, data: Data) {
    self.root = root
    self.data = data
  }

  public var bookmarkCount: Int { root.bookmarkCount }
  public var folderCount: Int { root.folderCount }
}

public enum ArtifactError: Error, Equatable, CustomStringConvertible, Sendable {
  case emptyFolderTitle
  case emptyURL
  case invalidRoot
  case malformedArtifact
  case nonCanonicalArtifact

  public var description: String {
    switch self {
    case .emptyFolderTitle: "Folder titles cannot be empty."
    case .emptyURL: "Bookmark URLs cannot be empty."
    case .invalidRoot: "The artifact root must be an anonymous folder."
    case .malformedArtifact: "The artifact JSON is malformed."
    case .nonCanonicalArtifact: "The artifact is not canonical."
    }
  }
}

public enum BookmarkNormalization {
  public static func text(_ value: String) -> String {
    value
      .precomposedStringWithCanonicalMapping
      .folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
  }

  public static func urlIdentity(_ value: String) -> String {
    guard let separator = value.range(of: "://") else { return value }
    let scheme = String(value[..<separator.lowerBound])
    guard !scheme.isEmpty,
      scheme.allSatisfy({
        $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == ".")
      })
    else {
      return value
    }

    let loweredScheme = scheme.lowercased()
    let remainderStart = separator.upperBound
    let remainder = value[remainderStart...]
    let authorityEnd =
      remainder.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? value.endIndex
    let authority = String(value[remainderStart..<authorityEnd])
    guard !authority.isEmpty else { return value }

    let atIndex = authority.lastIndex(of: "@")
    let userInfo = atIndex.map { String(authority[...$0]) } ?? ""
    let hostPortStart = atIndex.map { authority.index(after: $0) } ?? authority.startIndex
    let hostPort = String(authority[hostPortStart...])
    let normalizedHostPort = normalizeHostPort(hostPort, scheme: loweredScheme)
    let suffix = String(value[authorityEnd...])
    return loweredScheme + "://" + userInfo + normalizedHostPort + suffix
  }

  private static func normalizeHostPort(_ value: String, scheme: String) -> String {
    if value.hasPrefix("["), let close = value.firstIndex(of: "]") {
      let host = String(value[...close]).lowercased()
      let tail = String(value[value.index(after: close)...])
      return host + removeDefaultPort(tail, scheme: scheme)
    }

    guard let colon = value.lastIndex(of: ":") else { return value.lowercased() }
    let port = String(value[value.index(after: colon)...])
    guard !port.isEmpty, port.allSatisfy(\.isNumber) else { return value.lowercased() }
    let host = String(value[..<colon]).lowercased()
    let suffix = removeDefaultPort(":" + port, scheme: scheme)
    return host + suffix
  }

  private static func removeDefaultPort(_ value: String, scheme: String) -> String {
    if (scheme == "http" && value == ":80") || (scheme == "https" && value == ":443") {
      return ""
    }
    return value
  }
}

public struct ArtifactCanonicalizer: Sendable {
  public typealias MD5 = @Sendable (Data) -> String
  private let md5: MD5

  public init(md5: @escaping MD5) {
    self.md5 = md5
  }

  public func canonicalize(_ root: BookmarkNode) throws -> CanonicalArtifact {
    guard case .folder(let title, let children) = root, title.isEmpty else {
      throw ArtifactError.invalidRoot
    }

    var seenURLs = Set<String>()
    let canonicalChildren = try canonicalizeChildren(children, path: [], seenURLs: &seenURLs)
    let rootUUID = digest("folder:")
    let canonicalRoot = CanonicalBookmarkNode.folder(
      uuid: rootUUID, title: "", children: canonicalChildren)
    let string = serialize(canonicalRoot, depth: 0) + "\n"
    return CanonicalArtifact(root: canonicalRoot, data: Data(string.utf8))
  }

  public func decodeAndValidate(_ data: Data) throws -> CanonicalArtifact {
    let decoded: CanonicalBookmarkNode
    do {
      decoded = try JSONDecoder().decode(CanonicalNodeDTO.self, from: data).node
    } catch {
      throw ArtifactError.malformedArtifact
    }
    let rebuilt = try canonicalize(decoded.bookmarkNode)
    guard rebuilt.root == decoded, rebuilt.data == data else {
      throw ArtifactError.nonCanonicalArtifact
    }
    return rebuilt
  }

  private func canonicalizeChildren(
    _ children: [BookmarkNode],
    path: [String],
    seenURLs: inout Set<String>
  ) throws -> [CanonicalBookmarkNode] {
    var mergedFolders: [(title: String, children: [BookmarkNode])] = []
    var folderIndexes: [String: Int] = [:]
    var leaves: [BookmarkNode] = []

    for child in children {
      switch child {
      case .folder(let title, let descendants):
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          throw ArtifactError.emptyFolderTitle
        }
        let key = BookmarkNormalization.text(title)
        if let index = folderIndexes[key] {
          mergedFolders[index].children.append(contentsOf: descendants)
        } else {
          folderIndexes[key] = mergedFolders.count
          mergedFolders.append((title, descendants))
        }
      case .leaf:
        leaves.append(child)
      }
    }

    var result: [CanonicalBookmarkNode] = []
    for folder in mergedFolders {
      let normalizedSegment = BookmarkNormalization.text(folder.title)
      let childPath = path + [normalizedSegment]
      let descendants = try canonicalizeChildren(
        folder.children, path: childPath, seenURLs: &seenURLs)
      result.append(
        .folder(
          uuid: digest("folder:" + childPath.joined(separator: "\u{1F}")),
          title: folder.title,
          children: descendants
        )
      )
    }

    for leaf in leaves {
      guard case .leaf(let rawTitle, let url) = leaf else { continue }
      guard !url.isEmpty else { throw ArtifactError.emptyURL }
      let identity = BookmarkNormalization.urlIdentity(url)
      guard seenURLs.insert(identity).inserted else { continue }
      let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? url : rawTitle
      result.append(.leaf(uuid: digest("leaf:" + identity), url: url, title: title))
    }

    return result.sorted(by: canonicalOrder)
  }

  private func canonicalOrder(_ lhs: CanonicalBookmarkNode, _ rhs: CanonicalBookmarkNode) -> Bool {
    let lhsFolder = isFolder(lhs)
    let rhsFolder = isFolder(rhs)
    if lhsFolder != rhsFolder { return lhsFolder }
    let lhsTitle = BookmarkNormalization.text(lhs.title)
    let rhsTitle = BookmarkNormalization.text(rhs.title)
    if lhsTitle != rhsTitle { return lhsTitle < rhsTitle }
    if case .leaf(_, let lhsURL, _) = lhs, case .leaf(_, let rhsURL, _) = rhs {
      let normalizedLHS = BookmarkNormalization.text(lhsURL)
      let normalizedRHS = BookmarkNormalization.text(rhsURL)
      if normalizedLHS != normalizedRHS { return normalizedLHS < normalizedRHS }
    }
    return lhs.uuid < rhs.uuid
  }

  private func isFolder(_ node: CanonicalBookmarkNode) -> Bool {
    if case .folder = node { return true }
    return false
  }

  private func digest(_ string: String) -> String {
    md5(Data(string.utf8))
  }

  private func serialize(_ node: CanonicalBookmarkNode, depth: Int) -> String {
    let indent = String(repeating: "  ", count: depth)
    let fieldIndent = String(repeating: "  ", count: depth + 1)
    switch node {
    case .folder(let uuid, let title, let children):
      let childIndent = String(repeating: "  ", count: depth + 2)
      let serializedChildren = children.map {
        childIndent + serialize($0, depth: depth + 2).dropLeadingIndent(childIndent)
      }
      .joined(separator: ",\n")
      let childrenValue =
        children.isEmpty ? "[]" : "[\n" + serializedChildren + "\n" + fieldIndent + "]"
      return """
        \(indent){
        \(fieldIndent)"WebBookmarkType": "WebBookmarkTypeList",
        \(fieldIndent)"WebBookmarkUUID": \(jsonString(uuid)),
        \(fieldIndent)"Title": \(jsonString(title)),
        \(fieldIndent)"Children": \(childrenValue)
        \(indent)}
        """
    case .leaf(let uuid, let url, let title):
      return """
        \(indent){
        \(fieldIndent)"WebBookmarkType": "WebBookmarkTypeLeaf",
        \(fieldIndent)"WebBookmarkUUID": \(jsonString(uuid)),
        \(fieldIndent)"URLString": \(jsonString(url)),
        \(fieldIndent)"URIDictionary": {
        \(fieldIndent)  "title": \(jsonString(title))
        \(fieldIndent)}
        \(indent)}
        """
    }
  }

  private func jsonString(_ value: String) -> String {
    var result = "\""
    for scalar in value.unicodeScalars {
      switch scalar.value {
      case 0x22: result += "\\\""
      case 0x5C: result += "\\\\"
      case 0x08: result += "\\b"
      case 0x0C: result += "\\f"
      case 0x0A: result += "\\n"
      case 0x0D: result += "\\r"
      case 0x09: result += "\\t"
      case 0...0x1F: result += String(format: "\\u%04x", scalar.value)
      default: result.unicodeScalars.append(scalar)
      }
    }
    return result + "\""
  }
}

private struct CanonicalNodeDTO: Decodable {
  let node: CanonicalBookmarkNode

  private enum CodingKeys: String, CodingKey {
    case type = "WebBookmarkType"
    case uuid = "WebBookmarkUUID"
    case title = "Title"
    case children = "Children"
    case url = "URLString"
    case uriDictionary = "URIDictionary"
  }

  private enum URIKeys: String, CodingKey { case title }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    let uuid = try container.decode(String.self, forKey: .uuid)
    switch type {
    case "WebBookmarkTypeList":
      let title = try container.decode(String.self, forKey: .title)
      let children = try container.decode([CanonicalNodeDTO].self, forKey: .children).map(\.node)
      node = .folder(uuid: uuid, title: title, children: children)
    case "WebBookmarkTypeLeaf":
      let url = try container.decode(String.self, forKey: .url)
      let uri = try container.nestedContainer(keyedBy: URIKeys.self, forKey: .uriDictionary)
      node = .leaf(uuid: uuid, url: url, title: try uri.decode(String.self, forKey: .title))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: container, debugDescription: "Unknown node type")
    }
  }
}

extension String {
  fileprivate func dropLeadingIndent(_ indent: String) -> String {
    hasPrefix(indent) ? String(dropFirst(indent.count)) : self
  }
}
