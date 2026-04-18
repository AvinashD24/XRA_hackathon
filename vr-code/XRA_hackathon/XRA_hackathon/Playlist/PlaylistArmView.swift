//
//  PlaylistArmView.swift
//  XRA_hackathon
//

import SwiftUI

struct PlaylistArmView: View {

    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(AudioPlaybackService.self) private var audioService

    @State private var expandedPlaylistId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "music.note.list")
                Text("Playlists")
                    .font(.headline)
                Spacer()
                Text("\(playlistStore.playlists.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if playlistStore.playlists.isEmpty {
                Text("Pinch both hands together and pull apart to create a playlist.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(playlistStore.playlists) { playlist in
                            playlistRow(playlist)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .padding(12)
        .frame(width: 260)
        .glassBackgroundEffect()
    }

    @ViewBuilder
    private func playlistRow(_ playlist: Playlist) -> some View {
        let isExpanded = expandedPlaylistId == playlist.id
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        expandedPlaylistId = isExpanded ? nil : playlist.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        Text(playlist.name)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(playlist.songs.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    playlistStore.deletePlaylist(playlist.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonBorderShape(.circle)
            }

            if isExpanded {
                ForEach(playlist.songs) { song in
                    HStack(spacing: 8) {
                        Button {
                            audioService.toggle(song: song)
                        } label: {
                            Image(systemName:
                                (audioService.currentSong?.id == song.id && audioService.isPlaying)
                                ? "pause.fill" : "play.fill")
                                .font(.caption2)
                        }
                        .buttonBorderShape(.circle)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(song.title)
                                .font(.caption)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            playlistStore.remove(songId: song.id, from: playlist.id)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.caption2)
                        }
                        .buttonBorderShape(.circle)
                    }
                    .padding(.leading, 14)
                }
            }
        }
    }
}
