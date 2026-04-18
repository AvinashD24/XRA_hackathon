//
//  GraphNode.swift
//  XRA_hackathon
//
//  Created by iguest on 4/18/26.
//

import RealityKit
import Foundation

struct GraphNode {
    let trackId: String
    var position: SIMD3<Float>
    let artist: String
    let title: String
    let playbackURL: URL?
    let photoURL: URL?
    // MARK: - State
    var originalPosition: SIMD3<Float>
    var isSelected: Bool = false
    var entity: ModelEntity
}
