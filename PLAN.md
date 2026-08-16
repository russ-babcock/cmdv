# CmdV — a modern native macOS clipboard manager

## Context

There is no clipboard manager on macOS that combines Copy 'Em's feature depth (pinned
slots, favorites, plain-vs-formatted paste, image thumbnails) with a UI that looks like
a current native macOS app. Copy 'Em's functionality is the target; its dated,
custom-drawn panel UI is not.

This project builds that app from scratch in `/Users/babcockr/Documents/Personal Dev/cmdv`
(currently an empty directory). The result is a background agent with no Dock icon that
records every copy — text, images, screenshots — into a searchable, persistent history,
opened with a global hotkey, rendered in a standard macOS window with a sidebar,
respecting light/dark/system appearance.

**Verified environment facts** (checked, not assumed):
- No Xcode — only Command Line Tools, with Swift 6.3.3 and the **macOS 26.5 SDK**.
- SwiftUI, `MenuBarExtra`, `SMAppService`, Carbon `RegisterEventHotKey`,
  `AXIsProcessTrustedWithOptions`, and `org.nspasteboard.ConcealedType` all compile
  against that SDK with `xcrun --sdk macosx swiftc` — no Xcode needed.
- GitHub is reachable; GRDB latest release is **7.11.1**.

## Decisions (from clarifying questions)

| Area | Decision |
|---|---|
| Build | SwiftPM package + `Scripts/build.sh` that assembles `CmdV.app`. Xcode-openable later. |
| Deployment target | macOS 26 Tahoe only |
| Paste | Auto-paste into the previously frontmost app via synthetic ⌘V (needs Accessibility) |
| Storage | GRDB/SQLite + image files on disk; eviction limit applies only to unpinned, unfavorited clips |
| Passwords | `ConcealedType` flag + password-manager bundle-ID list; 60s auto-purge; text shown normally |
| Pins | Manually assigned, persistent, never evicted |
| Window | Standard-looking window with `NavigationSplitView` sidebar (backed by a non-activating `NSPanel` — see below) |
| Menu bar icon | Shown by default, toggleable. Clipboard outline whose top clip is a ⌘, with a V in the body |
| Image preview | Quick Look-style overlay on Space or right-click → Preview |
| Queue mode | Click rows to paste one-by-one, window stays open; pasted rows dim with ✓ + order number |
| Signing | Stable ad-hoc identity + fixed bundle ID so Accessibility grants survive rebuilds |
| Extras in v1 | Search/type-to-filter, ignore-apps list, rich previews (URL/color/file) |

## Architecture

Three hard constraints drive the structure:

1. **`NSPasteboard` has no change notification.** The only supported detection is polling
   `changeCount`. So a single `ClipboardMonitor` owns a timer and is the sole writer of
   new clips.
2. **Auto-paste requires the *other* app to be frontmost.** The window controller captures
   `NSWorkspace.shared.frontmostApplication` *before* showing the window, and reactivates
   it before synthesizing ⌘V.
3. **Queue mode forces the window to be a non-activating panel.** Clicking a row in a
   normal window makes CmdV the active app, so the following ⌘V would be delivered to
   CmdV itself. The window is therefore an `NSPanel` with `.nonactivatingPanel` —
   visually identical to a standard titled window with a sidebar and toolbar, but clicks
   don't steal focus from the app you're pasting into.

```
Sources/CmdV/
  App/        CmdVApp.swift · AppDelegate.swift · AppEnvironment.swift
  Clipboard/  ClipboardMonitor.swift · ClipPayload.swift · ConcealedDetector.swift
              PasteboardWriter.swift · Paster.swift · PasteQueue.swift
  Storage/    Database.swift · Migrations.swift · ClipStore.swift · ImageStore.swift
  Model/      Clip.swift · ClipKind.swift · PinKey.swift
  Hotkeys/    HotkeyManager.swift · KeyCombo.swift · HotkeyRecorder.swift
  UI/         ClipboardPanel.swift · ClipboardWindowController.swift · ClipboardView.swift
              SidebarView.swift · ClipRowView.swift · RichPreview.swift
              PreviewOverlayController.swift · PreviewOverlayView.swift
  MenuBar/    MenuBarController.swift · MenuBarIcon.swift
  Settings/   Preferences.swift · SettingsView.swift + General/Hotkeys/History/Privacy panes
  Support/    LoginItem.swift · AccessibilityPermission.swift · WindowPositioner.swift
Resources/    Info.plist · AppIcon.icns · MenuBarIcon.svg
Scripts/      build.sh · run.sh · make-icons.sh
Tests/CmdVTests/
```

