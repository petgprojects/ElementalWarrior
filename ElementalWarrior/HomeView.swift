//
//  HomeView.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI
import RealityKit

struct HomeView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    var body: some View {
        ZStack(alignment: .top) {
            // Fireball rendered inside the same window scene
            RealityView { content in
                let root = Entity()

                // Core sphere
                var mat = PhysicallyBasedMaterial()
                mat.baseColor = .init(tint: .orange)
                mat.emissiveColor = .init(color: .orange)
                mat.emissiveIntensity = 2.0
                mat.roughness = 0.2
                mat.metallic = 0.0

                let sphere = ModelEntity(
                    mesh: .generateSphere(radius: 0.06),
                    materials: [mat]
                )

                // Light to sell glow
                let light = PointLight()
                light.light.intensity = 1500
                light.light.attenuationRadius = 1.0
                light.position = [0, 0, 0.15]

                root.addChild(sphere)
                root.addChild(light)

                // Place the fireball slightly in front
                root.position = [0, 0, 0]

                content.add(root)
            }
            .frame(height: 180)
            .padding(.top, 10)
            .offset(z: 60)
            .allowsHitTesting(false)

            // Existing UI
            VStack(spacing: 16) {
                Text("Welcome to Elemental Warrior")
                    .font(.largeTitle)
                    .bold()

                Text("Master the elements. Enter the arena.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Start") {
                        Task {
                            _ = await openImmersiveSpace(id: "arena")
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Quit Immersion") {
                        Task {
                            await dismissImmersiveSpace()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, 160)
            .padding(32)
        }
    }
}
