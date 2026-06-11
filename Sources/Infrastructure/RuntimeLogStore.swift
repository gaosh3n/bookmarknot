import Application
import Combine
import Foundation

final class RuntimeLogStore {
  private let fileManager: FileManager
  private let file: URL
  private let subject = PassthroughSubject<String, Never>()

  var updates: AnyPublisher<String, Never> {
    subject.eraseToAnyPublisher()
  }

  init(fileManager: FileManager, file: URL) {
    self.fileManager = fileManager
    self.file = file
  }

  func read() -> String {
    (try? String(contentsOf: file, encoding: .utf8)) ?? ""
  }

  func clean() throws {
    let handle = try writableHandle()
    defer { try? handle.close() }
    try handle.truncate(atOffset: 0)
    subject.send("")
  }

  func append(level: RuntimeLogLevel, message: String) throws {
    let handle = try writableHandle()
    defer { try? handle.close() }
    try handle.seekToEnd()
    let timestamp = ISO8601DateFormatter().string(from: Date())
    try handle.write(contentsOf: Data("[\(timestamp)] [\(level.rawValue)] \(message)\n".utf8))
    subject.send(read())
  }

  private func writableHandle() throws -> FileHandle {
    try ensureDirectory()
    if !fileManager.fileExists(atPath: file.path) {
      fileManager.createFile(atPath: file.path, contents: Data())
    }
    return try FileHandle(forWritingTo: file)
  }

  private func ensureDirectory() throws {
    try fileManager.createDirectory(
      at: file.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
  }
}
