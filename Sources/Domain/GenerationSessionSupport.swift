func mergeResolvedChildren(_ children: [BookmarkNode]) -> [BookmarkNode] {
  var merged: [BookmarkNode] = []
  var folderIndexes: [String: Int] = [:]

  for child in children {
    switch child {
    case .folder(let title, let descendants):
      let key = BookmarkNormalization.text(title)
      if let index = folderIndexes[key],
        case .folder(let existingTitle, let existingDescendants) = merged[index] {
        merged[index] = .folder(
          title: existingTitle,
          children: existingDescendants + descendants
        )
      } else {
        folderIndexes[key] = merged.count
        merged.append(.folder(title: title, children: descendants))
      }
    case .leaf:
      merged.append(child)
    }
  }

  return merged.map { child in
    guard case .folder(let title, let descendants) = child else { return child }
    return .folder(title: title, children: mergeResolvedChildren(descendants))
  }
}

func isLeaf(_ node: BookmarkNode) -> Bool {
  if case .leaf = node { return true }
  return false
}

func isFolder(_ node: BookmarkNode) -> Bool {
  if case .folder = node { return true }
  return false
}

func equivalentFolderOrder(_ lhs: BookmarkNode, _ rhs: BookmarkNode) -> Bool {
  let lhsKey = equivalentFolderSortKey(lhs)
  let rhsKey = equivalentFolderSortKey(rhs)
  if lhsKey != rhsKey { return lhsKey < rhsKey }
  return String(describing: lhs) < String(describing: rhs)
}

func equivalentFolderSortKey(_ node: BookmarkNode) -> String {
  guard case .folder(let title, let children) = node else { return "" }
  return BookmarkNormalization.text(title) + ":\(children.count)"
}

func normalizedChildTreesMatch(_ lhs: [BookmarkNode], _ rhs: [BookmarkNode]) -> Bool {
  normalizedChildTreeSignatures(lhs) == normalizedChildTreeSignatures(rhs)
}

func normalizedChildTreeSignatures(_ children: [BookmarkNode]) -> [String] {
  children.map(normalizedChildTreeSignature).sorted()
}

func normalizedChildTreeSignature(_ node: BookmarkNode) -> String {
  switch node {
  case .leaf(_, let url):
    return "leaf:" + BookmarkNormalization.urlIdentity(url)
  case .folder(let title, let children):
    return "folder:" + BookmarkNormalization.text(title) + "["
      + normalizedChildTreeSignatures(children).joined(separator: "|") + "]"
  }
}

func recordCounterparts(
  currentPath: [Int],
  incomingPath: [Int],
  plan: inout GenerationPlan
) {
  let currentID = GenerationSession.id(side: .current, path: currentPath)
  let incomingID = GenerationSession.id(side: .incoming, path: incomingPath)
  plan.counterpartDecisionIDs[currentID] = incomingID
  plan.counterpartDecisionIDs[incomingID] = currentID
}

func subtreeHasResolvedContent(in session: GenerationSession, for id: String) -> Bool {
  guard let occurrence = session.decisions.first(where: { $0.id == id }) else { return false }
  let root = occurrence.side == .current ? session.current : session.incoming
  guard let root, let node = node(at: occurrence.path, in: root) else { return false }
  return subtreeNodeHasResolvedContent(
    node, side: occurrence.side, path: occurrence.path, in: session)
}

func subtreeNodeHasResolvedContent(
  _ node: BookmarkNode,
  side: GenerationSide,
  path: [Int],
  in session: GenerationSession
) -> Bool {
  let id = GenerationSession.id(side: side, path: path)
  if let decision = session.decisions.first(where: { $0.id == id }) {
    switch node {
    case .leaf:
      return decision.state == .accepted
    case .folder(_, let children):
      if decision.state == .accepted { return true }
      return children.enumerated().contains { index, child in
        subtreeNodeHasResolvedContent(child, side: side, path: path + [index], in: session)
      }
    }
  }

  return session.automaticallyIncludedIDs.contains(id)
}

func node(at path: [Int], in root: BookmarkNode) -> BookmarkNode? {
  guard !path.isEmpty else { return root }
  guard case .folder(_, let children) = root, children.indices.contains(path[0]) else {
    return nil
  }
  return node(at: Array(path.dropFirst()), in: children[path[0]])
}
