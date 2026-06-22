# Full Browser Import Automation Research

Date: 2026-06-24

## Local Baseline

- macOS `26.5.1` (`25F80`)
- Safari `26.5`
- Google Chrome application metadata reported `148.0.7778.181`; the running process reported `149.0.7827.114`, so prototypes must record the live executable version rather than assume metadata is current
- both browsers were already running
- target inputs:
  - `~/Desktop/browser-chrome.html`
  - `~/Desktop/browser-safari.html`

Local `sdef` inspection confirmed:

- Safari exposes windows, tabs, JavaScript, and `show bookmarks`, but no bookmark-import command
- Chrome exposes windows, tabs, JavaScript, and bookmark objects, but no bookmark-import command

## Capability Matrix

| Mechanism | Browser-owned import UI | File panel | Primary permission | Assessment |
| --- | --- | --- | --- | --- |
| Browser AppleScript dictionary | No import verb in either installed browser | No | Automation/Apple Events | Insufficient alone |
| AppleScript + `System Events` | Yes, through menus and UI elements | Yes, through standard panel UI | Automation plus Accessibility | Strongest rapid prototype |
| Direct `AXUIElement` API | Yes | Yes | Accessibility | Strongest production candidate if UI route works |
| `CGEvent` keyboard/mouse input | Indirectly | Indirectly | Accessibility/Input Monitoring may apply | Fragile fallback for elements AX cannot invoke |
| Chrome DevTools Protocol | Web content only | No | Browser launch/debug configuration | No bookmark-import method |
| Safari WebDriver | Web content only | No | Safari Develop settings | No bookmark-import method |
| `osascript`, OSAKit, ScriptingBridge | Hosts Apple Events/scripts | Only via UI scripting | Inherits Automation/Accessibility gates | Hosting choice, not new capability |
| Helper, Automator, Shortcuts | Can host other mechanisms | Only via hosted mechanism | Permission attaches to responsible executable | Deployment choice, not new capability |

## Permission And Runtime Implications

- Sending Apple Events to `System Events`, Safari, or Chrome may trigger macOS Automation consent and can fail with Apple Event error `-1743` when denied.
- Controlling application UI requires Accessibility authorization for the responsible executable.
- Permission cannot be silently granted. The user may need to approve it in System Settings and rerun or resume.
- Permission identity matters: Terminal/`osascript`, a helper, and the final Bookmarknot executable can receive separate TCC decisions.
- GUI automation requires an unlocked interactive login session. It should reject unavailable menu bars, sheets it does not own, and timeouts instead of returning success.
- UI element roles and identifiers are preferable to fixed coordinates; localized titles remain a version and locale risk.

## Browser-Specific Findings

### Chrome

- Chromium contains a browser-owned bookmark HTML importer internally, but exposes no supported AppleScript or DevTools import command.
- The practical public route is to invoke Chrome's import menu and automate its file panel.

### Safari

- Safari officially supports importing bookmark HTML through its browser-owned File menu.
- Safari exposes no import command in its AppleScript dictionary and no public SafariServices import API.
- The practical public route is to invoke Safari's import menu and automate its file panel and any import confirmation UI.

## First Prototype Routes

1. Use AppleScript to activate the browser and `System Events` to discover and invoke the import menu item.
2. Discover the resulting standard file panel by role, enter the preselected absolute path through Go to Folder, and confirm.
3. Handle any browser-owned confirmation UI by discovered role/title.
4. Return zero only after all expected UI transitions complete; return nonzero on permission denial, missing UI, timeout, or browser rejection.
5. If `System Events` cannot address a required element, inspect it with direct Accessibility before considering synthetic coordinates.

## Primary Sources

- Apple, Automating the User Interface: https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/AutomatetheUserInterface.html
- Apple, AppleScript Language Guide: https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/index.html
- Apple, macOS Mojave Automation privacy notes: https://developer.apple.com/documentation/macos-release-notes/macos-mojave-10_14-release-notes
- Apple, Accessibility trust API: https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions
- Apple, Safari bookmark import: https://support.apple.com/guide/safari/import-bookmarks-and-passwords-ibrw1015/mac
- Chromium AppleScript design: https://www.chromium.org/developers/design-documents/applescript/
- Chromium bookmark file importer: https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/utility/importer/bookmarks_file_importer.cc
- Chrome DevTools Protocol: https://chromedevtools.github.io/devtools-protocol/
