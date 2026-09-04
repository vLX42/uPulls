import AppKit
import Combine
import SwiftUI

@main
struct UPullsApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        _ = delegate // retain
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let store = Store.shared
    private let launch = LaunchAtLogin.shared
    private lazy var monitor = Monitor(store: store)
    private var popover: NSPopover!
    private var clickOutsideMonitor: Any?
    private var settingsWindowController: NSWindowController?
    private var cancellables: Set<AnyCancellable> = []

    // MARK: – Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "arrow.triangle.pull", accessibilityDescription: "uPulls")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let root = DashboardView(
            onRefresh: { [weak self] in self?.monitor.refresh() },
            onSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        ).environmentObject(store)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        popover = NSPopover()
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true

        _ = Notifier.shared

        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusButton() }
            .store(in: &cancellables)
        updateStatusButton()

        // Zero-config: borrow the GitHub CLI's token on first launch.
        if store.token.isEmpty, case .token(let t) = GHCLI.token() {
            store.token = t
        }

        monitor.start()

        let updater = Updater.shared
        updater.start(auto: store.autoUpdate)
        store.$autoUpdate.dropFirst().sink { updater.start(auto: $0) }.store(in: &cancellables)
        updater.$latest
            .compactMap { _ in updater.updateAvailable }
            .receive(on: RunLoop.main)
            .sink { [weak self] release in
                guard let self, store.notifiedUpdateVersion != release.version else { return }
                store.notifiedUpdateVersion = release.version
                Notifier.shared.post(title: "uPulls \(release.version) is available",
                                     body: "Open uPulls and click Update, it installs and relaunches by itself.",
                                     url: release.pageURL, thread: "update", sound: false)
            }
            .store(in: &cancellables)

        // Dev helpers: `open build/uPulls.app --args --fireworks --open-menu --snapshot <dir>`
        if CommandLine.arguments.contains("--fireworks") {
            let delay: TimeInterval = CommandLine.arguments.contains("--snapshot") ? 4.8 : 0.5
            let backdrop = CommandLine.arguments.contains("--backdrop")
            // --promo: louder tuning for marketing captures on a 1x display.
            let tuning = CommandLine.arguments.contains("--promo")
                ? FireworksTuning(duration: 5, intensity: 2.0, sparkSize: 2.0, spread: 1.15)
                : store.fireworksTuning
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { Fireworks.launch(tuning, backdrop: backdrop) }
        }
        if CommandLine.arguments.contains("--notify-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                Notifier.shared.post(title: "🎉 someone approved your PR", body: "#1 Test notification from uPulls",
                                     subtitle: "vLX42/uPulls", url: URL(string: "https://github.com/vLX42/uPulls")!, thread: "test")
            }
        }
        if CommandLine.arguments.contains("--self-update-test") {
            // Dev: check immediately and install whatever is newer than this build.
            updater.check(token: store.token)
            updater.$latest.compactMap { $0 }.first().sink { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { updater.install() }
            }.store(in: &cancellables)
        }
        if CommandLine.arguments.contains("--edr-probe") {
            // Log the screen's live headroom before, during and after a volley:
            // if EDR engages, the "now" value climbs above 1.0 while it plays.
            for t in stride(from: 0.0, through: 9.0, by: 1.0) {
                DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                    let s = NSScreen.main
                    NSLog("[uPulls] t=%.0fs headroom now %.2f potential %.2f", t,
                          s?.maximumExtendedDynamicRangeColorComponentValue ?? 0,
                          s?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 0)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { NSApp.terminate(nil) }
        }
        if CommandLine.arguments.contains("--settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [self] in openSettings() }
        }
        if CommandLine.arguments.contains("--open-menu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [self] in showPopover() }
        }
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.indices.contains(i + 1) {
            let dir = CommandLine.arguments[i + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [self] in showPopover() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { DebugSnapshot.capture(to: dir) }
            if CommandLine.arguments.contains("--fireworks") {
                for (i, t) in [5.3, 6.6, 7.4].enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + t) { DebugSnapshot.capture(to: dir + "/f\(i)") }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { NSApp.terminate(nil) }
        }
        if store.token.isEmpty || store.repos.isEmpty {
            openSettings()
        }
    }

    private func updateStatusButton() {
        guard let button = statusItem?.button else { return }
        let count = store.badgeCount
        button.title = (store.showCount && count > 0) ? " \(count)" : ""
        button.appearsDisabled = store.isSnoozed
        button.toolTip = store.isSnoozed
            ? "uPulls — snoozed until \(store.snoozedUntil!.formatted(date: .omitted, time: .shortened))"
            : "uPulls — \(count) open pull request\(count == 1 ? "" : "s")"
    }

    // MARK: – Popover

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown { closePopover() } else { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        store.expireTimers()
        monitor.refreshIfStale()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        // Transient popovers from an accessory app don't always notice clicks
        // elsewhere in the menu bar; close on any outside click ourselves.
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePopover() }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let m = clickOutsideMonitor {
            NSEvent.removeMonitor(m)
            clickOutsideMonitor = nil
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        let repos = NSMenuItem(title: "Manage Repositories…", action: #selector(openSettings), keyEquivalent: "")
        repos.target = self
        menu.addItem(repos)
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = launch.isEnabled ? .on : .off
        menu.addItem(loginItem)
        let about = NSMenuItem(title: "About uPulls", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit uPulls", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Temporarily attach so the system positions it under the status item.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: – Actions

    @objc private func refreshNow() {
        monitor.refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        launch.setEnabled(!launch.isEnabled)
        if let err = launch.lastError {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Login Item"
            alert.informativeText = err
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let info: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "uPulls",
            .credits: NSAttributedString(
                string: "Open pull requests in your menu bar.\n\nhttps://github.com/vLX42/uPulls",
                attributes: [.foregroundColor: NSColor.labelColor]
            )
        ]
        NSApp.orderFrontStandardAboutPanel(options: info)
    }

    @objc func openSettings() {
        closePopover()
        if settingsWindowController == nil {
            let root = SettingsView()
                .environmentObject(store)
                .environmentObject(launch)
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "uPulls"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}
