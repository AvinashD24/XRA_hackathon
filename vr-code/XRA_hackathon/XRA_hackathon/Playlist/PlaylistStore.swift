//
//  PlaylistStore.swift
//  XRA_hackathon
//

import Foundation
import Observation

struct Playlist: Identifiable, Hashable {
    let id: UUID = UUID()
    var name: String
    var songs: [SongData]
}

@MainActor
@Observable
final class PlaylistStore {
    var playlists: [Playlist] = []

    func createPlaylist(from songs: [SongData]) {
        let index = playlists.count + 1
        playlists.append(Playlist(name: "Playlist \(index)", songs: songs))
    }

    func addSong(_ song: SongData, to playlistID: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        if !playlists[idx].songs.contains(where: { $0.id == song.id }) {
            playlists[idx].songs.append(song)
        }
    }

    func remove(songId: String, from playlistID: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[idx].songs.removeAll { $0.id == songId }
    }

    func deletePlaylist(_ playlistID: UUID) {
        playlists.removeAll { $0.id == playlistID }
    }
}
