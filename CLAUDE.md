# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

uPulls: a macOS menu-bar app (SwiftPM, AppKit + SwiftUI, macOS 14+, arm64) that shows open GitHub pull
requests for tracked repos in a popover and notifies about activity on the user's own PRs. Sister project
of `../uHosts`; same build/release/site pipeline.

## Commands

```sh
swift test                                   # unit tests (ActivityTracker, repo parsing, bot detection)
swift test --filter ActivityTrackerTests/testMutedRepoSwallowsEventsForGood   # one test
./build.sh                                   # release build + .app bundle + ad-hoc codesign → build/uPulls.app
./release.sh                                 # build + zip + RELEASE_NOTES.md → dist/
./bump.sh 1.2.0                              # bump version everywhere (plist, release.sh, README, website)
./deploy-site.sh                             # push website/index.html to vLX42/upulls-site (GitHub Pages)
```

Run a dev build without touching the Keychain (every ad-hoc rebuild changes the code identity, which makes
Keychain prompt on each launch), letting it borrow the `gh` CLI token in memory:

```sh
pkill -x uPulls; UPULLS_NO_KEYCHAIN=1 build/uPulls.app/Contents/MacOS/uPulls --open-menu &
```

Dev flags: `--fireworks`, `--open-menu`, `--settings`, `--notify-test`, `--snapshot <dir>` (writes a PNG per
app window then quits; used for headless visual checks). Seed repos for a test run with
`defaults write com.upulls.app repos -data <hex of JSON [{"fullName":"owner/repo"}]>`; reset the seen-event
state with `defaults delete com.upulls.app tracker`.

Verifying visually: `screencapture -x file.png` works once the terminal has Screen Recording permission;
CA emitter content (fireworks) only shows in real screen captures, not in `--snapshot` window captures.

## Architecture

Data flow per poll (`Monitor.performRefresh`):
`GitHubClient.fetch` (one GraphQL request, every repo an aliased `repository(...)` field so a bad repo fails
alone) → `Store.prs` / `repoErrors` → `ActivityTracker.ingest` (pure diff, returns `[Alert]`) →
`Monitor.deliver` applies user preferences (quiet bots, snooze, toggles) → `Notifier` / `Fireworks`.

- List filters and notifications share one rule: `Store.isHidden(pr)` decides both, and `Monitor.deliver`
  drops any alert whose PR is hidden. `isHidden` never hides your own PRs or ones where you are a requested
  reviewer, so those always show and always notify.
- `Store` is the single `@MainActor ObservableObject`: every setting persists in `didSet` (UserDefaults; token
  in Keychain via `Keychain.swift`). Muted repos carry `mutedUntil` (`.distantFuture` = indefinitely); global
  snooze is `snoozedUntil`. `expireTimers()` clears elapsed ones.
- `ActivityTracker` keeps seen event ids **per repo** and a per-repo `baselined` set: the first successful
  fetch of a repo is silent, a repo that errors for a round keeps its history, removing a repo forgets it.
  Muted rounds still mark events seen (mute means "don't tell me", not "queue it").
- `AppDelegate` (App.swift) owns the status item, the `NSPopover` hosting `DashboardView`, a right-click
  `NSMenu`, and the Settings window. Left click toggles the popover; a global mouse monitor closes it.
- UI is SwiftUI inside AppKit containers. The popover sizes itself via `NSHostingController.sizingOptions =
  .preferredContentSize` plus a height preference key in `DashboardView`.
- HDR fireworks: the brightness has to live in the sprite. A half-float (`RGBA16Float`) `CGImage` in
  extended linear Display P3 with premultiplied components above 1.0 activates EDR; an extended-range
  `CGColor` tint on the emitter cell does not (measured: headroom stayed at 1.0). Layers set
  `contentsFormat = .RGBA16Float`, `wantsExtendedDynamicRangeContent`, `preferredDynamicRange = .high`
  (macOS 26) and `toneMapMode = .never` (macOS 15). Clamp the gain with
  `maximumPotentialExtendedDynamicRangeColorComponentValue`, never the current value: the current one
  reads 1.0 until EDR content is already on screen. Verify with `--edr-probe`, which logs the screen's
  live headroom; it should climb above 1.0 during a volley (measured 1.00 → 10.16 on a 16x XDR panel).
- `Fireworks` uses two independent `CAEmitterLayer`s in a click-through screen-saver-level window. Keep
  `emitterShape = .rectangle`: `.line` emits nothing visible on macOS (verified). The view is flipped so
  "up" is `-π/2` and gravity is positive `yAcceleration`.

- `Updater` polls `repos/vLX42/uPulls/releases/latest`, compares with `CFBundleShortVersionString`, and installs
  by moving the running bundle aside, moving the unpacked app in, and relaunching via a `/bin/sh` that waits for
  the pid to exit. The release zip keeps a parent folder, so it searches up to three levels for the `.app`.
  End-to-end test: build, `plutil -replace CFBundleShortVersionString -string 1.0.0 build/uPulls.app/Contents/Info.plist`,
  re-sign, run with `--self-update-test`, then confirm the plist version changed and one process is running.

GraphQL notes: bots come back as `author.__typename == "Bot"` (Copilot is `copilot-pull-request-reviewer`);
`viewer` has no `__typename` in our query, so it decodes into its own struct. Timeline window is the last 20
`ISSUE_COMMENT`/`PULL_REQUEST_REVIEW` items per PR; empty `COMMENTED` reviews are ignored as noise.

## Promo video (`video/`)

Remotion 4 project, all `@remotion/*` pinned to the same version. Scenes in `src/scenes`, frame budget in
`src/constants.ts` (output = sum of scenes minus 18 frames per transition). `src/components/Popover.tsx` is a
mock of `DashboardView` with fake data (acme/…); keep it in sync when the real popover changes. Render one
frame with `npx remotion still src/index.ts UPulls out/x.jpg --frame=N`, the video with `npm run build`.

## Conventions

- Bundle id `com.upulls.app`; `LSUIElement` (no Dock icon). Version lives in `Resources/Info.plist` and is
  changed only through `bump.sh`.
- Ad-hoc signed, not notarized; README/INSTALL.txt tell users about the `xattr` step. Don't add a signing
  identity to scripts.
- Public repo `vLX42/uPulls`; homepage mirrored to public `vLX42/upulls-site`. Releases are cut by pushing a
  `v*` tag (`.github/workflows/release.yml`).
