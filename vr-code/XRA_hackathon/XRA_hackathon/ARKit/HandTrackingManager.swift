//
//  HandTrackingManager.swift
//  XRA_hackathon
//

import Foundation
import ARKit
import RealityKit
import simd
import Observation

enum SelectionPhase: Equatable {
    case idle
    case forming
    case confirming
}

@MainActor
@Observable
final class HandTrackingManager {
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()

    var leftWristTransform: Transform?
    var rightWristTransform: Transform?

    // Pinch state (index tip close to thumb tip)
    var leftPinching: Bool = false
    var rightPinching: Bool = false

    // Fingertip positions (world space)
    var leftIndexTip: SIMD3<Float>?
    var rightIndexTip: SIMD3<Float>?

    // Selection sphere
    var selectionPhase: SelectionPhase = .idle
    var selectionCenter: SIMD3<Float> = .zero
    var selectionRadius: Float = 0
    var selectedSongIds: Set<String> = []

    private var allSongs: [SongData] = []

    func updateSongList(_ songs: [SongData]) {
        allSongs = songs
    }

    func start() async {
        guard HandTrackingProvider.isSupported else {
            print("HandTrackingManager: hand tracking not supported on this device")
            return
        }
        do {
            try await session.run([handTracking])
            await processUpdates()
        } catch {
            print("HandTrackingManager: failed to start — \(error)")
        }
    }

    private func processUpdates() async {
        for await update in handTracking.anchorUpdates {
            let anchor = update.anchor
            guard anchor.isTracked, let skeleton = anchor.handSkeleton else { continue }

            let wristJoint = skeleton.joint(.wrist)
            let wristWorld = anchor.originFromAnchorTransform * wristJoint.anchorFromJointTransform
            let wristTransform = Transform(matrix: wristWorld)

            let indexTipJoint = skeleton.joint(.indexFingerTip)
            let thumbTipJoint = skeleton.joint(.thumbTip)
            let indexWorld = anchor.originFromAnchorTransform * indexTipJoint.anchorFromJointTransform
            let thumbWorld = anchor.originFromAnchorTransform * thumbTipJoint.anchorFromJointTransform
            let indexPos = SIMD3<Float>(indexWorld.columns.3.x, indexWorld.columns.3.y, indexWorld.columns.3.z)
            let thumbPos = SIMD3<Float>(thumbWorld.columns.3.x, thumbWorld.columns.3.y, thumbWorld.columns.3.z)
            let isPinching = distance(indexPos, thumbPos) < 0.03

            switch anchor.chirality {
            case .left:
                leftWristTransform = wristTransform
                leftIndexTip = indexPos
                leftPinching = isPinching
            case .right:
                rightWristTransform = wristTransform
                rightIndexTip = indexPos
                rightPinching = isPinching
            }

            updateSelection()
        }
    }

    private func updateSelection() {
        guard let l = leftIndexTip, let r = rightIndexTip else {
            if selectionPhase != .confirming { selectionPhase = .idle }
            return
        }

        let bothPinching = leftPinching && rightPinching
        let midpoint = (l + r) / 2
        let separation = distance(l, r) / 2

        switch selectionPhase {
        case .idle:
            if bothPinching && distance(l, r) < 0.15 {
                selectionPhase = .forming
                selectionCenter = midpoint
                selectionRadius = separation
            }
        case .forming:
            if bothPinching {
                selectionCenter = midpoint
                selectionRadius = separation
                selectedSongIds = Set(
                    allSongs
                        .filter { distance($0.position, selectionCenter) <= selectionRadius }
                        .map(\.id)
                )
            } else {
                selectionPhase = selectedSongIds.isEmpty ? .idle : .confirming
            }
        case .confirming:
            break
        }
    }

    func dismissSelection() {
        selectionPhase = .idle
        selectionRadius = 0
        selectedSongIds = []
    }
}
