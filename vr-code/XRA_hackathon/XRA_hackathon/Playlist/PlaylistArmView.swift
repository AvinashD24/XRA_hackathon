//
//  PlaylistArmView.swift
//  XRA_hackathon
//
//  Always-visible playlist panel that follows the user's head.
//  Displays all playlists with their songs visible.

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
                Text("Pinch both hands together and pull apart to select songs, or tap a song and use \"Add to Playlist\".")
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
                .frame(maxHeight: 320)
            }
        }
        .padding(14)
        .frame(width: 300)
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
                        Text("\(playlist.songs.count) songs")
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

            // Always show first 3 songs as a preview; show all when expanded
            let songsToShow = isExpanded ? playlist.songs : Array(playlist.songs.prefix(3))
            ForEach(songsToShow) { song in
                HStack(spacing: 8) {
                    // Small album art
                    AsyncImage(url: song.photoURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Rectangle().fill(.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    Button {
                        audioService.toggle(song: song)
                    } label: {
                        Image(systemName:
                            (audioService.currentSong?.id == song.id && audioService.isPlaying)
                            ? "pause.fill" : "play.fill")
                            .font(.caption2)
                    }
                    .buttonBorderShape(.circle)
                    .disabled(song.playbackURL == nil)

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

            if !isExpanded && playlist.songs.count > 3 {
                Text("+ \(playlist.songs.count - 3) more…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 14)
            }
        }
    }
}
