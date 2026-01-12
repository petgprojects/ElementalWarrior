//
//  TeleportEffects.swift
//  ElementalWarrior
//
//  Simple gaze-based teleport marker visuals.
//

import RealityKit
import SwiftUI

#if os(macOS)
    import AppKit
    private typealias TeleportColor = NSColor
#else
    import UIKit
    private typealias TeleportColor = UIColor
#endif

@MainActor
func createTeleportMarker(radius: Float, thickness: Float) -> Entity {
    let root = Entity()
    root.name = "TeleportMarker"

    let mesh = MeshResource.generateCylinder(height: thickness, radius: radius)

    var material = UnlitMaterial()
    material.color = .init(tint: TeleportColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.9))
    material.blending = .transparent(opacity: .init(floatLiteral: 0.65))

    let disc = ModelEntity(mesh: mesh, materials: [material])
    disc.name = "TeleportMarkerDisc"
    root.addChild(disc)

    return root
}
