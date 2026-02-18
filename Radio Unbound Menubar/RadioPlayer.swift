//
//  RadioPlayer.swift
//  Radio Unbound Menubar
//
//  Created by Daniel Lee on 2/18/26.
//

import Foundation
import AVFoundation

@MainActor
final class RadioPlayer: NSObject {
    enum StreamKind: String {
        case hls = "HLS"
        case mp3 = "MP3"
    }

    enum State: Equatable {
        case stopped
        case buffering(StreamKind)
        case playing(StreamKind)
        case failed(String)
    }

    // Stream candidates (order matters)
    private let streams: [(kind: StreamKind, url: URL)] = [
        (.hls, URL(string: "https://streaming.live365.com/a94197/playlist.m3u8")!),
        (.mp3, URL(string: "https://streaming.live365.com/a94197")!)
    ]

    private(set) var state: State = .stopped {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((State) -> Void)?

    private var player: AVPlayer?
    private var currentIndex: Int = 0

    private var itemStatusObs: NSKeyValueObservation?
    private var timeControlObs: NSKeyValueObservation?
    private var likelyToKeepUpObs: NSKeyValueObservation?
    private var failedToPlayToEndObs: NSObjectProtocol?

    var volume: Float {
        get { player?.volume ?? 1.0 }
        set { player?.volume = max(0, min(1, newValue)) }
    }

    func isPlaying() -> Bool {
        if case .playing = state { return true }
        if case .buffering = state { return true }
        return false
    }

    func togglePlayStop() {
        isPlaying() ? stop() : playPreferred()
    }

    func playPreferred() {
        currentIndex = 0
        play(index: currentIndex)
    }

    func stop() {
        teardownObservers()
        player?.pause()
        player = nil
        state = .stopped
    }

    // MARK: - Internals

    private func play(index: Int) {
        teardownObservers()

        guard streams.indices.contains(index) else {
            state = .failed("No usable stream URLs.")
            return
        }

        let chosen = streams[index]
        let item = AVPlayerItem(url: chosen.url)
        let p = AVPlayer(playerItem: item)
        p.volume = (player?.volume ?? 1.0) // preserve last volume if possible
        player = p

        state = .buffering(chosen.kind)

        // Observe item.status for readiness/failure
        itemStatusObs = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .unknown:
                Task { @MainActor in
                    self.state = .buffering(chosen.kind)
                }
                
            case .readyToPlay:
                break
                
            case .failed:
                let msg = item.error?.localizedDescription ?? "Stream failed."
                Task { @MainActor in
                    self.failAndMaybeFallback(msg)
                }
                
            @unknown default:
                Task { @MainActor in
                    self.failAndMaybeFallback("Unknown AVPlayerItem status.")
                }
            }
        }


        // Observe buffering/playing transitions
        timeControlObs = p.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            guard let self else { return }
            switch player.timeControlStatus {
            case .paused:
                break

            case .waitingToPlayAtSpecifiedRate:
                Task { @MainActor in
                    self.state = .buffering(chosen.kind)
                }

            case .playing:
                Task { @MainActor in
                    self.state = .playing(chosen.kind)
                }

            @unknown default:
                break
            }

        }

        // Helps detect stalling
        likelyToKeepUpObs = item.observe(\.isPlaybackLikelyToKeepUp, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            if !item.isPlaybackLikelyToKeepUp {
                Task { @MainActor in
                    if self.isPlaying() {
                        self.state = .buffering(chosen.kind)
                    }
                }
            }

        }

        // Notification when playback fails mid-stream
        failedToPlayToEndObs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        )
        { [weak self] note in
            guard let self else { return }

            let err = (note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError)?.localizedDescription
                ?? "Playback failed to continue."

            Task { @MainActor [weak self] in
                self?.failAndMaybeFallback(err)
            }
        }

        p.play()
    }

    private func failAndMaybeFallback(_ msg: String) {
        // Try other stream once before giving up
        let nextIndex = currentIndex + 1
        if streams.indices.contains(nextIndex) {
            currentIndex = nextIndex
            play(index: currentIndex)
        } else {
            state = .failed(msg)
        }
    }

    private func teardownObservers() {
        itemStatusObs = nil
        timeControlObs = nil
        likelyToKeepUpObs = nil
        if let failedToPlayToEndObs {
            NotificationCenter.default.removeObserver(failedToPlayToEndObs)
            self.failedToPlayToEndObs = nil
        }
    }
}
