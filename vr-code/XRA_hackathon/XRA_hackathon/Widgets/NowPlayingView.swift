//
//  NowPlayingView.swift
//  XRA_hackathon
//

import SwiftUI

struct NowPlayingView: View {

    @Environment(AudioPlaybackService.self) private var audioService

    var body: some View {
        Group {
            if let song = audioService.currentSong {
                HStack(spacing: 10) {
                    AsyncImage(url: song.photoURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Rectangle().fill(.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 110, alignment: .leading)

                    Button {
                        audioService.toggle(song: song)
                    } label: {
                        Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonBorderShape(.circle)
                }
                .padding(10)
                .frame(width: 220)
                .glassBackgroundEffect()
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                    Text("No song playing")
                        .font(.caption)
                }
                .padding(10)
                .glassBackgroundEffect()
            }
        }
    }
}
