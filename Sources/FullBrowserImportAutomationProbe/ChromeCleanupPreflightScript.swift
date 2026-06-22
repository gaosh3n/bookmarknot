let chromeCleanupPreflightScript = #"""
  on closeProbeWindow(targetWindowID)
    if targetWindowID is missing value then return
    tell application "Google Chrome"
      try
        close (first window whose id is targetWindowID)
      end try
    end tell
  end closeProbeWindow

  on run
    set targetWindowID to missing value
    set openedWindow to false

    try
      with timeout of 30 seconds
        tell application "Google Chrome"
          activate
          delay 0.5
          set targetWindow to missing value
          repeat with candidateWindow in windows
            if mode of candidateWindow is "normal" then
              set targetWindow to candidateWindow
              exit repeat
            end if
          end repeat
          if targetWindow is missing value then
            set targetWindow to make new window with properties {mode:"normal"}
            set openedWindow to true
          end if
          set targetWindowID to id of targetWindow
          set URL of active tab of targetWindow to "chrome://bookmarks/?id=1"
          repeat 100 times
            if not loading of active tab of targetWindow then
              if title of active tab of targetWindow is "Bookmarks" then exit repeat
            end if
            delay 0.1
          end repeat
          if title of active tab of targetWindow is not "Bookmarks" then
            error "Chrome bookmark manager did not finish loading" number 84
          end if
          set index of targetWindow to 1
        end tell

        delay 0.5

        tell application "System Events"
          tell process "Google Chrome"
            set frontmost to true
            try
              set value of attribute "AXEnhancedUserInterface" to true
            end try
            delay 0.5

            set foundOrganize to false
            set foundBookmarksBar to false
            keystroke "l" using command down
            repeat 20 times
              key code 48
              delay 0.1
              try
                set focusedElement to value of attribute "AXFocusedUIElement"
                if description of focusedElement is "Organize" then
                  set foundOrganize to true
                end if
                if role of focusedElement is "AXRow" and name of focusedElement is "Bookmarks Bar" then
                  set foundBookmarksBar to true
                  exit repeat
                end if
              end try
            end repeat
            if not foundOrganize then error "Chrome Organize control was not reachable" number 80
            if not foundBookmarksBar then error "Chrome Bookmarks Bar row was not reachable" number 85
          end tell
        end tell
      end timeout

      if openedWindow then my closeProbeWindow(targetWindowID)
      if openedWindow then
        return "Chrome Bookmarks Bar cleanup surface is reachable; preflight opened one window"
      end if
      return "Chrome Bookmarks Bar cleanup surface is reachable; preflight reused an existing window"
    on error errorMessage number errorNumber
      if openedWindow then my closeProbeWindow(targetWindowID)
      error errorMessage number errorNumber
    end try
  end run
  """#
