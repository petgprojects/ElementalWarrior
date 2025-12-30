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
        // Use a 3D layout container so RealityView doesn't push the 2D content forward.
        VStackLayout().depthAlignment(.front) {
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

                // Keep the entity centered in the view
                root.position = [0, 0, 0]

                content.add(root)
            }
            .frame(height: 120)
            // Make the RealityView effectively planar so it doesn't consume window depth.
            .frame(depth: 0.001, alignment: .front)
            .padding(.top, 24)
//            .offset(y: 30)
            .allowsHitTesting(false)

            Color.clear.frame(height: 12)

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
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(32)
        }
    }
}
