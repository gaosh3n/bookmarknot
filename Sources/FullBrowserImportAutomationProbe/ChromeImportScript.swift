let chromeScript = #"""
  on run argv
    set htmlPath to item 1 of argv
    set openedWindow to false

    with timeout of 40 seconds
      tell application "Google Chrome"
        activate
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

          set cleanupTargetFound to false
          keystroke "l" using command down
          repeat 20 times
            key code 48
            delay 0.1
            try
              set focusedElement to value of attribute "AXFocusedUIElement"
              if role of focusedElement is "AXRow" and name of focusedElement is not "Bookmarks Bar" then
                set cleanupTargetFound to true
                exit repeat
              end if
            end try
          end repeat

          if cleanupTargetFound then
            keystroke "a" using command down
            delay 0.2
            key code 51
            delay 1
          end if

          set foundOrganize to false
          repeat 10 times
            keystroke "l" using command down
            repeat 12 times
              key code 48
              delay 0.1
              try
                set focusedElement to value of attribute "AXFocusedUIElement"
                if description of focusedElement is "Organize" then
                  set foundOrganize to true
                  exit repeat
                end if
              end try
            end repeat
            if foundOrganize then exit repeat
            delay 0.5
          end repeat
          if not foundOrganize then error "Chrome Organize control was not reachable" number 80

          key code 49
          delay 0.2

          set foundImport to false
          repeat 12 times
            key code 125
            delay 0.1
            try
              set focusedElement to value of attribute "AXFocusedUIElement"
              if name of focusedElement is "Import bookmarks" then
                set foundImport to true
                exit repeat
              end if
            end try
          end repeat
          if not foundImport then error "Chrome Import bookmarks menu item was not reachable" number 81

          key code 36
          repeat 40 times
            if (count of sheets of front window) > 0 then exit repeat
            delay 0.1
          end repeat
          if (count of sheets of front window) is 0 then error "Chrome import file panel did not open" number 82

          keystroke "g" using {command down, shift down}
          delay 0.3
          keystroke htmlPath
          key code 36
          delay 0.5
          key code 36

          repeat 80 times
            if (count of sheets of front window) is 0 then exit repeat
            delay 0.1
          end repeat
          if (count of sheets of front window) is not 0 then error "Chrome import file panel did not close" number 83
        end tell
      end tell
    end timeout

    if openedWindow then
      return "Chrome automation opened one window, cleaned Bookmarks Bar, and completed import"
    end if
    return "Chrome automation reused an existing window, cleaned Bookmarks Bar, and completed import"
  end run
  """#
