import SwiftUI

/// The popover: every tracked repo and its open PRs, visible at once.
struct DashboardView: View {
    @EnvironmentObject private var store: Store
    @ObservedObject private var updater = Updater.shared
    let onRefresh: () -> Void
    let onSettings: () -> Void
    let onQuit: () -> Void

    @State private var contentHeight: CGFloat = 0
    private let width: CGFloat = 372
    private let maxListHeight: CGFloat = 620

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.token.isEmpty {
                emptyState("Connect GitHub", detail: "Paste a token or pick up the one from the gh CLI.", button: "Open Settings…")
            } else if store.repos.isEmpty {
                emptyState("No repositories yet", detail: "Add the projects you want to keep an eye on.", button: "Add Repository…")
            } else {
                list
            }
            Divider()
            footer
        }
        .frame(width: width)
        .background(.regularMaterial)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.pull")
                .font(.system(size: 12, weight: .semibold))
            Text("uPulls").font(.system(size: 12, weight: .semibold))
            if !store.repos.isEmpty && !store.token.isEmpty {
                Text("\(store.badgeCount) open")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let login = store.viewerLogin {
                Text("· \(login)").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            Spacer()
            if let release = updater.updateAvailable {
                Button {
                    updater.install()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: updater.state == .downloading || updater.state == .installing ? "arrow.down.circle" : "arrow.up.circle.fill")
                        Text(updater.state == .downloading ? "Downloading…" : updater.state == .installing ? "Installing…" : "Update to \(release.version)")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.22), in: Capsule())
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(updater.state == .downloading || updater.state == .installing)
                .help("Downloads the new version, swaps it in and relaunches")
            }
            snoozeMenu
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                    .animation(store.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: store.isRefreshing)
            }
            .buttonStyle(.borderless)
            .help("Refresh now (⌘R)")
            .keyboardShortcut("r", modifiers: .command)
            Button(action: onSettings) {
                Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Add or manage repositories")
            Button(action: onSettings) {
                Image(systemName: "gearshape").font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("Settings (⌘,)")
            .keyboardShortcut(",", modifiers: .command)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var snoozeMenu: some View {
        Menu {
            if store.isSnoozed {
                Button("Unsnooze") { store.snoozedUntil = nil }
                Divider()
            }
            Button("Snooze for 1 hour") { store.snoozedUntil = Date().addingTimeInterval(3600) }
            Button("Snooze until tomorrow") { store.snoozedUntil = tomorrowMorning() }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: store.isSnoozed ? "bell.slash.fill" : "bell")
                if store.isSnoozed, let until = store.snoozedUntil {
                    Text(until.formatted(date: .omitted, time: .shortened)).font(.system(size: 10))
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(store.isSnoozed ? Color.orange : Color.primary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(store.isSnoozed ? "Notifications snoozed" : "Snooze all notifications")
    }

    // MARK: List

    private var list: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                if let err = store.lastError {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                        .lineLimit(2)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                }
                ForEach(store.repos) { repo in
                    RepoSection(repo: repo)
                }
            }
            .padding(.vertical, 4)
            .background(GeometryReader { g in
                Color.clear.preference(key: HeightKey.self, value: g.size.height)
            })
        }
        .onPreferenceChange(HeightKey.self) { contentHeight = $0 }
        .frame(height: min(max(contentHeight, 44), maxListHeight))
    }

    private func emptyState(_ title: String, detail: String, button: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold))
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(button, action: onSettings).controlSize(.small).padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            if let last = store.lastRefresh {
                Text("Updated \(shortAge(last)) ago").monospacedDigit()
            } else if store.isRefreshing {
                Text("Loading…")
            }
            Spacer()
            Button("Quit", action: onQuit)
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
}

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// MARK: - Repo section

private struct RepoSection: View {
    @EnvironmentObject private var store: Store
    let repo: TrackedRepo
    @State private var hovering = false

