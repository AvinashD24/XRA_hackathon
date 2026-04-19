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
    var selected: Bool
    var hovered: Bool
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
        entity.components.set(HighlightState(highlighted: false, playing: false, selected: false, hovered: false))
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

    /// Creates a ring/torus-like visual to orbit around the selected sphere for extra tap feedback.
    /// Since RealityKit doesn't have a torus mesh, we use a thin, flat box "ring" (4 thin planes arranged as a square frame).
    /// Alternatively we just use a larger semi-transparent sphere with an emissive look.
    static func makeSelectionRing() -> ModelEntity {
        // Use a slightly larger sphere with a pulsing transparent bright color
        let mesh = MeshResource.generateSphere(radius: baseRadius * 2.2)
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(red: 0.3, green: 0.85, blue: 1.0, alpha: 0.15))
        material.blending = .transparent(opacity: 0.15)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "selectionRing"
        return entity
    }

    static func updateHighlight(entity: ModelEntity, song: SongData, highlighted: Bool, playing: Bool, selected: Bool = false, hovered: Bool = false) {
        let next = HighlightState(highlighted: highlighted, playing: playing, selected: selected, hovered: hovered)
        if entity.components[HighlightState.self] == next { return }
        entity.components.set(next)

        let tint: UIColor
        if selected {
            // Bright white-cyan glow for the tapped/selected sphere
            tint = UIColor(red: 0.6, green: 0.95, blue: 1.0, alpha: 1.0)
        } else if playing {
            tint = UIColor.white
        } else if hovered {
            // Slightly brighter highlight on hover/gaze
            tint = UIColor(red: 0.5, green: 0.85, blue: 1.0, alpha: 1.0)
        } else if highlighted {
            tint = UIColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 1.0)
        } else {
            tint = color(for: song.position)
        }
        var mat = SimpleMaterial(color: tint, isMetallic: selected)
        if selected || playing || highlighted || hovered {
            mat.roughness = .init(floatLiteral: selected ? 0.0 : 0.1)
        }
        entity.model?.materials = [mat]

        // Scale: selected is the biggest, then playing/highlighted, then hovered, then default
        let scale: Float
        if selected {
            scale = 1.8
        } else if playing || highlighted {
            scale = 1.4
        } else if hovered {
            scale = 1.25
        } else {
            scale = 1.0
        }
        entity.scale = SIMD3<Float>(repeating: scale)
    }

    private static func color(for position: SIMD3<Float>) -> UIColor {
        let hue = CGFloat(max(0, min(1, (position.x + 2.0) / 4.0)))
        let sat = CGFloat(max(0.5, min(1, (position.y + 2.0) / 4.0)))
        let bri = CGFloat(max(0.6, min(1, (position.z + 2.0) / 4.0)))
        return UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 1.0)
    }
}
