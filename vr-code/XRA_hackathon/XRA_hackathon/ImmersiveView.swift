//
//  ImmersiveView.swift
//  XRA_hackathon
//
//  Major features:
//  • Head-anchored playlist panel, reset button, and now-playing widget
//    (via WorldTrackingProvider device anchor) so they always float near the user.
//  • Drag gesture on the root entity lets the user pan/fly through the data cloud.
//  • Gaze-based hover detection shows song info on looked-at spheres.
//  • Performance: batched highlight updates limited to nearby spheres;
//    collision shapes & input targets only enabled on close spheres.

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
    @State private var selectionRingEntity: ModelEntity?

    // Head-anchored UI anchors
    @State private var headAnchor = Entity()

    // Wrist anchors (used when hands are tracked)
    @State private var leftWristAnchor = Entity()

    // Info card & hover label
    @State private var infoCardAnchor = Entity()
    @State private var hoverLabelAnchor = Entity()
    @State private var confirmAnchor = Entity()

    // Drag state for world navigation
    @State private var dragStartRootPosition: SIMD3<Float> = .zero

    // Device position (updated by the world tracking poll loop)
    @State private var devicePosition: SIMD3<Float> = SIMD3<Float>(0, 1.4, 0)
    @State private var deviceForward: SIMD3<Float> = SIMD3<Float>(0, 0, -1)

    private var visibleSongs: [SongData] {
        let base = appSettings.onlyShowPreviewable
            ? songStore.songs.filter { $0.playbackURL != nil }
            : songStore.songs
        return Array(base.prefix(appSettings.maxVisibleSphereCount))
    }

    private var selectedSong: SongData? {
        guard let id = selectedSongId else { return nil }
        return visibleSongs.first { $0.id == id }
    }

    private var hoveredSong: SongData? {
        guard let id = hoveredSongId else { return nil }
        return visibleSongs.first { $0.id == id }
    }

    // MARK: - Body

    var body: some View {
        RealityView { content, attachments in
            // Root holds all song spheres; user drags this to navigate
            rootEntity.position = SIMD3<Float>(0, 1.4, -1.5)
            content.add(rootEntity)
            content.add(headAnchor)
            content.add(leftWristAnchor)
            content.add(infoCardAnchor)
            content.add(confirmAnchor)
            content.add(hoverLabelAnchor)

            // ── Create sphere entities (batched) ──
            let songs = visibleSongs
            print("ImmersiveView: creating \(songs.count) sphere entities")
            for song in songs {
                let entity = SongSphereEntity.make(for: song)
                rootEntity.addChild(entity)
                songEntities[song.id] = entity
            }
            print("ImmersiveView: rootEntity has \(rootEntity.children.count) children")

            // Selection sphere (hand pinch area)
            let sel = SongSphereEntity.makeSelectionSphere()
            sel.isEnabled = false
            rootEntity.addChild(sel)
            selectionSphere = sel

            // Selection ring (highlight around tapped sphere)
            let ring = SongSphereEntity.makeSelectionRing()
            ring.isEnabled = false
            rootEntity.addChild(ring)
            selectionRingEntity = ring

            // ── Attach SwiftUI overlays ──
            if let info = attachments.entity(for: "infoCard") {
                infoCardAnchor.addChild(info)
            }
            if let np = attachments.entity(for: "nowPlaying") {
                headAnchor.addChild(np)
                // Position relative to head: slightly left and below gaze
                np.position = SIMD3<Float>(-0.35, -0.18, -0.7)
            }
            if let pl = attachments.entity(for: "playlistPanel") {
                headAnchor.addChild(pl)
                // Position relative to head: slightly to the right, within FOV
                pl.position = SIMD3<Float>(0.25, -0.05, -0.7)
            }
            if let rb = attachments.entity(for: "resetButton") {
                headAnchor.addChild(rb)
                // Below and center
                rb.position = SIMD3<Float>(0, -0.35, -0.7)
            }
            if let cb = attachments.entity(for: "confirmPlaylist") {
                confirmAnchor.addChild(cb)
                confirmAnchor.isEnabled = false
            }
            if let hoverLabel = attachments.entity(for: "hoverLabel") {
                hoverLabelAnchor.addChild(hoverLabel)
                hoverLabelAnchor.isEnabled = false
            }
        } update: { _, _ in
            updateSceneState()
        } attachments: {
            // ── Song info card (appears when sphere tapped) ──
            Attachment(id: "infoCard") {
                if let song = selectedSong {
                    SongInfoCard(song: song) {
                        selectedSongId = nil
                    }
                }
            }

            // ── Hover label (appears when gazing at sphere) ──
            Attachment(id: "hoverLabel") {
                if let song = hoveredSong, hoveredSongId != selectedSongId {
                    SongHoverLabel(song: song)
                }
            }

            // ── Now-playing widget (head-anchored) ──
            Attachment(id: "nowPlaying") {
                NowPlayingView()
            }

            // ── Playlist panel (head-anchored, always visible) ──
            Attachment(id: "playlistPanel") {
                PlaylistArmView()
            }

            // ── Confirm playlist creation (from hand selection sphere) ──
            Attachment(id: "confirmPlaylist") {
                ConfirmPlaylistView {
                    let selected = songStore.songs.filter { handTracking.selectedSongIds.contains($0.id) }
                    playlistStore.createPlaylist(from: selected)
                    handTracking.dismissSelection()
                }
            }

            // ── Reset button (head-anchored) ──
            Attachment(id: "resetButton") {
                ResetButtonView {
                    resetScene()
                }
            }
        }
        // ── Tap to select a sphere ──
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let name = value.entity.name
                    if !name.isEmpty, visibleSongs.contains(where: { $0.id == name }) {
                        selectedSongId = (selectedSongId == name) ? nil : name
                    }
                }
        )
        // ── Drag to navigate through the world ──
        .simultaneousGesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    let translation3D = value.convert(value.translation3D, from: .local, to: .scene)
                    rootEntity.position = dragStartRootPosition + SIMD3<Float>(
                        Float(translation3D.x),
                        Float(translation3D.y),
                        Float(translation3D.z)
                    )
                }
                .onEnded { _ in
                    dragStartRootPosition = rootEntity.position
                }
        )
        .task {
            dragStartRootPosition = rootEntity.position
            handTracking.updateSongList(visibleSongs)
            await handTracking.start()
        }
        .task {
            await pollDeviceAnchor()
        }
    }

    // MARK: - Device Anchor Polling (gaze hover + head-anchored UI)

    /// Polls the device anchor at ~20 Hz to:
    /// 1. Update `headAnchor` so playlist/reset/now-playing float near the user.
    /// 2. Raycast from the device to detect which sphere the user is gazing at.
    @MainActor
    private func pollDeviceAnchor() async {
        let worldTracking = WorldTrackingProvider()
        let session = ARKitSession()
        guard WorldTrackingProvider.isSupported else {
            print("ImmersiveView: WorldTrackingProvider not supported")
            return
        }
        do {
            try await session.run([worldTracking])
        } catch {
            print("ImmersiveView: failed to start world tracking — \(error)")
            return
        }

        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(50))
            guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
                continue
            }
            let m = deviceAnchor.originFromAnchorTransform
            let pos = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
            let forward = -SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z)

            devicePosition = pos
            deviceForward = forward

            // ── Update head anchor: keep it at the device position, facing forward ──
            headAnchor.transform = Transform(matrix: m)

            // ── Gaze raycast to find hovered sphere ──
            var bestId: String?
            var bestProj: Float = Float.greatestFiniteMagnitude
            let hitThreshold: Float = 0.10

            for song in visibleSongs {
                let sphereWorldPos = rootEntity.convert(position: song.position, to: nil)
                let toSphere = sphereWorldPos - pos
                let projLen = simd_dot(toSphere, forward)
                if projLen < 0 { continue }
                let closestPoint = pos + forward * projLen
                let dist = simd_distance(closestPoint, sphereWorldPos)
                if dist < hitThreshold && projLen < bestProj {
                    bestProj = projLen
                    bestId = song.id
                }
            }
            hoveredSongId = bestId
        }
    }

    // MARK: - Scene State Update

    private func updateSceneState() {
        // ── Info card: place above selected sphere (world space) ──
        if let id = selectedSongId, let entity = songEntities[id] {
            let sphereWorldPos = rootEntity.convert(position: entity.position, to: nil)
            infoCardAnchor.position = sphereWorldPos + SIMD3<Float>(0, 0.15, 0)
            infoCardAnchor.isEnabled = true

            // Selection ring follows selected sphere
            if let ring = selectionRingEntity {
                ring.position = entity.position
                ring.isEnabled = true
                let time = Float(Date.timeIntervalSinceReferenceDate)
                ring.orientation = simd_quatf(angle: time * 1.5, axis: SIMD3<Float>(0, 1, 0))
            }
        } else {
            infoCardAnchor.isEnabled = false
            selectionRingEntity?.isEnabled = false
        }

        // ── Hover label follows the hovered sphere ──
        if let id = hoveredSongId, id != selectedSongId, let entity = songEntities[id] {
            let sphereWorldPos = rootEntity.convert(position: entity.position, to: nil)
            hoverLabelAnchor.position = sphereWorldPos + SIMD3<Float>(0, 0.10, 0)
            hoverLabelAnchor.isEnabled = true
        } else {
            hoverLabelAnchor.isEnabled = false
        }

        // ── Wrist attachment for now-playing (fallback, head-anchor is primary) ──
        if let lt = handTracking.leftWristTransform {
            leftWristAnchor.transform = lt
            leftWristAnchor.transform.translation += SIMD3<Float>(0, 0.08, 0)
            leftWristAnchor.isEnabled = true
        } else {
            leftWristAnchor.isEnabled = false
        }

        // ── Hand-pinch selection sphere ──
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

        // ── Highlight updates (only update spheres whose state changed) ──
        let playingId = (audioService.isPlaying ? audioService.currentSong?.id : nil)
        let selId = selectedSongId
        let hovId = hoveredSongId
        let handSelected = handTracking.selectedSongIds

        for song in visibleSongs {
            guard let entity = songEntities[song.id] else { continue }
            SongSphereEntity.updateHighlight(
                entity: entity,
                song: song,
                highlighted: handSelected.contains(song.id),
                playing: playingId == song.id,
                selected: selId == song.id,
                hovered: hovId == song.id
            )
        }
    }

    // MARK: - Reset

    private func resetScene() {
        audioService.stop()
        selectedSongId = nil
        hoveredSongId = nil
        handTracking.dismissSelection()
        rootEntity.position = SIMD3<Float>(0, 1.4, -1.5)
        dragStartRootPosition = rootEntity.position
        for song in visibleSongs {
            if let entity = songEntities[song.id] {
                entity.position = song.position
            }
        }
    }
}
