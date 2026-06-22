import Foundation

public struct BookmarkHTMLExporter: Sendable {
  public init() {}

  public func export(_ root: CanonicalBookmarkNode) -> Data {
    Data(serialize(root).utf8)
  }

  public func exportString(_ root: CanonicalBookmarkNode) -> String {
    serialize(root)
  }

  private func serialize(_ root: CanonicalBookmarkNode) -> String {
    let writer = HTMLWriter()
    return writer.serialize(root)
  }
}

private struct HTMLWriter {
  private let newline = "\r\n"
  private let indentSize = 4

  func serialize(_ root: CanonicalBookmarkNode) -> String {
    var lines: [String] = []
    lines.append("<!DOCTYPE NETSCAPE-Bookmark-file-1>")
    lines.append("<!-- This is an automatically generated file.")
    lines.append("     It will be read and overwritten.")
    lines.append("     DO NOT EDIT! -->")
    lines.append("<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">")
    lines.append("<TITLE>Bookmarks</TITLE>")
    lines.append("<H1>Bookmarks</H1>")
    lines.append("<DL><p>")

    if case .folder(_, _, let children) = root {
      lines.append(
        indent(1)
          + "<DT><H3 ADD_DATE=\"0\" LAST_MODIFIED=\"0\" PERSONAL_TOOLBAR_FOLDER=\"true\">Bookmarks bar</H3>"
      )
      lines.append(indent(1) + "<DL><p>")
      for child in children {
        append(node: child, indentLevel: 2, lines: &lines)
      }
      lines.append(indent(1) + "</DL><p>")
    }

    lines.append("</DL><p>")
    return lines.joined(separator: newline) + newline
  }

  private func append(node: CanonicalBookmarkNode, indentLevel: Int, lines: inout [String]) {
    switch node {
    case .folder(_, let title, let children):
      lines.append(
        indent(indentLevel) + "<DT><H3 ADD_DATE=\"0\" LAST_MODIFIED=\"0\">"
          + escapeText(title) + "</H3>"
      )
      lines.append(indent(indentLevel) + "<DL><p>")
      for child in children {
        append(node: child, indentLevel: indentLevel + 1, lines: &lines)
      }
      lines.append(indent(indentLevel) + "</DL><p>")
    case .leaf(_, let url, let title):
      lines.append(
        indent(indentLevel) + "<DT><A HREF=\"" + escapeAttribute(url) + "\" ADD_DATE=\"0\">"
          + escapeText(title) + "</A>"
      )
    }
  }

  private func indent(_ level: Int) -> String {
    String(repeating: " ", count: level * indentSize)
  }

  private func escapeText(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

  private func escapeAttribute(_ value: String) -> String {
    escapeText(value)
  }
}
