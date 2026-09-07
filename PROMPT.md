# Build it yourself

You should not run a stranger's menu bar app just because it looks nice. Here is the
whole thing as a prompt instead. Paste it into Claude Code (or any coding agent that
can run a compiler), read the diff, and you get your own build that you can change
whenever the defaults annoy you.

Takes roughly two hours of agent time. You do not have to watch.

---

## The prompt

> Build me a macOS menu bar app called **uPulls** that shows my open GitHub pull requests.
>
> **Stack.** Swift Package Manager, AppKit for the status item and windows, SwiftUI for the
> views, macOS 14 or later, Apple Silicon. No third party dependencies. A `build.sh` that
> runs `swift build -c release --arch arm64`, wraps the binary in a proper `.app` bundle
> with an `Info.plist` marked `LSUIElement`, and ad-hoc signs it.
>
> **Data.** One GitHub GraphQL request per refresh. Put every tracked repo in the same query
> as an aliased `repository(owner:name:)` field so one bad repo fails alone instead of
> killing the whole response. Per pull request I need: number, title, url, isDraft,
> createdAt, updatedAt, reviewDecision, author (login, avatarUrl, and `__typename` so bots
> are detectable), requested reviewers, the status check rollup of the last commit, and the
> last 20 timeline items of type ISSUE_COMMENT and PULL_REQUEST_REVIEW. Note that `viewer`
> has no `__typename` in that query, so decode it into its own type. Poll every minute by
> default, and on wake from sleep.
>
> **Auth.** Read the token from the login Keychain. On first launch, if there is no token,
> try `gh auth token` from the GitHub CLI so there is nothing to configure. Also allow
> pasting a personal access token in Settings.
>
> **The popover.** Clicking the status item opens an NSPopover, about 372 points wide, with
> every tracked repo and all its open pull requests visible at once. No disclosure
> triangles, nothing to expand. Each row: a review-state dot (green approved, red changes
> requested, grey waiting, dashed outline for draft), the number, the title, an orange
> "review" pill when I am a requested reviewer, a CI glyph (tick, cross, dot), the author's
> avatar, and a short age like 4h. My own pull requests sort first, render bold with an
> accent-coloured number, and get a ring on the avatar. Rows open the PR in the browser.
> Repo headers carry a bell menu that mutes that repo for an hour, until tomorrow, or
> indefinitely, and a global snooze lives in the popover header. Right-clicking the status
> item gives a small menu with Refresh, Settings, Launch at Login and Quit.
>
> **Filters.** Settings toggles for hiding bot pull requests (Dependabot, Renovate,
> github-actions, anything whose author is a Bot), drafts, and pull requests already
> approved by someone else. Never hide my own pull requests or ones where I am a requested
> reviewer, whatever the filters say. Show a small count of what was hidden on the repo row.
>
> **Notifications.** Notify me when a human comments on, requests changes to, or approves a
> pull request I authored, and when someone requests my review. Rules that matter: the first
> successful fetch of a repo is silent so I do not get a backlog on day one, each event
> fires once, a muted repo or a global snooze swallows everything, and anything the list
> filters hide never notifies either. A "quiet bots" setting (on by default) silences
> Copilot reviews, github-actions chatter, and review requests on Renovate or Dependabot
> pull requests, because Renovate re-requests review on every rebase. Keep the diffing logic
> in a pure struct and unit test it.
>
> **Fireworks.** When one of my pull requests gets approved, put a click-through,
> screen-saver-level overlay window over the whole screen and fire real fireworks with
> CAEmitterLayer for a few seconds. Two independent emitters, rockets rising from the bottom
> and bursts popping in the upper half. Three things I learned the hard way, save yourself
> the debugging: use `emitterShape = .rectangle`, because `.line` emits nothing visible on
> macOS. Do not give a rocket cell an image and then an image-bearing child cell, or Core
> Animation draws the parent as a flat square. And for the HDR version, the brightness has
> to live in the sprite: build each particle as a half-float `RGBA16Float` CGImage in
> extended linear Display P3 with premultiplied components above 1.0, set the layers to
> `contentsFormat = .RGBA16Float`, `wantsExtendedDynamicRangeContent`,
> `preferredDynamicRange = .high` and `toneMapMode = .never`. An extended-range CGColor tint
> on the emitter cell does nothing. Clamp the brightness with the screen's
> `maximumPotentialExtendedDynamicRangeColorComponentValue`, never the current value, which
> reads 1.0 until HDR content is already on screen. On an XDR display the sparks then burn
> past white. Give me sliders for duration, intensity, spark size, spread and brightness,
> plus a Test button, because tuning fireworks by rebuilding is miserable.
>
> **Updates.** Check the GitHub Releases API on launch and every six hours. If a newer
> version exists, show an "Update to x.y.z" pill in the popover header and notify once per
> version. Clicking it downloads the release zip, unpacks it, strips the quarantine flag,
> moves the running bundle aside, moves the new one in, rolls back if that fails, and
> relaunches through a shell that waits for the old process to exit.
>
> **Settings window.** Token, repository list with drag and arrow reordering, the filter
> toggles, notification toggles, the fireworks sliders, updates, launch at login. Make the
> window vertically resizable and give it a title bar separator, otherwise the form scrolls
> under the title bar and ghosts in dark mode.
>
> **Prove it works.** Ship unit tests for the notification diffing, repo name parsing and
> the filters. Then actually run the app, take screenshots with `screencapture`, and look at
> them before telling me it works.

---

## After it builds

```sh
./build.sh
cp -R build/uPulls.app /Applications/
open /Applications/uPulls.app
```

macOS will complain that the app is not notarized, because you did not pay Apple 99 dollars
to say your own code is fine. Right-click the app, choose Open, confirm once. That is the
Apple tax, and it applies to your own build too.

Then change it. That is the point. The settings I picked are my compromises, not yours.