`AppEnvironment` is a single `@Observable` object constructed in `AppDelegate` and
injected into SwiftUI; it holds `ClipStore`, `Preferences`, `HotkeyManager`, `PasteQueue`.

### Data model — `Clip`

| Field | Purpose |
|---|---|
| `id` UUID, `createdAt`, `lastUsedAt`, `useCount` | identity + ordering |
| `kind` (`text`/`rtf`/`html`/`image`/`fileURL`) | row rendering |
| `plainText: String?` | plain-text paste + search index |
| `previewText: String` | truncated (~500 char) display string, keeps rows cheap |
| `payloadPath: String?` | binary plist of `[pasteboardType: Data]` for formatted paste |
| `imagePath` / `thumbPath` / `pixelWidth` / `pixelHeight` / `byteSize` | images + overlay preview |
| `sourceBundleID`, `sourceAppName` | ignore-list + "copied from" label |
| `isFavorite`, `pinKey: String?` (UNIQUE) | exempt from eviction |
| `isConcealed`, `expiresAt: Date?` | 60s password purge |
| `contentHash` | dedup |

Rich representations live in `~/Library/Application Support/CmdV/payloads/<uuid>.plist`
rather than as DB blobs, so list queries stay small. Images write a full-size original
plus a 128pt thumbnail into `images/` — the original is what the preview overlay and
formatted paste use. Deleting a clip deletes its files.

### Capture pipeline (`ClipboardMonitor`)

Timer at 0.25s (adjustable) → `changeCount` differs → build a `ClipPayload`:

- **Skip** if the change came from our own paste (compare stored `changeCount`),
  if `org.nspasteboard.TransientType`/`AutoGeneratedType` is present, or if the
  frontmost app's bundle ID is on the ignore list.
- **Screenshots need no special case** — ⌘⌃⇧3/4 put PNG/TIFF straight on the general
  pasteboard, so they enter through the same image branch as any other image copy.
- **Dedup**: SHA-256 over the canonical representation; if it matches the newest clip,
  bump `lastUsedAt` instead of inserting.
- **Conceal**: `ConcealedDetector` flags the clip if `org.nspasteboard.ConcealedType`
  exists, or the source bundle ID is a known password manager (1Password, Bitwarden,
  KeePassXC, Keychain Access, Dashlane, LastPass, Proton Pass, Strongbox). Sets
  `expiresAt = now + 60s`. A 5s purge timer deletes expired rows; a row shows a small
  countdown badge but its text is displayed normally, as requested.
- **Evict**: after insert, delete oldest rows `WHERE pinKey IS NULL AND isFavorite = 0`
  beyond the limit (default 50).

### Paste pipeline (`Paster`)

1. `PasteboardWriter` writes either plain text only (default) or the full stored
   representation set (right-click → "Paste with Formatting").
2. Single-paste mode: window hides, then `previousApp.activate()`.
   Queue mode: window **stays visible**, `previousApp.activate()` still runs.
3. After ~60ms, synthesize ⌘V with `CGEvent` on `.cgSessionEventTap`.
4. If `AXIsProcessTrusted()` is false, skip step 3 and show a one-click
   "Open Accessibility Settings" prompt — the clip is still on the clipboard, so
   nothing is lost.

### Queue mode (`PasteQueue`)

The workflow: copy a batch of items normally, hit ⌘⇧V, flip on Queue Mode, then click
clips one at a time in whatever order you want them to land.

- Toggled from the toolbar or with **⌘K** while the window is open.
- While active: `panel.hidesOnDeactivate = false`, `panel.level = .floating`, and the
  panel keeps `.nonactivatingPanel` behavior so each click pastes into the target app
  without the window closing or losing its place.
- Each click runs the paste pipeline above, then records the clip in `PasteQueue.history`.
- A pasted row dims, shows a ✓ and its paste-order number (1, 2, 3…), and stays clickable
  so you can repeat an item; its badge updates to the latest position.
- A toolbar counter shows "3 pasted" with a Reset that clears the badges.
- Leaving queue mode (⌘K, Esc, or closing) restores `hidesOnDeactivate` and clears badges.
- Because a non-activating panel avoids taking key focus during queue mode, type-to-filter
  is unavailable while it's on — filter the list first, then flip the mode on. The toolbar
  makes this explicit by dimming the search field.

### Image preview overlay (`PreviewOverlayController`)

