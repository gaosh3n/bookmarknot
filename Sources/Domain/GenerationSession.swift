import Foundation

public enum GenerationSide: String, Codable, Hashable, Sendable {
  case current
  case incoming
}

public enum DecisionState: String, Codable, Hashable, Sendable {
  case unresolved
  case accepted
  case rejected
}

public enum DecisionNodeKind: String, Codable, Hashable, Sendable {
  case folder
  case leaf
}

public struct DecisionOccurrence: Identifiable, Equatable, Sendable {
  public let id: String
  public let side: GenerationSide
  public let path: [Int]
  public let depth: Int
  public let kind: DecisionNodeKind
  public let title: String
  public let url: String?
  public var state: DecisionState

  public init(
    id: String,
    side: GenerationSide,
    path: [Int],
    depth: Int,
    kind: DecisionNodeKind,
    title: String,
    url: String?,
    state: DecisionState = .unresolved
  ) {
    self.id = id
    self.side = side
    self.path = path
    self.depth = depth
    self.kind = kind
    self.title = title
    self.url = url
    self.state = state
  }
}

public struct GenerationSession: Equatable, Sendable {
  public let current: BookmarkNode?
  public let incoming: BookmarkNode?
  public private(set) var decisions: [DecisionOccurrence]

  public init(current: BookmarkNode?, incoming: BookmarkNode?) {
    self.current = current
    self.incoming = incoming
    var occurrences: [DecisionOccurrence] = []
    if let current { Self.appendOccurrences(from: current, side: .current, to: &occurrences) }
    if let incoming { Self.appendOccurrences(from: incoming, side: .incoming, to: &occurrences) }
    decisions = occurrences
  }

  public var resolvedCount: Int { decisions.count(where: { $0.state != .unresolved }) }
  public var totalCount: Int { decisions.count }
  public var isResolved: Bool { !decisions.isEmpty && resolvedCount == totalCount }
  public var hasAcceptedContent: Bool { decisions.contains(where: { $0.state == .accepted }) }

  public mutating func resolve(_ id: String, as state: DecisionState, recursively: Bool = false) {
    guard state != .unresolved, let target = decisions.first(where: { $0.id == id }) else { return }
    for index in decisions.indices {
      let candidate = decisions[index]
      let isTarget = candidate.id == id
      let isDescendant =
        recursively && candidate.side == target.side && candidate.path.starts(with: target.path)
      if isTarget || isDescendant {
        decisions[index].state = state
        if state == .accepted, let url = decisions[index].url {
          rejectCompetingURL(url, except: decisions[index].id)
        }
      }
    }
  }

  public func resolvedRoot() -> BookmarkNode? {
    guard isResolved, hasAcceptedContent else { return nil }
    var children: [BookmarkNode] = []
    if let current { children.append(contentsOf: filteredChildren(of: current, side: .current)) }
    if let incoming { children.append(contentsOf: filteredChildren(of: incoming, side: .incoming)) }
    return .folder(title: "", children: children)
  }

  private mutating func rejectCompetingURL(_ url: String, except acceptedID: String) {
    let identity = BookmarkNormalization.urlIdentity(url)
    for index in decisions.indices where decisions[index].id != acceptedID {
      let candidateIdentity = decisions[index].url.map(BookmarkNormalization.urlIdentity)
      if candidateIdentity == identity {
        decisions[index].state = .rejected
      }
    }
  }

  private func filteredChildren(of root: BookmarkNode, side: GenerationSide) -> [BookmarkNode] {
    guard case .folder(_, let children) = root else { return [] }
    return children.enumerated().compactMap { index, node in
      filtered(node, side: side, path: [index])
    }
  }

  private func filtered(_ node: BookmarkNode, side: GenerationSide, path: [Int]) -> BookmarkNode? {
    let id = Self.id(side: side, path: path)
    guard let decision = decisions.first(where: { $0.id == id }) else { return nil }
    switch node {
    case .leaf:
      return decision.state == .accepted ? node : nil
    case .folder(let title, let children):
      let acceptedChildren = children.enumerated().compactMap { index, child in
        filtered(child, side: side, path: path + [index])
      }
      if decision.state == .accepted || !acceptedChildren.isEmpty {
        return .folder(title: title, children: acceptedChildren)
      }
      return nil
    }
  }

  private static func appendOccurrences(
    from root: BookmarkNode,
    side: GenerationSide,
    to result: inout [DecisionOccurrence]
  ) {
    guard case .folder(_, let children) = root else { return }
    for (index, child) in children.enumerated() {
      append(child, side: side, path: [index], depth: 0, to: &result)
    }
  }

  private static func append(
    _ node: BookmarkNode,
    side: GenerationSide,
    path: [Int],
    depth: Int,
    to result: inout [DecisionOccurrence]
  ) {
    switch node {
    case .folder(let title, let children):
      result.append(
        DecisionOccurrence(
          id: id(side: side, path: path), side: side, path: path, depth: depth,
          kind: .folder, title: title, url: nil
        )
      )
      for (index, child) in children.enumerated() {
        append(child, side: side, path: path + [index], depth: depth + 1, to: &result)
      }
    case .leaf(let title, let url):
      result.append(
        DecisionOccurrence(
          id: id(side: side, path: path), side: side, path: path, depth: depth,
          kind: .leaf, title: title, url: url
        )
      )
    }
  }

  private static func id(side: GenerationSide, path: [Int]) -> String {
    side.rawValue + ":" + path.map(String.init).joined(separator: ".")
  }
}
