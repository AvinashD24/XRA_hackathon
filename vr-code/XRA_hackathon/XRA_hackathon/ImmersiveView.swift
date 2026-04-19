//
//  ImmersiveView.swift
//  XRA_hackathon
//

import SwiftUI
import RealityKit
import simd

struct ImmersiveView: View {

    @Environment(AppSettings.self) private var appSettings
    @Environment(SongStore.self) private var songStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(AudioPlaybackService.self) private var audioService
    @Environment(HandTrackingManager.self) private var handTracking

    @State private var selectedSongId: String?
    @State private var songEntities: [String: ModelEntity] = [:]
    @State private var rootEntity = Entity()
    @State private var selectionSphere: ModelEntity?
    @State private var leftWristAnchor = Entity()
    @State private var rightWristAnchor = Entity()
    @State private var infoCardAnchor = Entity()
    @State private var confirmAnchor = Entity()
    @State private var resetAnchor = Entity()

    private var visibleSongs: [SongData] {
        Array(songStore.songs.prefix(appSettings.maxVisibleSphereCount))
    }

    private var selectedSong: SongData? {
        guard let id = selectedSongId else { return nil }
        return visibleSongs.first { $0.id == id }
    }

    var body: some View {
        RealityView { content, attachments in
            rootEntity.position = SIMD3<Float>(0, 1.4, -1.5)
            content.add(rootEntity)
            content.add(leftWristAnchor)
            content.add(rightWristAnchor)
            content.add(infoCardAnchor)
            content.add(confirmAnchor)
            content.add(resetAnchor)

            print("ImmersiveView: creating \(visibleSongs.count) sphere entities")
            for song in visibleSongs {
                let entity = SongSphereEntity.make(for: song)
                rootEntity.addChild(entity)
                songEntities[song.id] = entity
            }
            print("ImmersiveView: rootEntity has \(rootEntity.children.count) children")

            let sel = SongSphereEntity.makeSelectionSphere()
            sel.isEnabled = false
            rootEntity.addChild(sel)
            selectionSphere = sel

            if let info = attachments.entity(for: "infoCard") {
                infoCardAnchor.addChild(info)
            }
            if let np = attachments.entity(for: "nowPlaying") {
                leftWristAnchor.addChild(np)
            }
            if let pl = attachments.entity(for: "playlistArm") {
                rightWristAnchor.addChild(pl)
            }
            if let cb = attachments.entity(for: "confirmPlaylist") {
                confirmAnchor.addChild(cb)
                confirmAnchor.isEnabled = false
            }
            if let rb = attachments.entity(for: "resetButton") {
                resetAnchor.addChild(rb)
                resetAnchor.position = SIMD3<Float>(0, -0.2, -1.2)
            }
        } update: { _, _ in
            updateSceneState()
        } attachments: {
            Attachment(id: "infoCard") {
                if let song = selectedSong {
                    SongInfoCard(song: song) {
                        selectedSongId = nil
                    }
                }
            }
            Attachment(id: "nowPlaying") {
                NowPlayingView()
            }
            Attachment(id: "playlistArm") {
                PlaylistArmView()
            }
            Attachment(id: "confirmPlaylist") {
                ConfirmPlaylistView {
                    let selected = songStore.songs.filter { handTracking.selectedSongIds.contains($0.id) }
                    playlistStore.createPlaylist(from: selected)
                    handTracking.dismissSelection()
                }
            }
            Attachment(id: "resetButton") {
                ResetButtonView {
                    resetScene()
                }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let name = value.entity.name
                    if !name.isEmpty, visibleSongs.contains(where: { $0.id == name }) {
                        selectedSongId = name
                    }
                }
        )
        .task {
            handTracking.updateSongList(visibleSongs)
            await handTracking.start()
        }
    }

    private func updateSceneState() {
        // Info card follows selected sphere
        if let id = selectedSongId, let entity = songEntities[id] {
            infoCardAnchor.position = entity.position + SIMD3<Float>(0, 0.15, 0)
            infoCardAnchor.isEnabled = true
        } else {
            infoCardAnchor.isEnabled = false
        }

        // Wrist attachments
        if let lt = handTracking.leftWristTransform {
            leftWristAnchor.transform = lt
            leftWristAnchor.transform.translation += SIMD3<Float>(0, 0.08, 0)
            leftWristAnchor.isEnabled = true
        } else {
            leftWristAnchor.isEnabled = false
        }
        if let rt = handTracking.rightWristTransform {
            rightWristAnchor.transform = rt
            rightWristAnchor.transform.translation += SIMD3<Float>(0, 0.08, 0)
            rightWristAnchor.isEnabled = true
        } else {
            rightWristAnchor.isEnabled = false
        }

        // Selection sphere
        if let sel = selectionSphere {
            switch handTracking.selectionPhase {
            case .idle:
                sel.isEnabled = false
                confirmAnchor.isEnabled = false
            case .forming:
                sel.isEnabled = true
                sel.position = handTracking.selectionCenter
                let r = max(handTracking.selectionRadius, 0.01)
                sel.scale = SIMD3<Float>(repeating: r / 0.1)
                confirmAnchor.isEnabled = false
            case .confirming:
                sel.isEnabled = true
                sel.position = handTracking.selectionCenter
                let r = max(handTracking.selectionRadius, 0.01)
                sel.scale = SIMD3<Float>(repeating: r / 0.1)
                confirmAnchor.position = handTracking.selectionCenter + SIMD3<Float>(0, handTracking.selectionRadius + 0.1, 0)
                confirmAnchor.isEnabled = true
            }
        }

        // Highlight selected songs
        for song in visibleSongs {
            guard let entity = songEntities[song.id] else { continue }
            let isHighlighted = handTracking.selectedSongIds.contains(song.id)
            let isPlaying = audioService.currentSong?.id == song.id && audioService.isPlaying
            SongSphereEntity.updateHighlight(entity: entity, song: song, highlighted: isHighlighted, playing: isPlaying)
        }
    }

    private func resetScene() {
        audioService.stop()
        selectedSongId = nil
        handTracking.dismissSelection()
        for song in visibleSongs {
            if let entity = songEntities[song.id] {
                entity.position = song.position
            }
        }
    }
}
