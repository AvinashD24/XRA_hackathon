//
//  SongInfoCard.swift
//  XRA_hackathon
//

import SwiftUI

struct SongInfoCard: View {

    let song: SongData
    let onDismiss: () -> Void

    @Environment(AudioPlaybackService.self) private var audioService
    @Environment(PlaylistStore.self) private var playlistStore

    private var isPlayingThis: Bool {
        audioService.currentSong?.id == song.id && audioService.isPlaying
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AsyncImage(url: song.photoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Rectangle().fill(.gray.opacity(0.3))
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Button {
                        audioService.toggle(song: song)
                    } label: {
                        Label(isPlayingThis ? "Stop" : (song.playbackURL == nil ? "No preview" : "Play"),
                              systemImage: isPlayingThis ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(song.playbackURL == nil)

                    Menu {
                        Button("New playlist") {
                            playlistStore.createPlaylist(from: [song])
                        }
                        if !playlistStore.playlists.isEmpty {
                            Divider()
                            ForEach(playlistStore.playlists) { playlist in
                                Button(playlist.name) {
                                    playlistStore.addSong(song, to: playlist.id)
                                }
                            }
                        }
                    } label: {
                        Label("Add to Playlist", systemImage: "plus")
                    }
                    .menuStyle(.button)
                }
            }

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonBorderShape(.circle)
        }
        .padding(18)
        .frame(width: 500)
        .glassBackgroundEffect()
    }
}
