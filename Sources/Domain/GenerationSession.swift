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

private struct GenerationPlan {
  var decisionIDs = Set<String>()
  var includedIDs = Set<String>()
}

public struct GenerationSession: Equatable, Sendable {
  public let current: BookmarkNode?
  public let incoming: BookmarkNode?
  public private(set) var decisions: [DecisionOccurrence]
  private let automaticallyIncludedIDs: Set<String>

  public init(current: BookmarkNode?, incoming: BookmarkNode?) {
    self.current = current
    self.incoming = incoming
    let plan = Self.classify(current: current, incoming: incoming)
    automaticallyIncludedIDs = plan.includedIDs
    var occurrences: [DecisionOccurrence] = []
    if let current { Self.appendOccurrences(from: current, side: .current, to: &occurrences) }
    if let incoming { Self.appendOccurrences(from: incoming, side: .incoming, to: &occurrences) }
    decisions = occurrences.filter { plan.decisionIDs.contains($0.id) }
  }

  public var resolvedCount: Int { decisions.count(where: { $0.state != .unresolved }) }
  public var totalCount: Int { decisions.count }
  public var isResolved: Bool { resolvedCount == totalCount }
  public var hasAcceptedContent: Bool {
    !automaticallyIncludedIDs.isEmpty || decisions.contains(where: { $0.state == .accepted })
  }

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
    guard let decision = decisions.first(where: { $0.id == id }) else {
      return automaticallyIncludedIDs.contains(id) ? node : nil
    }
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

  private static func classify(
    current: BookmarkNode?,
    incoming: BookmarkNode?
  ) -> GenerationPlan {
    var plan = GenerationPlan()
    switch (current, incoming) {
    case (.folder(_, let currentChildren), .folder(_, let incomingChildren)):
      classifyChildren(
        currentChildren,
        incomingChildren,
        currentParentPath: [],
        incomingParentPath: [],
        plan: &plan
      )
    case (.some(let current), nil):
      markDecisionSubtree(
        current, side: .current, path: [], decisionIDs: &plan.decisionIDs)
    case (nil, .some(let incoming)):
      markDecisionSubtree(
        incoming, side: .incoming, path: [], decisionIDs: &plan.decisionIDs)
    default:
      break
    }
    return plan
  }

  private static func classifyChildren(
    _ currentChildren: [BookmarkNode],
    _ incomingChildren: [BookmarkNode],
    currentParentPath: [Int],
    incomingParentPath: [Int],
    plan: inout GenerationPlan
  ) {
    var matchedIncoming = Set<Int>()

    for (currentIndex, currentNode) in currentChildren.enumerated() {
      let currentPath = currentParentPath + [currentIndex]
      guard
        let incomingIndex = incomingChildren.indices.first(where: {
          !matchedIncoming.contains($0) && nodesMatch(currentNode, incomingChildren[$0])
        })
      else {
        markDecisionSubtree(
          currentNode,
          side: .current,
          path: currentPath,
          decisionIDs: &plan.decisionIDs
        )
        continue
      }

      matchedIncoming.insert(incomingIndex)
      let incomingNode = incomingChildren[incomingIndex]
      let incomingPath = incomingParentPath + [incomingIndex]
      if equivalent(currentNode, incomingNode) {
        plan.includedIDs.insert(id(side: .current, path: currentPath))
        continue
      }

      plan.decisionIDs.insert(id(side: .current, path: currentPath))
      plan.decisionIDs.insert(id(side: .incoming, path: incomingPath))
      if case .folder(_, let currentDescendants) = currentNode {
        if case .folder(_, let incomingDescendants) = incomingNode {
          classifyChildren(
            currentDescendants,
            incomingDescendants,
            currentParentPath: currentPath,
            incomingParentPath: incomingPath,
            plan: &plan
          )
        }
      }
    }

    for (incomingIndex, incomingNode) in incomingChildren.enumerated()
    where !matchedIncoming.contains(incomingIndex) {
      markDecisionSubtree(
        incomingNode,
        side: .incoming,
        path: incomingParentPath + [incomingIndex],
        decisionIDs: &plan.decisionIDs
      )
    }
  }

  private static func nodesMatch(_ lhs: BookmarkNode, _ rhs: BookmarkNode) -> Bool {
    switch (lhs, rhs) {
    case (.folder(let lhsTitle, _), .folder(let rhsTitle, _)):
      return BookmarkNormalization.text(lhsTitle) == BookmarkNormalization.text(rhsTitle)
    case (.leaf(_, let lhsURL), .leaf(_, let rhsURL)):
      return BookmarkNormalization.urlIdentity(lhsURL)
        == BookmarkNormalization.urlIdentity(rhsURL)
    default:
      return false
    }
  }

  private static func equivalent(_ lhs: BookmarkNode, _ rhs: BookmarkNode) -> Bool {
    switch (lhs, rhs) {
    case (.folder(let lhsTitle, let lhsChildren), .folder(let rhsTitle, let rhsChildren)):
      guard BookmarkNormalization.text(lhsTitle) == BookmarkNormalization.text(rhsTitle) else {
        return false
      }
      guard lhsChildren.count == rhsChildren.count else { return false }
      return zip(lhsChildren, rhsChildren).allSatisfy(equivalent)
    case (.leaf, .leaf):
      // Same-identity leaves must remain explicit user decisions so mixed-source
      // generation can keep current, keep incoming, or reject both.
      return false
    default:
      return false
    }
  }

  private static func markDecisionSubtree(
    _ node: BookmarkNode,
    side: GenerationSide,
    path: [Int],
    decisionIDs: inout Set<String>
  ) {
    if !path.isEmpty {
      decisionIDs.insert(id(side: side, path: path))
    }
    guard case .folder(_, let children) = node else { return }
    for (index, child) in children.enumerated() {
      markDecisionSubtree(
        child, side: side, path: path + [index], decisionIDs: &decisionIDs)
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
