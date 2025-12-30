//
//  FireballVolumeView.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI
import RealityKit

struct FireballVolumeView: View {
    var body: some View {
        RealityView { content in
            let root = Entity()
            
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.06),
                materials: [makeFireMaterial()]
            )
            
            let light = PointLight()
            light.light.intensity = 1500
            light.light.attenuationRadius = 1.0
            light.position = [0, 0, 0.15]
            
            root.addChild(sphere)
            root.addChild(light)
            
            root.position = [0, 0, 0.05]
            
            sphere.components.set(RotationComponent(speed: 0.8))
            
            RotationSystem.ensureRegistered()
            
            content.add(root)
        }
    }
    
    private func makeFireMaterial() -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .orange)
        m.emissiveColor = .init(color: .orange)
        m.emissiveIntensity = 2.0
        m.roughness = 0.2
        m.metallic = 0.0
        return m
    }
}
