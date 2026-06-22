# Bookmarknot

Bookmarknot combines browser bookmark sources into app-owned artifacts and can derive browser-importable exports from them.

## Language

**Browser bookmark store**:
The browser-owned native storage whose modification time can provide evidence that a browser automation run wrote bookmark state.
_Avoid_: Browser bookmark artifact, JSON artifact

**Bookmarknot artifact**:
An app-owned canonical bookmark tree produced by Bookmarknot, distinct from any browser's native bookmark store.
_Avoid_: Browser bookmark store, browser-native artifact

**Target browser profile**:
The user's existing logged-in Chrome or Safari profile selected to receive a browser-importable export. Automation must not substitute a disposable or newly-created profile.
_Avoid_: Test profile, temporary profile

**Interactive authorization**:
A password or biometric challenge that the user must satisfy during a browser import run. It is distinct from granting macOS Automation or Accessibility permission before the run.
_Avoid_: Permission grant, automation consent

**Full browser import automation**:
A browser import in which Bookmarknot drives the browser-owned flow to completion without human interaction after required macOS permissions are granted.
_Avoid_: Assisted browser import, guided handoff

**Assisted browser import**:
A browser import in which Bookmarknot automates the complete browser-owned flow except for an interactive authorization challenge that the user explicitly satisfies.
_Avoid_: Full automation, guided handoff

**Same-file import idempotence**:
The guarantee that importing the same final-version bookmark HTML into the same target browser profile repeatedly leaves the browser bookmark tree unchanged after the first successful import.
_Avoid_: Duplicate tolerance, repeated-import support
