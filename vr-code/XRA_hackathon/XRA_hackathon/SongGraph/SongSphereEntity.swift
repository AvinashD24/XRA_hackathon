//
//  SongSphereEntity.swift
//  XRA_hackathon
//
//  Performance-optimised sphere factory.
//  Spheres share a single MeshResource and use PhysicallyBasedMaterial
//  with translucent blending + low roughness for a shiny, glowing look.

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

    static let baseRadius: Float = 0.025
    private static let selectionBaseRadius: Float = 0.1

    // ── Shared mesh: created once, used by every sphere ──
    private static let sharedMesh: MeshResource = {
        MeshResource.generateSphere(radius: baseRadius)
    }()

    // MARK: - Factory

    static func make(for song: SongData) -> ModelEntity {
        let material = shinyGlowMaterial(tint: color(for: song.position))
        let entity = ModelEntity(mesh: sharedMesh, materials: [material])
        entity.name = song.id
        entity.position = song.position
        entity.components.set(InputTargetComponent(allowedInputTypes: .all))
        entity.components.set(HoverEffectComponent())
        entity.components.set(HighlightState(highlighted: false, playing: false, selected: false, hovered: false))
        entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: baseRadius)]))
        return entity
    }

    // MARK: - Utility entities

    static func makeSelectionSphere() -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: selectionBaseRadius)
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.2))
        material.blending = .transparent(opacity: 0.2)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "selectionSphere"
        return entity
    }

    static func makeSelectionRing() -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: baseRadius * 3.0)
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(red: 0.3, green: 0.85, blue: 1.0, alpha: 0.12))
        material.blending = .transparent(opacity: 0.12)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "selectionRing"
        return entity
    }

    // MARK: - Material helpers

    /// Creates a shiny, translucent PhysicallyBasedMaterial.
    /// Low roughness + metallic = reflective/glossy surface.
    /// Transparent blending = see-through glow.
    private static func shinyGlowMaterial(
        tint: UIColor,
        opacity: Float = 0.75,
        roughness: Float = 0.15,
        metallic: Float = 0.6
    ) -> PhysicallyBasedMaterial {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: tint)
        mat.roughness = .init(floatLiteral: roughness)
        mat.metallic = .init(floatLiteral: metallic)
        mat.blending = .transparent(opacity: .init(floatLiteral: opacity))
        // Emissive adds a self-illuminating glow so the spheres look lit from within
        mat.emissiveColor = .init(color: tint)
        mat.emissiveIntensity = 0.3
        return mat
    }

    // MARK: - Highlight / state update

    static func updateHighlight(entity: ModelEntity, song: SongData, highlighted: Bool, playing: Bool, selected: Bool = false, hovered: Bool = false) {
        let next = HighlightState(highlighted: highlighted, playing: playing, selected: selected, hovered: hovered)
        if entity.components[HighlightState.self] == next { return }
        entity.components.set(next)

        let tint: UIColor
        let opacity: Float
        let roughness: Float
        let metallic: Float

        if selected {
            tint = UIColor(red: 0.6, green: 0.95, blue: 1.0, alpha: 1.0)
            opacity = 1.0
            roughness = 0.0
            metallic = 1.0
        } else if playing {
            tint = UIColor.white
            opacity = 1.0
            roughness = 0.05
            metallic = 0.9
        } else if hovered {
            tint = UIColor(red: 0.5, green: 0.85, blue: 1.0, alpha: 1.0)
            opacity = 0.9
            roughness = 0.1
            metallic = 0.7
        } else if highlighted {
            tint = UIColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 1.0)
            opacity = 0.9
            roughness = 0.1
            metallic = 0.7
        } else {
            tint = color(for: song.position)
            opacity = 0.75
            roughness = 0.15
            metallic = 0.6
        }

        entity.model?.materials = [shinyGlowMaterial(tint: tint, opacity: opacity, roughness: roughness, metallic: metallic)]

        let scale: Float
        if selected {
            scale = 2.0
        } else if playing || highlighted {
            scale = 1.5
        } else if hovered {
            scale = 1.3
        } else {
            scale = 1.0
        }
        entity.scale = SIMD3<Float>(repeating: scale)
    }

    // MARK: - Colour mapping

    static func color(for position: SIMD3<Float>) -> UIColor {
        let hue = CGFloat(max(0, min(1, (position.x + 2.0) / 4.0)))
        let sat = CGFloat(max(0.5, min(1, (position.y + 2.0) / 4.0)))
        let bri = CGFloat(max(0.6, min(1, (position.z + 2.0) / 4.0)))
        return UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 1.0)
    }
}
