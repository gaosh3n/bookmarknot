import Foundation

private enum ProbeError: Error, CustomStringConvertible {
  case usage
  case missingFile(String)
  case missingApplication(String)
  case scriptFailed(status: Int32, output: String)

  var description: String {
    switch self {
    case .usage:
      "usage: full-browser-import-automation-probe preflight|chrome|safari"
    case .missingFile(let path):
      "required bookmark HTML file does not exist: \(path)"
    case .missingApplication(let path):
      "required browser application does not exist: \(path)"
    case .scriptFailed(let status, let output):
      "automation exited with status \(status): \(output)"
    }
  }
}

private enum TargetBrowser: String {
  case chrome
  case safari

  var htmlPath: String {
    switch self {
    case .chrome:
      NSString(string: "~/Desktop/browser-chrome.html").expandingTildeInPath
    case .safari:
      NSString(string: "~/Desktop/browser-safari.html").expandingTildeInPath
    }
  }

  var applicationPath: String {
    switch self {
    case .chrome: "/Applications/Google Chrome.app"
    case .safari: "/Applications/Safari.app"
    }
  }

  var bookmarkStorePath: String {
    switch self {
    case .chrome:
      chromeBookmarkStorePath()
    case .safari:
      NSString(string: "~/Library/Safari/Bookmarks.plist").expandingTildeInPath
    }
  }

  var script: String {
    switch self {
    case .chrome: chromeScript
    case .safari: safariScript
    }
  }
}

private func chromeBookmarkStorePath() -> String {
  let chromeRoot = NSString(
    string: "~/Library/Application Support/Google/Chrome"
  ).expandingTildeInPath
  let localStateURL = URL(fileURLWithPath: chromeRoot).appendingPathComponent("Local State")
  guard
    let data = try? Data(contentsOf: localStateURL),
    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    let profile = object["profile"] as? [String: Any],
    let lastUsed = profile["last_used"] as? String,
    !lastUsed.isEmpty
  else {
    return URL(fileURLWithPath: chromeRoot)
      .appendingPathComponent("Default/Bookmarks").path
  }
  return URL(fileURLWithPath: chromeRoot)
    .appendingPathComponent(lastUsed)
    .appendingPathComponent("Bookmarks").path
}