- Space, or right-click → **Preview**, on the selected row.
- A borderless floating `NSPanel` with a vibrancy background, centered on the clipboard
  window, sized to fit the image within ~80% of the screen's `visibleFrame` and never
  upscaled beyond 100% for small images.
- Space, Esc, or click-outside dismisses; ↑/↓ moves through the list with the overlay
  still open, exactly like Finder's Quick Look.
- Text and file clips get the same overlay with a scrollable, selectable full-text view —
  useful for the long clips that `previewText` truncates in the list.
- Footer strip shows dimensions, file size, source app, and timestamp.

### Menu bar icon (`MenuBarIcon`)

Hand-authored SVG → PDF template asset, drawn at 18×18pt with 1.5pt strokes:
a rounded-rect clipboard body, its top clip replaced by the ⌘ loop-square glyph shape,
and a bold **V** centered in the body. Rendered as an `NSImage` with `isTemplate = true`
so macOS handles light/dark and menu bar tinting automatically.

Before it ships I'll render it at 1×/2× on light and dark menu bar backgrounds and send
you the comparison — a ⌘ at 18pt is dense, so the clip shape may need simplifying to a
bracket-and-two-loops suggestion rather than a literal glyph. The same artwork scales up
into `AppIcon.icns` via `Scripts/make-icons.sh`.

### Hotkeys

`HotkeyManager` wraps Carbon `RegisterEventHotKey` — deliberately chosen over a
`CGEventTap` because it needs **no** Accessibility permission and cannot be broken by a
revoked grant. Default ⌘⇧V. `HotkeyRecorder` is an `NSViewRepresentable` capturing
`keyDown` + `flagsChanged`; registration failure surfaces as "That shortcut is already
in use."

**Pin activation** is a bare `1`–`9`/`A`–`Z` keypress while the window is open, matching
the described flow. That conflicts with type-to-filter, so `Preferences` carries
`pinActivation: .bareKey | .controlKey`:
- `.bareKey` (default) — the list has focus; ⌘F focuses search.
- `.controlKey` — search focused on open; ⌃+key fires pins.

Assignment is via right-click → "Pin to…" or ⌘⇧+key on the selected row. Assigning an
in-use key moves it.

### UI

`ClipboardWindowController` owns a `ClipboardPanel` (`NSPanel`: `.titled`,
`.fullSizeContentView`, `.resizable`, `.nonactivatingPanel`, `becomesKeyOnlyIfNeeded`)
hosting `ClipboardView` in an `NSHostingView` — chosen over a SwiftUI `WindowGroup` for
exact positioning, reliable hiding under accessory activation policy, and the
non-activating behavior queue mode needs.

- `NavigationSplitView`: sidebar (All / Favorites / Pinned / Images / Text) + list.
- `ClipRowView`: pin badge, favorite star, source-app icon, relative timestamp, queue
  ✓/order badge; images render as thumbnails; `RichPreview` renders URLs, hex colors
  (swatch), and file paths with a Finder-style icon.
- Search filters in memory (case/diacritic-insensitive across `plainText`) — at the
  default 50-clip scale FTS5 would be pure overhead; it can be added later if the limit
  is raised into the thousands.
- Context menu: Preview · Paste as Plain Text · Paste with Formatting · Copy · Favorite ·
  Pin to… · Delete.
- Toolbar: search field, Queue Mode toggle + counter, settings gear.
- `WindowPositioner` implements the two placement modes: at the mouse cursor, or centered
  on the screen containing the mouse — both clamped to `visibleFrame` so the window is
  never partly offscreen on a multi-display setup.

### Background behavior

- `Info.plist`: `LSUIElement = true` → no Dock icon; `NSApp.setActivationPolicy(.accessory)`.
- `MenuBarExtra` via `MenuBarController`, shown by default, toggleable.
- `LoginItem` wraps `SMAppService.mainApp` (register/unregister/status), default on.
- Appearance setting maps System/Light/Dark to `NSApp.appearance`.

## Files to create

Everything is new. The load-bearing ones, in dependency order:

1. `Package.swift` — executable target `CmdV`, GRDB `.upToNextMajor(from: "7.11.0")`,
   no `.unsafeFlags` so it stays Xcode-compatible.
