//
//  SongSphereEntity.swift
//  XRA_hackathon
//

import Foundation
import RealityKit
import SwiftUI
import simd

private struct HighlightState: Component, Equatable {
    var highlighted: Bool
    var playing: Bool
}

enum SongSphereEntity {

    private static let baseRadius: Float = 0.06
    private static let selectionBaseRadius: Float = 0.1

    static func make(for song: SongData) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: baseRadius)
        let material = SimpleMaterial(color: color(for: song.position), isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = song.id
        entity.position = song.position
        entity.components.set(InputTargetComponent(allowedInputTypes: .all))
        entity.components.set(HoverEffectComponent())
        entity.components.set(HighlightState(highlighted: false, playing: false))
        entity.generateCollisionShapes(recursive: false)
        return entity
    }

    static func makeSelectionSphere() -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: selectionBaseRadius)
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.2))
        material.blending = .transparent(opacity: 0.2)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "selectionSphere"
        return entity
    }

    static func updateHighlight(entity: ModelEntity, song: SongData, highlighted: Bool, playing: Bool) {
        let next = HighlightState(highlighted: highlighted, playing: playing)
        if entity.components[HighlightState.self] == next { return }
        entity.components.set(next)

        let tint: UIColor
        if playing {
            tint = UIColor.white
        } else if highlighted {
            tint = UIColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 1.0)
        } else {
            tint = color(for: song.position)
        }
        var mat = SimpleMaterial(color: tint, isMetallic: false)
        if playing || highlighted {
            mat.roughness = .init(floatLiteral: 0.1)
        }
        entity.model?.materials = [mat]

        let scale: Float = (playing || highlighted) ? 1.4 : 1.0
        entity.scale = SIMD3<Float>(repeating: scale)
    }

    private static func color(for position: SIMD3<Float>) -> UIColor {
        let hue = CGFloat(max(0, min(1, (position.x + 2.0) / 4.0)))
        let sat = CGFloat(max(0.5, min(1, (position.y + 2.0) / 4.0)))
        let bri = CGFloat(max(0.6, min(1, (position.z + 2.0) / 4.0)))
        return UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 1.0)
    }
}