private let safariScript = #"""
  on run argv
    set htmlPath to item 1 of argv

    with timeout of 30 seconds
      tell application "Safari" to activate
      delay 0.5

    tell application "System Events"
      tell process "Safari"
        set frontmost to true
        if role description of front window is "dialog" then
          if exists button "Done" of front window then
            click button "Done" of front window
            delay 0.3
            if role description of front window is "dialog" and exists button "Not Now" of front window then
              click button "Not Now" of front window
              delay 0.3
            end if
          else if exists button "Not Now" of front window then
            click button "Not Now" of front window
            delay 0.3
          else
            error "Safari has an unrelated dialog open" number 89
          end if
        end if

        try
          click menu item "Import Browsing Data from File or Folder…" of menu 1 of menu bar item "File" of menu bar 1
          on error
            error "Safari import menu item was not reachable" number 90
          end try

          delay 0.5
          if role description of front window is "dialog" then
            try
              click button "Choose File or Folder…" of front window
            on error
              -- A standard file panel may already be frontmost.
            end try
          end if

          repeat 40 times
            if name of front window is "Import File" then exit repeat
            delay 0.1
          end repeat
          if name of front window is not "Import File" then error "Safari Import File panel did not open" number 91

          keystroke "g" using {command down, shift down}
          delay 0.3
          keystroke htmlPath
          key code 36
          delay 0.5
          key code 36

        repeat 80 times
          if name of front window is not "Import File" then exit repeat
          delay 0.1
        end repeat
        if name of front window is "Import File" then error "Safari Import File panel did not close" number 92

        set importSucceeded to false
        repeat 80 times
          -- Safari may require password or Touch ID authorization here. This
          -- prototype cannot satisfy that challenge without the user.
          if role description of front window is "dialog" then
            if exists button "Done" of front window then
              set importSucceeded to true
              exit repeat
            end if
          end if
          delay 0.1
        end repeat
        if not importSucceeded then error "Safari did not report a successful import" number 93
        click button "Done" of front window
        repeat 40 times
          if role description of front window is "dialog" and exists button "Not Now" of front window then exit repeat
          delay 0.1
        end repeat
        if role description of front window is not "dialog" or not (exists button "Not Now" of front window) then
          error "Safari source-file retention prompt did not appear" number 94
        end if
        click button "Not Now" of front window
      end tell
    end tell
    end timeout

    return "Safari import flow completed; unattended completion was not established"
  end run
  """#

private func modificationDate(path: String) -> Date? {
  let attributes = try? FileManager.default.attributesOfItem(atPath: path)
  return attributes?[.modificationDate] as? Date
}

private func format(_ date: Date?) -> String {
  guard let date else { return "unavailable" }
  return date.formatted(.iso8601)
}

private func runAppleScript(_ source: String, arguments: [String] = []) throws -> String {
  let process = Process()
  let standardInput = Pipe()
  let combinedOutput = Pipe()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
  process.arguments = ["-"] + arguments
  process.standardInput = standardInput
  process.standardOutput = combinedOutput
  process.standardError = combinedOutput

  try process.run()
  standardInput.fileHandleForWriting.write(Data(source.utf8))
  try standardInput.fileHandleForWriting.close()
  process.waitUntilExit()

  let outputData = combinedOutput.fileHandleForReading.readDataToEndOfFile()
  let output = (String(bytes: outputData, encoding: .utf8) ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)

  guard process.terminationStatus == 0 else {
    throw ProbeError.scriptFailed(status: process.terminationStatus, output: output)
  }
  return output
}

private func validate(_ browser: TargetBrowser) throws {
  guard FileManager.default.fileExists(atPath: browser.htmlPath) else {
    throw ProbeError.missingFile(browser.htmlPath)
  }
  guard FileManager.default.fileExists(atPath: browser.applicationPath) else {
    throw ProbeError.missingApplication(browser.applicationPath)
  }
}

private func preflight() throws {
  try validate(.chrome)
  try validate(.safari)

  let permissionResult = try runAppleScript(
    #"""
    tell application "System Events"
      if not UI elements enabled then error "Accessibility permission is not enabled" number 100
      return {UI elements enabled, exists process "Safari", exists process "Google Chrome"}
    end tell
    """#)
  let chromeCleanupResult = try runAppleScript(chromeCleanupPreflightScript)

  print("preflight=passed")
  print("system-events=\(permissionResult)")
  print("chrome-cleanup-preflight=\(chromeCleanupResult)")
  for browser in [TargetBrowser.chrome, .safari] {
    print("\(browser.rawValue)-html=\(browser.htmlPath)")
    print("\(browser.rawValue)-store=\(browser.bookmarkStorePath)")
    print(
      "\(browser.rawValue)-store-modified=\(format(modificationDate(path: browser.bookmarkStorePath)))"
    )
  }
}

private func importBookmarks(into browser: TargetBrowser) throws {
  try validate(browser)
  let before = modificationDate(path: browser.bookmarkStorePath)
  let output = try runAppleScript(browser.script, arguments: [browser.htmlPath])

  // Modification time is supporting evidence only. Browser persistence may lag UI completion.
  var after = modificationDate(path: browser.bookmarkStorePath)
  for _ in 0..<20 where after == before {
    Thread.sleep(forTimeInterval: 0.25)
    after = modificationDate(path: browser.bookmarkStorePath)
  }

  print("automation=completed")
  print("browser=\(browser.rawValue)")
  print("message=\(output)")
  print("store-modified-before=\(format(before))")
  print("store-modified-after=\(format(after))")
  print("store-modification-observed=\(before != after)")
}

do {
  guard CommandLine.arguments.count == 2 else { throw ProbeError.usage }
  switch CommandLine.arguments[1] {
  case "preflight":
    try preflight()
  case "chrome":
    try importBookmarks(into: .chrome)
  case "safari":
    try importBookmarks(into: .safari)
  default:
    throw ProbeError.usage
  }
} catch {
  FileHandle.standardError.write(Data("error: \(error)\n".utf8))
  exit(1)
}
