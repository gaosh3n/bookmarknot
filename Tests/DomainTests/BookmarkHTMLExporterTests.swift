import Testing

@testable import Domain

private let htmlExporterCanonicalizer = ArtifactCanonicalizer { data in
  "md5[\(String(data: data, encoding: .utf8) ?? "")]"
}

@Test
func htmlExporterUsesSharedNetscapeStyleStructureForFoldersAndLinks() throws {
  var children: [BookmarkNode] = []
  children.append(
    .folder(
      title: "Folder",
      children: [.leaf(title: "OpenAI", url: "https://openai.com")]
    )
  )
  children.append(.leaf(title: "Example", url: "https://example.com"))
  let artifact = try htmlExporterCanonicalizer.canonicalize(
    .folder(title: "", children: children)
  )

  let html = BookmarkHTMLExporter().exportString(artifact.root)

  #expect(html.contains("<!DOCTYPE NETSCAPE-Bookmark-file-1>\r\n"))
  #expect(
    html.contains(
      "<DT><H3 ADD_DATE=\"0\" LAST_MODIFIED=\"0\" PERSONAL_TOOLBAR_FOLDER=\"true\">Bookmarks bar</H3>"
    )
  )
  #expect(html.contains("<DT><H3 ADD_DATE=\"0\" LAST_MODIFIED=\"0\">Folder</H3>"))
  #expect(html.contains("<DT><A HREF=\"https://example.com\" ADD_DATE=\"0\">Example</A>"))
  #expect(html.contains("<DT><A HREF=\"https://openai.com\" ADD_DATE=\"0\">OpenAI</A>"))
}

@Test
func htmlExporterEscapesTitlesAndURLsAndEndsWithCRLF() throws {
  let artifact = try htmlExporterCanonicalizer.canonicalize(
    .folder(
      title: "",
      children: [
        .leaf(title: "Fish & Chips <Best>", url: "https://example.com?a=1&b=2")
      ]
    )
  )

  let html = BookmarkHTMLExporter().exportString(artifact.root)

  #expect(
    html.contains(
      "<DT><A HREF=\"https://example.com?a=1&amp;b=2\" ADD_DATE=\"0\">Fish &amp; Chips &lt;Best&gt;</A>"
    )
  )
  #expect(html.hasSuffix("\r\n"))
}