2. `Sources/CmdV/Storage/Database.swift`, `Migrations.swift`, `ClipStore.swift`
3. `Sources/CmdV/Clipboard/ClipboardMonitor.swift` — the core capture loop
4. `Sources/CmdV/Hotkeys/HotkeyManager.swift`
5. `Sources/CmdV/UI/ClipboardPanel.swift`, `ClipboardWindowController.swift`, `ClipboardView.swift`
6. `Sources/CmdV/Clipboard/Paster.swift`, `PasteQueue.swift`
7. `Sources/CmdV/UI/PreviewOverlayController.swift`
8. `Sources/CmdV/MenuBar/MenuBarIcon.swift` + `Resources/MenuBarIcon.svg`
9. `Sources/CmdV/Settings/*`
10. `Resources/Info.plist`, `Scripts/build.sh`

`Scripts/build.sh`: `swift build -c release` → assemble
`CmdV.app/Contents/{MacOS,Resources}` → substitute version into `Info.plist` →
`codesign --force --sign - --identifier com.babcock.cmdv` with a fixed bundle ID so
Accessibility grants persist across rebuilds. A `DEVELOPER_ID` env var swaps in a real
certificate later without touching the script's logic.

## Milestones

1. **Skeleton** — package, build script, accessory-policy app with menu bar icon; launches.
2. **Capture + storage** — monitor, GRDB schema, dedup, eviction; verified by dumping the DB.
3. **Window + list** — hotkey, positioning, sidebar, rows, thumbnails, search.
4. **Paste** — plain/formatted, focus restore, Accessibility prompt.
5. **Pins & favorites** — assignment, activation, eviction exemption.
6. **Preview overlay** — Quick Look-style panel for images and long text.
7. **Queue mode** — non-activating paste loop, ✓/order badges, toolbar counter.
8. **Settings** — all panes, hotkey recorder, login item, appearance.
9. **Privacy** — concealed detection, 60s purge, ignore-apps list.
10. **Icon + polish** — menu bar icon candidates rendered for your review, app icon,
    empty states, animations, rich previews.

## Verification

**Automated** (`swift test`, Swift Testing):
- dedup hashing; eviction spares pinned/favorited and trims the rest to the limit
- `ConcealedDetector` on flag-present, password-manager-source, and ordinary clips
- `KeyCombo` round-trips through `UserDefaults`; pin-key uniqueness reassignment
- `WindowPositioner` clamps to `visibleFrame` for cursor positions near screen edges
- `PasteQueue` order numbering, including re-pasting an already-pasted clip
- `PreviewOverlayView` sizing math: large image scales down, small image is not upscaled

**Manual checklist** after `./Scripts/build.sh && open CmdV.app`:
1. No Dock icon; menu bar icon present and legible in both light and dark menu bars.
2. ⌘C in TextEdit → clip appears; ⌘⌃⇧4 screenshot → thumbnail appears.
3. ⌘⇧V opens the window at the cursor; retest with the centered setting on a second display.
4. Type to filter; Return pastes plain text into the previously focused app.
5. Right-click → Paste with Formatting into TextEdit preserves bold/color.
6. Space on a screenshot row → large overlay; ↑/↓ walks the list; Esc closes.
7. Copy 5 lines separately, open the window, enable Queue Mode, click them in a scrambled
   order into TextEdit → they land in click order, the window never closes, and each row
   dims with the right number.
8. Pin a clip to `3`; reopen; press `3` → it pastes.
9. Favorite a clip, set the limit to 5, copy 10 things → favorite and pinned survive.
10. Copy a password from 1Password → clip appears, is gone within 60s.
11. Add an app to the ignore list → copies from it are not recorded.
12. Toggle Light/Dark/System; toggle the menu bar icon; toggle launch-at-login and confirm
    with `sfltool dumpbtm | grep -i cmdv`.
13. Revoke Accessibility → selecting a clip still copies it and shows the re-grant prompt.

## Known risks

- **Non-activating panel vs. keyboard.** A `.nonactivatingPanel` that becomes key can be
  finicky about first-responder routing. If bare-key pin activation misbehaves, the
  fallback is `becomesKeyOnlyIfNeeded = false` outside queue mode and non-activating only
  while queue mode is on — a small, contained change.
- **Accessibility grant vs. rebuilds.** Ad-hoc signatures change per build; a fixed bundle
  ID and identifier makes the grant usually stick, but macOS may still occasionally
  invalidate it. The app detects this and prompts rather than silently failing to paste.
- **⌘ glyph legibility at 18pt.** Mitigated by rendering candidates for review before the
  icon is locked in (milestone 10).
- **`SMAppService` and app location.** Login-item registration is tied to the app's path;
  moving `CmdV.app` to `/Applications` after first registering will require re-toggling.
- **Polling cost.** A 0.25s `changeCount` check is effectively free (an integer read), but
  the interval is exposed in Settings in case it ever matters.
