//
//  AudioPlaybackService.swift
//  XRA_hackathon
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class AudioPlaybackService {
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var audioSessionConfigured = false

    var currentSong: SongData?
    var isPlaying: Bool = false

    func toggle(song: SongData) {
        if currentSong?.id == song.id, isPlaying {
            stop()
        } else {
            play(song: song)
        }
    }

    func play(song: SongData) {
        guard let url = song.playbackURL else {
            print("AudioPlaybackService: no preview URL for \(song.title)")
            return
        }

        stop()
        configureAudioSessionIfNeeded()

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        self.currentSong = song
        self.isPlaying = true

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }

        print("AudioPlaybackService: playing \(url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent)")
        player.play()
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
    }

    private func configureAudioSessionIfNeeded() {
#if os(iOS) || os(tvOS) || os(visionOS)
        guard !audioSessionConfigured else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            audioSessionConfigured = true
        } catch {
            print("AudioPlaybackService: failed to configure audio session: \(error.localizedDescription)")
        }
#endif
    }
}
