//
//  ImmersiveView.swift
//  XRA_hackathon
//

import SwiftUI
import RealityKit
import ARKit
import simd

struct ImmersiveView: View {

    @Environment(AppSettings.self) private var appSettings
    @Environment(SongStore.self) private var songStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(AudioPlaybackService.self) private var audioService
    @Environment(HandTrackingManager.self) private var handTracking

    @State private var selectedSongId: String?
    @State private var hoveredSongId: String?
    @State private var songEntities: [String: ModelEntity] = [:]
    @State private var rootEntity = Entity()
    @State private var selectionSphere: ModelEntity?
    @State private var leftWristAnchor = Entity()
    @State private var rightWristAnchor = Entity()
    @State private var infoCardAnchor = Entity()
    @State private var confirmAnchor = Entity()
    @State private var resetAnchor = Entity()
    @State private var hoverLabelAnchor = Entity()
    /// Glowing ring entity shown around the selected sphere for visual feedback
    @State private var selectionRingEntity: ModelEntity?

    private var visibleSongs: [SongData] {
        Array(songStore.songs.prefix(appSettings.maxVisibleSphereCount))
    }

    private var selectedSong: SongData? {
        guard let id = selectedSongId else { return nil }
        return visibleSongs.first { $0.id == id }
    }

    private var hoveredSong: SongData? {
        guard let id = hoveredSongId else { return nil }
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
            content.add(hoverLabelAnchor)

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

            // Selection ring (orbiting highlight around tapped sphere)
            let ring = SongSphereEntity.makeSelectionRing()
            ring.isEnabled = false
            rootEntity.addChild(ring)
            selectionRingEntity = ring

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
            if let hoverLabel = attachments.entity(for: "hoverLabel") {
                hoverLabelAnchor.addChild(hoverLabel)
                hoverLabelAnchor.isEnabled = false
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
            Attachment(id: "hoverLabel") {
                if let song = hoveredSong, hoveredSongId != selectedSongId {
                    SongHoverLabel(song: song)
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
        // Tap gesture to select a sphere
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let name = value.entity.name
                    if !name.isEmpty, visibleSongs.contains(where: { $0.id == name }) {
                        if selectedSongId == name {
                            selectedSongId = nil
                        } else {
                            selectedSongId = name
                        }
                    }
                }
        )
        // Hover gesture to detect gaze on a sphere and show its info
        .onContinuousHover(coordinateSpace: .global) { phase in
            // onContinuousHover doesn't give us the entity on RealityView.
            // We rely on the per-entity HoverEffectComponent for native gaze
            // feedback plus scene.raycast in the update loop instead.
        }
        .task {
            handTracking.updateSongList(visibleSongs)
            await handTracking.start()
        }
        .task {
            // Poll device gaze direction to find which sphere the user is looking at.
            // We raycast from the device anchor through the scene every frame.
            await pollGazeHover()
        }
    }

    /// Continuously checks which sphere the user is looking at using the device anchor
    /// (head position + gaze direction) and sets `hoveredSongId` accordingly.
    @MainActor
    private func pollGazeHover() async {
        // WorldTrackingProvider gives us the device anchor for gaze direction
        let worldTracking = WorldTrackingProvider()
        let session = ARKitSession()
        guard WorldTrackingProvider.isSupported else {
            print("ImmersiveView: WorldTrackingProvider not supported, gaze hover disabled")
            return
        }
        do {
            try await session.run([worldTracking])
        } catch {
            print("ImmersiveView: failed to start world tracking — \(error)")
            return
        }

        // Poll at ~20 Hz
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(50))
            guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
                continue
            }
            let deviceMatrix = deviceAnchor.originFromAnchorTransform
            let devicePos = SIMD3<Float>(deviceMatrix.columns.3.x, deviceMatrix.columns.3.y, deviceMatrix.columns.3.z)
            // Gaze direction: negative Z in the device's local coordinate space
            let gazeDir = -SIMD3<Float>(deviceMatrix.columns.2.x, deviceMatrix.columns.2.y, deviceMatrix.columns.2.z)

            // Find the closest sphere that the gaze ray passes near
            var bestId: String?
            var bestDist: Float = Float.greatestFiniteMagnitude
            let hitThreshold: Float = 0.12 // how close the ray must pass to the sphere center

            for song in visibleSongs {
                let sphereWorldPos = rootEntity.convert(position: song.position, to: nil)
                // Distance from the ray to the sphere center
                let toSphere = sphereWorldPos - devicePos
                let projLen = simd_dot(toSphere, gazeDir)
                if projLen < 0 { continue } // behind the user
                let closestPoint = devicePos + gazeDir * projLen
                let dist = simd_distance(closestPoint, sphereWorldPos)
                if dist < hitThreshold && projLen < bestDist {
                    bestDist = projLen
                    bestId = song.id
                }
            }
            hoveredSongId = bestId
        }
    }

    private func updateSceneState() {
        // ── Info card: attach near the user's left hand ──
        if let id = selectedSongId, let entity = songEntities[id] {
            let sphereWorldPos = rootEntity.convert(position: entity.position, to: nil)
            if let lt = handTracking.leftWristTransform {
                // Position the card slightly above and in front of the left wrist
                var cardPos = lt.translation
                cardPos.y += 0.18
                cardPos.z -= 0.06
                infoCardAnchor.position = cardPos
            } else {
                // Fallback: place above the sphere in world coordinates
                infoCardAnchor.position = sphereWorldPos + SIMD3<Float>(0, 0.18, 0)
            }
            infoCardAnchor.isEnabled = true

            // Selection ring follows selected sphere
            if let ring = selectionRingEntity {
                ring.position = entity.position
                ring.isEnabled = true
                // Slowly rotate the ring for visual flair
                let time = Float(Date.timeIntervalSinceReferenceDate)
                let angle = time * 1.5 // radians/sec
                ring.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            }
        } else {
            infoCardAnchor.isEnabled = false
            selectionRingEntity?.isEnabled = false
        }

        // ── Hover label follows the hovered sphere ──
        if let id = hoveredSongId, id != selectedSongId, let entity = songEntities[id] {
            let sphereWorldPos = rootEntity.convert(position: entity.position, to: nil)
            hoverLabelAnchor.position = sphereWorldPos + SIMD3<Float>(0, 0.12, 0)
            hoverLabelAnchor.isEnabled = true
        } else {
            hoverLabelAnchor.isEnabled = false
        }

        // ── Wrist attachments ──
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

        // ── Selection sphere ──
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

        // ── Highlight selected, hovered & hand-selected songs ──
        for song in visibleSongs {
            guard let entity = songEntities[song.id] else { continue }
            let isHighlighted = handTracking.selectedSongIds.contains(song.id)
            let isPlaying = audioService.currentSong?.id == song.id && audioService.isPlaying
            let isSelected = selectedSongId == song.id
            let isHovered = hoveredSongId == song.id
            SongSphereEntity.updateHighlight(
                entity: entity,
                song: song,
                highlighted: isHighlighted,
                playing: isPlaying,
                selected: isSelected,
                hovered: isHovered
            )
        }
    }

    private func resetScene() {
        audioService.stop()
        selectedSongId = nil
        hoveredSongId = nil
        handTracking.dismissSelection()
        for song in visibleSongs {
            if let entity = songEntities[song.id] {
                entity.position = song.position
            }
        }
    }
}
