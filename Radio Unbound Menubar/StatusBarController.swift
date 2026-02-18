//
//  StatusBarController.swift
//  Radio Unbound Menubar
//
//  Created by Daniel Lee on 2/18/26.
//

import AppKit

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private let client = RadioUnboundClient()
    private let radioPlayer = RadioPlayer()

    private var timer: Timer?

    private var playStopItem: NSMenuItem!
    private var nowPlayingItem: NSMenuItem!
    private var copyTrackItem: NSMenuItem!
    private var volumeMenuItem: NSMenuItem!

    private var lastTrack: Track?
    private var lastFreshIdentityKey: String?
    private var lastDisplayText: String?

    // If API lags, we mark stale when "now" is past end + grace
    private let staleGraceSeconds: TimeInterval = 20

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.title = "Radio Unbound…"
        statusItem.menu = menu

        buildMenu()
        hookPlayer()
        startPolling()
        Task { await refreshNow() }
    }

    // MARK: - Menu

    private func buildMenu() {
        menu.removeAllItems()

        nowPlayingItem = NSMenuItem(title: "Now Playing: —", action: nil, keyEquivalent: "")
        nowPlayingItem.isEnabled = false
        menu.addItem(nowPlayingItem)

        menu.addItem(NSMenuItem.separator())

        playStopItem = NSMenuItem(title: "Play", action: #selector(playStopClicked), keyEquivalent: "p")
        playStopItem.target = self
        menu.addItem(playStopItem)

        volumeMenuItem = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        menu.addItem(volumeMenuItem)
        volumeMenuItem.submenu = makeVolumeSubmenu(selectedPercent: 100)

        copyTrackItem = NSMenuItem(title: "Copy Track Info", action: #selector(copyTrackInfo), keyEquivalent: "c")
        copyTrackItem.target = self
        menu.addItem(copyTrackItem)

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshClicked), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let openSite = NSMenuItem(title: "Open RadioUnbound.com", action: #selector(openWebsite), keyEquivalent: "")
        openSite.target = self
        menu.addItem(openSite)

        let openStream = NSMenuItem(title: "Open Stream URL", action: #selector(openStreamURL), keyEquivalent: "")
        openStream.target = self
        menu.addItem(openStream)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    private func formatLocalTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        df.locale = .current
        df.timeZone = .current
        return df.string(from: date)
    }


    private func makeVolumeSubmenu(selectedPercent: Int) -> NSMenu {
        let sub = NSMenu()

        // A nice spread; adjust as desired
        let steps = [0, 10, 25, 40, 55, 70, 85, 100]

        for pct in steps {
            let item = NSMenuItem(title: "\(pct)%", action: #selector(volumeSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pct
            item.state = (pct == selectedPercent) ? .on : .off
            sub.addItem(item)
        }

        return sub
    }

    private func updateVolumeMenuCheckmarks(to selectedPercent: Int) {
        guard let sub = volumeMenuItem.submenu else { return }
        for item in sub.items {
            let pct = item.representedObject as? Int
            item.state = (pct == selectedPercent) ? .on : .off
        }
    }

    // MARK: - Polling

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { await self?.refreshNow() }
        }
        timer?.tolerance = 3
    }

    @objc private func refreshClicked() {
        Task { await refreshNow() }
    }

    private func refreshNow() async {
        do {
            let track = try await client.fetchCurrentTrack()
            updateTrackDisplay(track)
        } catch {
            setStatusBarTitleIfChanged("Radio Unbound — (offline)")
            DispatchQueue.main.async { [weak self] in
                self?.nowPlayingItem.title = "Now Playing: (offline)"
            }
        }
    }

    // MARK: - Stale logic + UI updates

    @MainActor
    private func updateTrackDisplay(_ track: Track?) {
        guard let track else {
            nowPlayingItem.title = "Now Playing: (no data)"
            setStatusBarTitleIfChanged("Radio Unbound — (no data)")
            return
        }

        let title = clean(track.title) ?? "Unknown Title"
        let artist = clean(track.artist) ?? "Unknown Artist"

        let prefix = "Now Playing on Radio Unbound: "
        let displayBase = "\(prefix)\(artist) - \(title)"


        let isStale = computeIsStale(track: track)

        let display: String
        if isStale, let endDate = Live365DateParser.parse(track.end) {
            let endedAt = formatLocalTime(endDate)
            display = "\(displayBase) — Song ended at \(endedAt). Awaiting new data."
        } else if isStale {
            display = "\(displayBase) — Song ended. Awaiting new data."
        } else {
            display = displayBase
        }


        nowPlayingItem.title = "Now Playing: \(display)"

        // If you want the menubar to always show the track:
        setStatusBarTitleIfChanged(display)

        // track caching
        lastTrack = track

        // Remember last *fresh* identity so you can compare later
        if !isStale {
            lastFreshIdentityKey = track.identityKey
        }

        // Enable Copy Track
        copyTrackItem.isEnabled = true
    }

    private func computeIsStale(track: Track) -> Bool {
        guard let endDate = Live365DateParser.parse(track.end) else {
            // If we can't parse end, we can't judge staleness reliably
            return false
        }

        let now = Date()
        let pastExpectedEnd = now > endDate.addingTimeInterval(staleGraceSeconds)

        if !pastExpectedEnd { return false }

        // If the API is still returning the same identity past end+grace,
        // it's probably stale metadata.
        // If identity differs from last fresh, treat as "updated" even if timing is weird.
        if let lastFresh = lastFreshIdentityKey {
            return track.identityKey == lastFresh
        }

        // Fallback: if we have a lastTrack and it's identical, treat stale
        if let last = lastTrack {
            return track.identityKey == last.identityKey
        }

        return false
    }

    private func clean(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func setStatusBarTitleIfChanged(_ text: String) {
        if lastDisplayText == text { return }
        lastDisplayText = text
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.title = text
        }
    }

    // MARK: - Player integration

    private func hookPlayer() {
        radioPlayer.onStateChange = { [weak self] state in
            self?.updatePlayStopTitle(state: state)
        }

        // Default volume menu state (100%)
        updateVolumeMenuCheckmarks(to: 100)
        radioPlayer.volume = 1.0
    }

    private func updatePlayStopTitle(state: RadioPlayer.State) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .stopped:
                self.playStopItem.title = "Play"
            case .buffering(let kind):
                self.playStopItem.title = "Stop (Buffering \(kind.rawValue)…)"
            case .playing(let kind):
                self.playStopItem.title = "Stop (\(kind.rawValue))"
            case .failed:
                self.playStopItem.title = "Play (Error)"
            }
        }
    }

    // MARK: - Actions

    @objc private func playStopClicked() {
        radioPlayer.togglePlayStop()
    }

    @objc private func volumeSelected(_ sender: NSMenuItem) {
        guard let pct = sender.representedObject as? Int else { return }
        let vol = Float(pct) / 100.0
        radioPlayer.volume = vol
        updateVolumeMenuCheckmarks(to: pct)
    }

    @objc private func copyTrackInfo() {
        // Use the most recent display line
        let text = lastDisplayText ?? "Radio Unbound"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    @objc private func openWebsite() {
        NSWorkspace.shared.open(URL(string: "https://www.RadioUnbound.com")!)
    }

    @objc private func openStreamURL() {
        // Opens in browser; playback stays in-app if you use Play
        NSWorkspace.shared.open(URL(string: "https://streaming.live365.com/a94197")!)
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
}
