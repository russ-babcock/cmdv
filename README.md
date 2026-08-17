# CmdV

A clipboard history manager for macOS. It lives in the menu bar, remembers what you
copy, and pastes any of it straight into the app you're working in — without stealing
focus along the way.

## Features

**Clipboard history.** Every copy — text, rich text, and images — is captured and
kept, with the source app recorded alongside it. Search the whole history, or filter
to Favorites, Pinned, Images, or Text.

**Pastes directly into the target app.** Picking a clip writes it to the clipboard,
returns focus to the app you came from, and synthesizes ⌘V so the text just appears.
No switching back and forth.

**Queue mode.** Turn it on and the window stays open while you click clips one at a
time, each pasting in sequence. Pasted rows dim with a ✓ and their order number, so
you can see what's left. Built for filling out a form or assembling a document from
several clips.

**Pinned clips.** Lock a clip to a key (`1`–`9`, `A`–`Z`) and recall it by pressing
that key while the window is open. Pinned clips keep their key regardless of position
and are never evicted by the history limit.

**Password-manager awareness.** Copies flagged with the standard
`org.nspasteboard.ConcealedType` marker are auto-purged after 60 seconds instead of
being kept in history. As a supplement, copies from a built-in list of known password
manager apps and browser extensions get the same treatment even when unflagged.

What that doesn't cover: the marker is authoritative, but the app list is a best-effort
deny list. A secret that arrives some other way — pasted
from a note, printed by a terminal, copied out of a password manager not on the list —
is kept like any other clip until it ages out of your history limit. Treat CmdV's
history as sensitive regardless (see [Where data is stored](#where-data-is-stored)),
and add anything you want ignored outright to **Settings → Privacy**.

**Previews.** Press Space, or right-click → Preview, for a Quick Look-style overlay.
Images and rich text render properly; arrow keys move between clips.

**Non-activating window.** The clipboard panel is an `NSPanel` that can be shown and
clicked without making CmdV the active app — which is what makes both single pastes
and queue mode land in the right place.

**Automatic updates.** CmdV checks for new versions once a day and can install them
itself, via [Sparkle](https://sparkle-project.org). Updates are cryptographically
signed, so only builds from the real signing key are ever accepted.

## Requirements

- **macOS 26.0 or later**
- Swift 6.2 toolchain (Xcode, or Command Line Tools)

## Installing

Download the latest `CmdV-x.y.z.zip` from
[Releases](https://github.com/russ-babcock/cmdv/releases), unzip it, and drag
`CmdV.app` to `/Applications`. After that CmdV keeps itself up to date — see
[Updates](#updates) below.

### Building from source

Build the app bundle and move it into place:

```bash
git clone https://github.com/russ-babcock/cmdv.git
```

```bash
cd cmdv && Scripts/build.sh --release
```

```bash
cp -R build/CmdV.app /Applications/
```

Then launch it:

```bash
open /Applications/CmdV.app
```

CmdV runs as a menu bar app with no Dock icon (`LSUIElement`). Press **⌘⇧V** to open
the clipboard window.

### Granting Accessibility access

Auto-paste synthesizes a ⌘V keystroke, which macOS only permits with Accessibility
access. CmdV prompts on first paste; you can also grant it manually under **System
Settings → Privacy & Security → Accessibility**.

Without it, everything else still works — a picked clip lands on the clipboard and you
paste it yourself.

### A note on signing

`Scripts/build.sh` signs with a stable local identity so Accessibility grants survive
rebuilds. Plain ad-hoc signing (`-`) has no certificate, so macOS can only recognize a
rebuilt binary by its exact hash — which changes every build, forcing you to re-grant
Accessibility every time.

The script looks for a local self-signed certificate named **`CmdV Local Dev`** in your
keychain and falls back to ad-hoc if it isn't found. To sign with a real Apple-issued
certificate instead:

```bash
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" Scripts/build.sh --release
```

## Updates

CmdV checks for updates once a day and offers to install them. You can also check
on demand from **Settings → General → Updates → Check Now**, or from the menu bar
icon's **Check for Updates…** item, and turn the automatic check off in the same
place.

Updates are signed with an EdDSA key whose public half is compiled into the app;
Sparkle rejects anything that doesn't verify, so a compromised download host still
can't push you a malicious build.

Publishing a release is documented in [RELEASING.md](RELEASING.md).

## Usage

Press **⌘⇧V** to open the window. Type to search, arrow keys to move, **Return** or a
click to paste.

| Shortcut | Action |
| --- | --- |
| `⌘⇧V` | Show/hide the clipboard window (configurable) |
| `Return` | Paste the selected clip |
| `Space` | Preview the selected clip |
| `⌘F` | Focus the search field |
| `⌘K` | Toggle queue mode |
| `1`–`9`, `A`–`Z` | Paste the clip pinned to that key |
| `Esc` | Close the preview, exit queue mode, or hide the window |

Right-click any clip to paste with formatting, favorite it, lock it to a key, or
delete it.

### Queue mode

Open the window, switch to the app you want to paste into, then press **⌘K**. Click
clips in the order you want them — each one pastes immediately and the window stays
open. The toolbar shows a running count with a Reset to clear the badges. **⌘K** again
or **Esc** exits.

Queue mode captures the frontmost app at the moment you turn it on, so switch to your
target app first.

## Settings

Four panes, reachable from the gear button:

- **General** — window position (at the cursor or centered), launch at login, menu bar
  icon visibility, appearance (System/Light/Dark), and update checks
- **Hotkeys** — record a different global hotkey; choose whether pinned clips activate
  on a bare keypress or require `⌃`
- **History** — how many clips to keep (default 50; favorited and locked clips are
  always kept regardless), and how often to poll the clipboard (0.25s / 0.5s / 1s)
- **Privacy** — a list of apps to ignore entirely, by bundle ID

## Where data is stored

```
~/Library/Application Support/CmdV/
  cmdv.sqlite     history database
  images/         captured images
  payloads/       rich-text payloads
```

Those directories are created owner-only (`0700`, with `0600` files), so other accounts
on the same Mac can't read your history. The database is not encrypted, though: anything
running as you can read it, and so can anyone with your unlocked machine or an unencrypted
backup of it. Turn on FileVault if that matters to you.

Your clipboard contents never leave your machine — CmdV has no telemetry, analytics, or
sync. The one thing it does talk to is its own update feed on GitHub, to check whether a
newer version exists and download it; that can be switched off in **Settings → General →
Updates**.

## Development

```bash
swift build
```

Run the tests through the wrapper script, which points at the Swift Testing framework
that ships with Command Line Tools:

```bash
Scripts/test.sh
```

Plain `swift test` works too if you have full Xcode installed.

Regenerate the app icon after changing `Scripts/GenerateAppIcon.swift`:

```bash
Scripts/make-icons.sh
```

`PLAN.md` documents the architecture and the constraints that drove it — clipboard
polling, focus handling, and why the window is a non-activating panel.

## License

MIT — see [LICENSE](LICENSE).