    private var prs: [PullRequest] { store.visiblePRs(for: repo) }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            if !repo.isMuted {
                ForEach(prs) { pr in
                    PRRow(pr: pr)
                }
            }
        }
        .padding(.bottom, 3)
    }

    private var sectionHeader: some View {
        let parts = repo.fullName.split(separator: "/", maxSplits: 1).map(String.init)
        let hiddenBots = store.hiddenBotCount(for: repo)
        let hiddenDrafts = store.hiddenDraftCount(for: repo)
        return HStack(spacing: 6) {
            (Text((parts.first ?? "") + "/").foregroundStyle(.tertiary)
             + Text(parts.count > 1 ? parts[1] : "").foregroundStyle(repo.isMuted ? .tertiary : .secondary))
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.head)
                .layoutPriority(1)

            if let err = store.repoErrors[repo.key] {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9)).foregroundStyle(.orange)
                    .help(err)
            }

            if repo.isMuted {
                Text(repo.isMutedIndefinitely ? "muted" : "muted until \(repo.mutedUntil!.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                Text("· \(prs.count) open").font(.system(size: 10)).foregroundStyle(.quaternary).monospacedDigit()
            } else if prs.isEmpty {
                Text("no open PRs").font(.system(size: 10)).foregroundStyle(.quaternary)
            }
            if hiddenBots > 0 {
                Text("· \(hiddenBots) bot\(hiddenBots == 1 ? "" : "s") hidden")
                    .font(.system(size: 10)).foregroundStyle(.quaternary)
                    .help("Hidden by the bot filter (Settings → Menu)")
            }
            if hiddenDrafts > 0 {
                Text("· \(hiddenDrafts) draft\(hiddenDrafts == 1 ? "" : "s") hidden")
                    .font(.system(size: 10)).foregroundStyle(.quaternary)
                    .help("Hidden by the draft filter (Settings → Menu)")
            }

            Spacer(minLength: 4)

            Button {
                NSWorkspace.shared.open(repo.pullsURL)
            } label: {
                Image(systemName: "arrow.up.right.square").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .opacity(hovering ? 1 : 0)
            .help("Open on GitHub")

            muteMenu
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var muteMenu: some View {
        Menu {
            if repo.isMuted {
                Button("Unmute") { store.mute(repo, until: nil) }
                Divider()
            }
            Button("Mute for 1 hour") { store.mute(repo, until: Date().addingTimeInterval(3600)) }
            Button("Mute until tomorrow") { store.mute(repo, until: tomorrowMorning()) }
            Button("Mute") { store.mute(repo, until: .distantFuture) }
            Divider()
            Button("Remove repository") { store.removeRepo(repo) }
        } label: {
            Image(systemName: repo.isMuted ? "bell.slash.fill" : "bell")
                .font(.system(size: 10))
                .foregroundStyle(repo.isMuted ? Color.orange.opacity(0.9) : Color.secondary.opacity(hovering ? 1 : 0.55))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(repo.isMuted ? "Muted — click to change" : "Mute this repository")
    }
}

// MARK: - PR row

private struct PRRow: View {
    @EnvironmentObject private var store: Store
    let pr: PullRequest
    @State private var hovering = false

    private var mine: Bool { pr.isAuthored(by: store.viewerLogin) }
    private var wantsMe: Bool { pr.isReviewRequested(from: store.viewerLogin) }

    var body: some View {
        HStack(spacing: 7) {
            StatusDot(pr: pr)

            Text(verbatim: "#\(pr.number)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)

            Text(pr.title)
                .font(.system(size: 12, weight: mine ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 6)

            if wantsMe {
                Text("review")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color.orange.opacity(0.18), in: Capsule())
                    .foregroundStyle(.orange)
            }

            checksGlyph

            Avatar(url: pr.authorAvatar, login: pr.authorLogin, highlighted: mine)

            Text(shortAge(pr.updatedAt))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 26, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(hovering ? 0.07 : 0))
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { NSWorkspace.shared.open(pr.url) }
        .help(tooltip)
    }

    @ViewBuilder
    private var checksGlyph: some View {
        switch pr.checks {
        case .success: Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.green)
        case .failure: Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.red)
        case .pending: Circle().fill(Color.yellow).frame(width: 6, height: 6)
        case .none: EmptyView()
        }
    }

    private var tooltip: String {
        var t = "\(pr.title)\nby \(pr.authorLogin) · opened \(shortAge(pr.createdAt)) ago"
        if pr.isDraft { t += " · draft" }
        switch pr.reviewDecision {
        case .approved: t += " · approved"
        case .changesRequested: t += " · changes requested"
        case .reviewRequired: t += " · review required"
        case .none: break
        }
        switch pr.checks {
        case .success: t += "\nChecks passing"
        case .failure: t += "\nChecks failing"
        case .pending: t += "\nChecks running"
        case .none: break
        }
        return t
    }
}

/// Review state at a glance: green approved, red changes requested,
/// hollow for drafts, dim for "nothing yet".
private struct StatusDot: View {
    let pr: PullRequest

    var body: some View {
        Group {
            if pr.isDraft {
                Circle().strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [2, 1.5]))
            } else {
                switch pr.reviewDecision {
                case .approved: Circle().fill(Color.green)
                case .changesRequested: Circle().fill(Color.red)
                case .reviewRequired, .none: Circle().fill(Color.secondary.opacity(0.35))
                }
            }
        }
        .frame(width: 8, height: 8)
    }
}

private struct Avatar: View {
    let url: URL?
    let login: String
    let highlighted: Bool

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Text(String(login.prefix(1)).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.2))
            }
        }
        .frame(width: 16, height: 16)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(highlighted ? Color.accentColor : Color.clear, lineWidth: 1.5))
        .help(highlighted ? "\(login) (you)" : login)
    }
}
