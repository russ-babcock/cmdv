# Releasing CmdV

CmdV updates itself with [Sparkle](https://sparkle-project.org). Shipped copies
poll a static appcast on GitHub Pages once a day and download new builds from
GitHub Releases.

```
Scripts/release.sh 0.2.0
        │
        ├─ builds + signs CmdV.app          (Scripts/build.sh --release)
        ├─ notarizes + staples              (Apple notary service)
        ├─ zips + signs with EdDSA key      (Sparkle sign_update)
        ├─ adds an <item> to docs/appcast.xml
        ├─ commits + tags + pushes          → GitHub Pages serves the feed
        └─ uploads the zip                  → GitHub Releases hosts the download
```

## One-time setup

### 1. Sparkle signing key — done

An EdDSA key pair was generated with Sparkle's `generate_keys`. The **private
key lives in the login Keychain** of this machine (item: "Private key for signing
Sparkle updates") and nowhere else. The public half is in `Resources/Info.plist`
as `SUPublicEDKey`.

Sparkle refuses any update it can't verify against that public key, which is
what makes it safe to serve updates over a plain static feed. Two consequences:

- The private key **has been backed up** off this machine, to the maintainer's
  password manager. Keep it that way: losing it means no existing install can
  ever be updated again — every user would have to download a fresh copy by
  hand. To export it again:
  `.build/artifacts/sparkle/Sparkle/bin/generate_keys -x cmdv-sparkle-key.txt`
- Never commit the exported key. `.gitignore` covers the default filename, but
  the export is a live signing credential — delete it once it is safely stored.

### 2. GitHub Pages

Enable Pages for the repo: **Settings → Pages → Source: Deploy from a branch →
`main` / `/docs`**. That publishes `docs/appcast.xml` at
`https://russ-babcock.github.io/cmdv/appcast.xml`, which is the `SUFeedURL` baked
into the app. Changing that URL later strands every already-shipped copy, so
treat it as permanent.

### 3. Developer ID and notarization

Without notarization macOS quarantines the download and shows "CmdV is damaged
and can't be opened" to anyone who isn't you. To fix that properly:

1. Enroll in the Apple Developer Program ($99/yr).
2. Create a **Developer ID Application** certificate and install it in the login
   Keychain.
3. Create an app-specific password at appleid.apple.com, then store notary
   credentials once:

   ```bash
   xcrun notarytool store-credentials cmdv-notary --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PASSWORD
   ```

4. Export the identity when releasing:

   ```bash
   export DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
   ```

`release.sh` notarizes only when `DEVELOPER_ID` is set; otherwise it warns
loudly and produces a build that requires users to clear quarantine by hand.

## Cutting a release

```bash
export DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
Scripts/release.sh 0.2.0 --notes-file NOTES.md
```

Rehearse first with `--dry-run`, which builds, notarizes nothing, signs the zip
and writes the appcast entry without committing, tagging, or uploading. Discard
the entry it wrote with `git checkout docs/appcast.xml` — leaving it in place
would publish a download link to a release that was never uploaded.

Version numbers: the argument is the marketing version
(`CFBundleShortVersionString`). The build number (`CFBundleVersion`) is a
timestamp generated at release time, and that is what Sparkle actually compares
to decide whether an update is newer. Tags are immutable — `release.sh` refuses
to reuse one. To fix a broken release, bump the patch version.

## What users see

- A daily background check; the interval is `SUScheduledCheckInterval` in
  `Info.plist`.
- **Settings → General → Updates** for the version, last check time, a "Check
  Now" button, and an automatic-check toggle.
- **Menu bar icon → Check for Updates…** for an on-demand check.

The first install is still a manual download — Sparkle only takes over after
that. If you skipped notarization, first-run instructions for users are:

```bash
xattr -dr com.apple.quarantine /Applications/CmdV.app
```

## If an update ever fails to install

Sparkle replaces the app bundle in place, so the app must be writable by the
user and not running from a read-only volume (i.e. installed in `/Applications`
or `~/Applications`, not left inside a mounted disk image). Sparkle logs to the
system log under the `org.sparkle-project.Sparkle` subsystem:

```bash
log stream --predicate 'subsystem == "org.sparkle-project.Sparkle"' --level debug
```
