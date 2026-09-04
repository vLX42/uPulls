import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var launch: LaunchAtLogin
    @State private var newRepo = ""
    @State private var addFailed = false
    @State private var ghImportMessage: String?

    private static let tokenURL = URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org&description=uPulls")!

    var body: some View {
        Form {
            Section {
                SecureField("Personal access token", text: $store.token)
                    .textContentType(.password)
                HStack(spacing: 10) {
                    Button("Use gh CLI token") { importFromGH() }
                        .help("Runs `gh auth token` and stores the result")
                    Link("Create a token…", destination: Self.tokenURL)
                        .font(.callout)
                    Spacer()
                    statusLabel
                }
                if let msg = ghImportMessage {
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("GitHub")
            } footer: {
                Text("Classic token with the `repo` scope, or a fine-grained token with Pull requests: read on the repositories you track.")
            }

            Section("Repositories") {
                ForEach(store.repos) { repo in
                    HStack {
                        Text(repo.fullName)
                        if let err = store.repoErrors[repo.key] {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .help(err)
                        }
                        Spacer()
                        if repo.isMuted {
                            Label(muteLabel(repo), systemImage: "bell.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .labelStyle(.titleAndIcon)
                        }
                        Button {
                            store.removeRepo(repo)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove")
                    }
                }
                HStack {
                    TextField("owner/repo or GitHub URL", text: $newRepo)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(TrackedRepo.parse(newRepo) == nil)
                }
                if addFailed {
                    Text("Already tracked or not a valid owner/repo.")
                        .font(.caption).foregroundStyle(.red)
                }
            }

            Section("Notifications") {
                Toggle("Comments and reviews on my PRs", isOn: $store.notifyMyPRs)
                Toggle("Someone requests my review", isOn: $store.notifyReviewRequests)
                Toggle("Quiet bots (Copilot reviews, github-actions…)", isOn: $store.quietBots)
                HStack {
                    Text("Try it").foregroundStyle(.secondary)
                    Spacer()
                    Button("Test notification") {
                        Notifier.shared.post(title: "🎉 octocat approved your PR",
                                             body: "#42 This is what an approval looks like", subtitle: "vLX42/uPulls",
                                             url: URL(string: "https://github.com/vLX42/uPulls")!, thread: "test")
                    }
                    .controlSize(.small)
                }
            }

            Section {
                Toggle("Fireworks when my PR gets approved", isOn: $store.fireworks)
                tuningSlider("Duration", value: $store.fireworksTuning.duration, in: 1.5...8, format: "%.1f s")
                tuningSlider("Intensity", value: $store.fireworksTuning.intensity, in: 0.3...3, format: "%.1f×")
                tuningSlider("Spark size", value: $store.fireworksTuning.sparkSize, in: 0.4...2.5, format: "%.1f×")
                tuningSlider("Spread", value: $store.fireworksTuning.spread, in: 0.4...2.5, format: "%.1f×")
                HStack {
                    Button("Reset") { store.fireworksTuning = FireworksTuning() }
                        .controlSize(.small)
                        .disabled(store.fireworksTuning == FireworksTuning())
                    Spacer()
                    Button("Test fireworks") { Fireworks.launch(store.fireworksTuning) }
                        .controlSize(.small)
                        .keyboardShortcut("t", modifiers: .command)
                }
            } header: {
                Text("Fireworks")
            } footer: {
                Text("Tweak, hit Test (⌘T), repeat. Settings apply to the next approval.")
            }

            Section("Menu") {
                Toggle("Hide bot PRs (Dependabot, Renovate…)", isOn: $store.hideBotPRs)
                Toggle("Show open PR count in menu bar", isOn: $store.showCount)
                Picker("Check GitHub every", selection: $store.pollInterval) {
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("2 minutes").tag(120.0)
                    Text("5 minutes").tag(300.0)
                }
                Toggle("Launch at login", isOn: Binding(
                    get: { launch.isEnabled },
                    set: { launch.setEnabled($0) }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 760)
    }

    private func tuningSlider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String) -> some View {
        HStack {
            Text(title).frame(width: 80, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if store.token.isEmpty {
            Text("Not signed in").font(.caption).foregroundStyle(.secondary)
        } else if let err = store.lastError {
            Label(err, systemImage: "xmark.circle.fill")
                .font(.caption).foregroundStyle(.red).lineLimit(1)
        } else if let login = store.viewerLogin {
            Label(login, systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        } else {
            ProgressView().controlSize(.small)
        }
    }

    private func muteLabel(_ repo: TrackedRepo) -> String {
        if repo.isMutedIndefinitely { return "muted" }
        guard let until = repo.mutedUntil else { return "" }
        return "until " + until.formatted(date: .omitted, time: .shortened)
    }

    private func add() {
        if store.addRepo(newRepo) {
            newRepo = ""
            addFailed = false
        } else {
            addFailed = true
        }
    }

    private func importFromGH() {
        switch GHCLI.token() {
        case .token(let t):
            store.token = t
            ghImportMessage = "Token imported from gh."
        case .notInstalled:
            ghImportMessage = "gh CLI not found (brew install gh)."
        case .failed(let msg):
            ghImportMessage = msg
        }
    }
}
