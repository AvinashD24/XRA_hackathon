//
//  ImmersiveView.swift
//  XRA_hackathon
//
//  • Head-anchored playlist and now-playing panels (lower, tilted, centered).
//  • Both panels are draggable so the user can reposition them.
//  • Drag gesture on spheres lets the user pan/fly through the data cloud.
//  • Gaze-based hover shows album art billboard on the looked-at sphere.
//  • No reset button.

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

    // Head-anchored UI anchor
    @State private var headAnchor = Entity()

    // Info card & hover label
    @State private var infoCardAnchor = Entity()
    @State private var hoverLabelAnchor = Entity()
    @State private var confirmAnchor = Entity()

    // Album art billboard entity (a single plane placed at hovered sphere)
    @State private var albumBillboard: ModelEntity?
    @State private var currentBillboardSongId: String?
    @State private var albumTextureCache: [String: TextureResource] = [:]

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
            rootEntity.position = SIMD3<Float>(0, 1.4, -1.5)
            content.add(rootEntity)
            content.add(headAnchor)
            content.add(infoCardAnchor)
            content.add(confirmAnchor)
            content.add(hoverLabelAnchor)

            // ── Create sphere entities ──
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

            // Album art billboard: a single reusable plane entity
            let billboard = SongSphereEntity.makeAlbumBillboard()
            billboard.isEnabled = false
            rootEntity.addChild(billboard)
            albumBillboard = billboard

            // ── Attach SwiftUI overlays ──
            if let info = attachments.entity(for: "infoCard") {
                infoCardAnchor.addChild(info)
            }
            if let np = attachments.entity(for: "nowPlaying") {
                headAnchor.addChild(np)
                // Lower, centered, tilted up so user can glance down
                np.position = SIMD3<Float>(-0.12, -0.32, -0.55)
                np.orientation = simd_quatf(angle: -0.35, axis: SIMD3<Float>(1, 0, 0))
            }
            if let pl = attachments.entity(for: "playlistPanel") {
                headAnchor.addChild(pl)
                // Slightly right of center, low, tilted up
                pl.position = SIMD3<Float>(0.12, -0.32, -0.55)
                pl.orientation = simd_quatf(angle: -0.35, axis: SIMD3<Float>(1, 0, 0))
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

            // ── Now-playing widget (head-anchored, draggable) ──
            Attachment(id: "nowPlaying") {
                NowPlayingView()
            }

            // ── Playlist panel (head-anchored, draggable) ──
            Attachment(id: "playlistPanel") {
                PlaylistArmView()
            }

            // ── Confirm playlist creation ──
            Attachment(id: "confirmPlaylist") {
                ConfirmPlaylistView {
                    let selected = songStore.songs.filter { handTracking.selectedSongIds.contains($0.id) }
                    playlistStore.createPlaylist(from: selected)
                    handTracking.dismissSelection()
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
        // ── Drag to navigate through the world or reposition panels ──
        .simultaneousGesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    let entity = value.entity

                    // If the user drags a head-anchored panel, reposition it locally
                    if entity.parent == headAnchor || entity.parent?.parent == headAnchor {
                        let panelEntity = (entity.parent == headAnchor) ? entity : entity.parent!
                        let translation3D = value.convert(value.translation3D, from: .local, to: .scene)
                        panelEntity.position = panelEntity.position + SIMD3<Float>(
                            Float(translation3D.x) * 0.002,
                            Float(translation3D.y) * 0.002,
                            Float(translation3D.z) * 0.002
                        )
                        return
                    }

                    // Otherwise drag the whole world
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

            // Update head anchor to follow device
            headAnchor.transform = Transform(matrix: m)

            // Gaze raycast to find hovered sphere
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

            let newHoveredId = bestId
            if newHoveredId != hoveredSongId {
                hoveredSongId = newHoveredId
                // Load album art for the new hovered sphere (async, off main)
                if let id = newHoveredId, id != currentBillboardSongId,
                   let song = visibleSongs.first(where: { $0.id == id }),
                   let photoURL = song.photoURL {
                    loadAlbumTexture(songId: id, url: photoURL)
                }
            }
        }
    }

    // MARK: - Album Art Billboard

    /// Asynchronously loads album art texture and applies it to the billboard entity.
    /// Uses a simple in-memory cache so we don't reload the same image.
    private func loadAlbumTexture(songId: String, url: URL) {
        // Check cache first
        if let cached = albumTextureCache[songId] {
            applyBillboardTexture(cached, songId: songId)
            return
        }

        Task.detached(priority: .utility) {
            do {
                let texture = try await TextureResource(contentsOf: url)
                await MainActor.run {
                    // Cache it (limit cache to 30 entries to save memory)
                    if albumTextureCache.count > 30 {
                        albumTextureCache.removeAll()
                    }
                    albumTextureCache[songId] = texture
                    applyBillboardTexture(texture, songId: songId)
                }
            } catch {
                // Silently fail — the hover label still shows info
            }
        }
    }

    @MainActor
    private func applyBillboardTexture(_ texture: TextureResource, songId: String) {
        guard let billboard = albumBillboard else { return }
        // Only apply if this song is still the hovered one
        guard hoveredSongId == songId else { return }

        var mat = UnlitMaterial()
        mat.color = .init(texture: .init(texture))
        billboard.model?.materials = [mat]
        currentBillboardSongId = songId
    }

    // MARK: - Scene State Update

    private func updateSceneState() {
        // ── Info card: place above selected sphere ──
        if let id = selectedSongId, let entity = songEntities[id] {
            let sphereWorldPos = rootEntity.convert(position: entity.position, to: nil)
            infoCardAnchor.position = sphereWorldPos + SIMD3<Float>(0, 0.15, 0)
            infoCardAnchor.isEnabled = true

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

        // ── Album art billboard follows the hovered sphere ──
        if let billboard = albumBillboard {
            if let id = hoveredSongId, let entity = songEntities[id] {
                billboard.position = entity.position + SIMD3<Float>(0, SongSphereEntity.baseRadius * 1.8, 0)
                billboard.isEnabled = true
                // Billboard always faces the user (camera)
                let billboardWorld = rootEntity.convert(position: billboard.position, to: nil)
                let toUser = simd_normalize(devicePosition - billboardWorld)
                let yaw = atan2(toUser.x, toUser.z)
                billboard.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            } else {
                billboard.isEnabled = false
                currentBillboardSongId = nil
            }
        }

        // ── Hover label follows the hovered sphere ──
        if let id = hoveredSongId, id != selectedSongId, let entity = songEntities[id] {
            let sphereWorldPos = rootEntity.convert(position: entity.position, to: nil)
            hoverLabelAnchor.position = sphereWorldPos + SIMD3<Float>(0, 0.10, 0)
            hoverLabelAnchor.isEnabled = true
        } else {
            hoverLabelAnchor.isEnabled = false
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

        // ── Highlight updates ──
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
}
