# uPulls

Open GitHub pull requests in your menu bar. One glance, no clicking around.

- **1.3 MB** app bundle, **~50 MB** RAM with avatars loaded
- Native `arm64`, AppKit status item with a SwiftUI popover
- Every tracked repo and its open PRs visible at once: review state, CI, author, age
- Your own PRs stand out; PRs waiting on your review get a `review` pill
- Notifications when someone comments on, requests changes to, or approves your PR
- 🎆 Fireworks when a PR of yours gets approved (tunable, testable)
- Mute a repo for an hour, until tomorrow, or indefinitely; snooze everything for a break
- Hides Dependabot/Renovate PRs, ignores Copilot and other bot chatter by default
- Picks up the `gh` CLI token automatically, or takes a personal access token

Built because every "PR dashboard" is either a browser tab or an Electron app.

## Install

Grab the latest `uPulls-X.Y.Z.zip` from [Releases](https://github.com/vLX42/uPulls/releases),
then:

```sh
unzip uPulls-*.zip
mv uPulls.app /Applications/
xattr -d com.apple.quarantine /Applications/uPulls.app
open /Applications/uPulls.app
```

The `xattr` step bypasses Gatekeeper, which blocks the app on first launch
because this build is ad-hoc signed (no paid Apple Developer Program
membership, hence no notarization). You only need to run it once.

**Requires:** macOS 14 (Sonoma) or later, Apple Silicon.

## Using it

Click the pull-request icon in the menu bar:

- Each repo is a section; each row is an open PR. Click a row to open it on GitHub.
- The dot says where review stands: green approved, red changes requested, grey waiting, dashed draft.
- ✓ / ✕ / ● after the title is CI: passing, failing, running.
- Bold title + ringed avatar = your PR. Orange `review` pill = they want you.
- Bell on a repo row: mute for 1 hour, until tomorrow, indefinitely, or remove the repo.
- Bell in the header: snooze all notifications. `+` / gear: manage repos and settings.
- Right-click the menu bar icon for Refresh, Settings, Launch at Login, Quit.

**Connecting GitHub.** On first launch uPulls tries `gh auth token`. If you don't use
the GitHub CLI, create a classic token with the `repo` scope (or a fine-grained token
with *Pull requests: read* on the repos you track) and paste it in Settings. The token
is stored in the login Keychain.

**Notifications** fire only for activity on PRs you authored (plus review requests
aimed at you), only for events that happen after a repo was added, and never while a
repo is muted or everything is snoozed. Bot activity (Copilot reviews, github-actions)
is ignored unless you turn *Quiet bots* off.

**Fireworks** have their own section in Settings: duration, intensity, spark size,
spread, and a *Test fireworks* button (⌘T) so you can tune them.

## Build from source

```sh
git clone https://github.com/vLX42/uPulls.git
cd uPulls
swift test               # diff logic, repo parsing, bot detection
./build.sh               # produces build/uPulls.app
./release.sh             # produces dist/uPulls-1.0.0.zip
```

`swift build` handles compilation; `build.sh` wraps the binary in a proper
`.app` bundle and ad-hoc signs it.

Dev flags (pass after `--args` with `open`, or directly to the binary):
`--fireworks` fires on launch, `--open-menu` opens the popover, `--settings`
opens Settings, `--notify-test` posts a sample notification,
`--snapshot <dir>` writes PNGs of the app's windows and quits.
`UPULLS_NO_KEYCHAIN=1` keeps the token in memory (avoids the Keychain prompt
that every ad-hoc rebuild triggers).

## Project layout

```
.
├── Package.swift                  SwiftPM manifest (app + tests)
├── Sources/uPulls/
│   ├── App.swift                  @main NSApplication, status item, popover, context menu
│   ├── DashboardView.swift        The popover (SwiftUI)
│   ├── SettingsView.swift         Token, repos, notifications, fireworks tuning
│   ├── Store.swift                Settings + live state (UserDefaults / Keychain)
│   ├── Monitor.swift              Poll loop: fetch → diff → notify
│   ├── GitHubClient.swift         One GraphQL request per refresh
│   ├── ActivityTracker.swift      Which events are new (pure, tested)
│   ├── Notifier.swift             UNUserNotificationCenter wrapper
│   ├── Fireworks.swift            CAEmitterLayer overlay
│   ├── Models.swift               PullRequest, TrackedRepo, …
│   ├── Keychain.swift / GHCLI.swift / LaunchAtLogin.swift / DebugSnapshot.swift
├── Tests/uPullsTests/             XCTest
├── Resources/Info.plist           Bundle metadata (LSUIElement, version)
├── build.sh                       Compile + bundle .app
├── release.sh                     Build + zip + release notes
├── bump.sh                        Update version string in every file
├── deploy-site.sh                 Push website/ to the public Pages mirror
├── website/index.html             Homepage (vLX42/upulls-site → GitHub Pages)
├── INSTALL.txt                    Shipped inside the release zip
└── .github/workflows/
    ├── build.yml                  Test + build on every push/PR
    └── release.yml                Build + publish on v* tag push
```

## Hosting

- **Source:** this repo, [`vLX42/uPulls`](https://github.com/vLX42/uPulls).
- **Homepage:** mirrored to [`vLX42/upulls-site`](https://github.com/vLX42/upulls-site)
  and served by GitHub Pages at
  [vlx42.github.io/upulls-site](https://vlx42.github.io/upulls-site/).
- **Releases:** attached to GitHub Releases here.
  `https://github.com/vLX42/uPulls/releases/download/vX.Y.Z/uPulls-X.Y.Z.zip`.

## Cutting a release

```sh
./bump.sh 1.1.0                                # updates Info.plist, release.sh, README, homepage
git commit -am "Bump version to 1.1.0"
git tag v1.1.0 && git push origin main v1.1.0  # triggers the Release workflow
./deploy-site.sh                               # publish updated download link on Pages
```

## License

MIT — see [LICENSE](LICENSE).
