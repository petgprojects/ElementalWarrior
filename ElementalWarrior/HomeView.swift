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
        VStackLayout().depthAlignment(.front) {
            RealityView { content in
                let fireball = await createFireball()
                content.add(fireball)
            }
            .frame(height: 120)
            .frame(depth: 0.001, alignment: .front)
            .padding(.top, 24)
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

    private func createFireball() async -> Entity {
        let root = Entity()
        root.position = [0, 0, 0]

        // Load the fireball.usdz asset from the app bundle
        if let url = Bundle.main.url(forResource: "Fireball", withExtension: "usdz") {
            do {
                let fireballModel = try await Entity(contentsOf: url)
                fireballModel.scale = [0.5, 0.5, 0.5]
                fireballModel.name = "FireballModel"

                // Add rotation to the model
                fireballModel.components.set(RotationComponent(speed: 0.5))
                root.addChild(fireballModel)
            } catch {
                print("Failed to load Fireball.usdz: \(error)")
                let fallbackSphere = createFallbackSphere()
                root.addChild(fallbackSphere)
            }
        } else {
            print("Fireball.usdz not found in bundle - make sure it's added to Copy Bundle Resources")
            let fallbackSphere = createFallbackSphere()
            root.addChild(fallbackSphere)
        }

        // Create a particle emitter entity for flames
        let flameParticles = Entity()
        flameParticles.name = "FlameParticles"
        flameParticles.components.set(createFlameParticleEmitter())
        root.addChild(flameParticles)

        // Create a particle emitter entity for smoke
        let smokeParticles = Entity()
        smokeParticles.name = "SmokeParticles"
        smokeParticles.position = [0, 0.02, 0]
        smokeParticles.components.set(createSmokeParticleEmitter())
        root.addChild(smokeParticles)

        // Add point light for dynamic glow
        let light = PointLight()
        light.light.color = .init(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)
        light.light.intensity = 2000
        light.light.attenuationRadius = 1.0
        light.position = [0, 0, 0.1]
        root.addChild(light)

        RotationSystem.ensureRegistered()

        return root
    }

    private func createFlameParticleEmitter() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()

        // Emission shape - emit from the surface of the fireball
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.05, 0.05, 0.05]

        // Birth rate and lifespan
        emitter.mainEmitter.birthRate = 80
        emitter.mainEmitter.lifeSpan = 0.4
        emitter.mainEmitter.lifeSpanVariation = 0.15

        // Movement - flames rise upward
        emitter.speed = 0.08
        emitter.speedVariation = 0.03
        emitter.mainEmitter.acceleration = [0, 0.15, 0]

        // Size
        emitter.mainEmitter.size = 0.012
        emitter.mainEmitter.sizeVariation = 0.004
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.1

        // Color - yellow core fading to orange/red then transparent
        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 0.9, blue: 0.3, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.2, blue: 0.0, alpha: 0.0))
        )

        // Blend mode for fire effect
        emitter.mainEmitter.blendMode = .additive

        return emitter
    }

    private func createSmokeParticleEmitter() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()

        // Emission shape - smoke rises from above the fireball
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.03, 0.03, 0.03]

        // Birth rate and lifespan - smoke lingers longer
        emitter.mainEmitter.birthRate = 20
        emitter.mainEmitter.lifeSpan = 1.0
        emitter.mainEmitter.lifeSpanVariation = 0.3

        // Movement - smoke drifts upward slowly
        emitter.speed = 0.04
        emitter.speedVariation = 0.02
        emitter.mainEmitter.acceleration = [0, 0.05, 0]

        // Size - smoke expands as it rises
        emitter.mainEmitter.size = 0.015
        emitter.mainEmitter.sizeVariation = 0.005
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 2.5

        // Color - dark gray smoke fading to transparent
        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.6)),
            end: .single(.init(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.0))
        )

        // Alpha blend for realistic smoke
        emitter.mainEmitter.blendMode = .alpha

        return emitter
    }

    private func createFallbackSphere() -> ModelEntity {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0))
        material.emissiveColor = .init(color: .init(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0))
        material.emissiveIntensity = 3.0
        material.roughness = 0.2

        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [material]
        )
        sphere.name = "FallbackFireball"
        sphere.components.set(RotationComponent(speed: 0.5))
        return sphere
    }
}
