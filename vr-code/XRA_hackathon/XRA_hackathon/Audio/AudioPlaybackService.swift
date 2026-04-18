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
}
