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
                fireballModel.scale = [2.5, 2.5, 2.5]
                fireballModel.name = "FireballModel"
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

        // MASSIVE particle effects - 7 layers like the handheld version

        // Layer 1: Outer flames
        let outerFlames = Entity()
        outerFlames.name = "OuterFlames"
        outerFlames.components.set(createOuterFlameParticles())
        root.addChild(outerFlames)

        // Layer 2: Mid flames
        let midFlames = Entity()
        midFlames.name = "MidFlames"
        midFlames.components.set(createMidFlameParticles())
        root.addChild(midFlames)

        // Layer 3: Inner core flames
        let innerFlames = Entity()
        innerFlames.name = "InnerFlames"
        innerFlames.components.set(createInnerFlameParticles())
        root.addChild(innerFlames)

        // Layer 4: Hot core
        let hotCore = Entity()
        hotCore.name = "HotCore"
        hotCore.components.set(createHotCoreParticles())
        root.addChild(hotCore)

        // Layer 5: Sparks
        let sparks = Entity()
        sparks.name = "Sparks"
        sparks.components.set(createSparkParticles())
        root.addChild(sparks)

        // Layer 6: Rising wisps
        let wisps = Entity()
        wisps.name = "Wisps"
        wisps.components.set(createWispParticles())
        root.addChild(wisps)

        // Layer 7: Smoke
        let smoke = Entity()
        smoke.name = "Smoke"
        smoke.position = [0, 0.06, 0]
        smoke.components.set(createSmokeParticles())
        root.addChild(smoke)

        // Bright point light
        let light = PointLight()
        light.light.color = .init(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)
        light.light.intensity = 6000
        light.light.attenuationRadius = 2.5
        light.position = [0, 0, 0.1]
        root.addChild(light)

        RotationSystem.ensureRegistered()

        return root
    }

    // MARK: - Particle Emitters

    private func createOuterFlameParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.14, 0.14, 0.14]

        emitter.mainEmitter.birthRate = 900
        emitter.mainEmitter.lifeSpan = 0.55
        emitter.mainEmitter.lifeSpanVariation = 0.2

        emitter.speed = 0.18
        emitter.speedVariation = 0.07
        emitter.mainEmitter.acceleration = [0, 0.45, 0]

        emitter.mainEmitter.size = 0.04
        emitter.mainEmitter.sizeVariation = 0.018
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.05

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.1, blue: 0.0, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createMidFlameParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.1, 0.1, 0.1]

        emitter.mainEmitter.birthRate = 700
        emitter.mainEmitter.lifeSpan = 0.4
        emitter.mainEmitter.lifeSpanVariation = 0.12

        emitter.speed = 0.12
        emitter.speedVariation = 0.05
        emitter.mainEmitter.acceleration = [0, 0.3, 0]

        emitter.mainEmitter.size = 0.032
        emitter.mainEmitter.sizeVariation = 0.012
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.1

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.3, blue: 0.0, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createInnerFlameParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.06, 0.06, 0.06]

        emitter.mainEmitter.birthRate = 600
        emitter.mainEmitter.lifeSpan = 0.28
        emitter.mainEmitter.lifeSpanVariation = 0.1

        emitter.speed = 0.07
        emitter.speedVariation = 0.025
        emitter.mainEmitter.acceleration = [0, 0.18, 0]

        emitter.mainEmitter.size = 0.026
        emitter.mainEmitter.sizeVariation = 0.01
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.15

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 1.0, blue: 0.7, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.5, blue: 0.1, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createHotCoreParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.035, 0.035, 0.035]

        emitter.mainEmitter.birthRate = 500
        emitter.mainEmitter.lifeSpan = 0.18
        emitter.mainEmitter.lifeSpanVariation = 0.06

        emitter.speed = 0.035
        emitter.speedVariation = 0.015
        emitter.mainEmitter.acceleration = [0, 0.06, 0]

        emitter.mainEmitter.size = 0.018
        emitter.mainEmitter.sizeVariation = 0.006
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.3

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.9, blue: 0.5, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createSparkParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.12, 0.12, 0.12]

        emitter.mainEmitter.birthRate = 250
        emitter.mainEmitter.lifeSpan = 0.65
        emitter.mainEmitter.lifeSpanVariation = 0.3

        emitter.speed = 0.35
        emitter.speedVariation = 0.18
        emitter.mainEmitter.acceleration = [0, 0.9, 0]

        emitter.mainEmitter.size = 0.01
        emitter.mainEmitter.sizeVariation = 0.005
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.0

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 0.9, blue: 0.5, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.3, blue: 0.0, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createWispParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.12, 0.12, 0.12]

        emitter.mainEmitter.birthRate = 180
        emitter.mainEmitter.lifeSpan = 0.55
        emitter.mainEmitter.lifeSpanVariation = 0.22

        emitter.speed = 0.25
        emitter.speedVariation = 0.12
        emitter.mainEmitter.acceleration = [0, 0.7, 0]

        emitter.mainEmitter.size = 0.024
        emitter.mainEmitter.sizeVariation = 0.012
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.02

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.85)),
            end: .single(.init(red: 1.0, green: 0.2, blue: 0.0, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createSmokeParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.08, 0.08, 0.08]

        emitter.mainEmitter.birthRate = 100
        emitter.mainEmitter.lifeSpan = 1.2
        emitter.mainEmitter.lifeSpanVariation = 0.35

        emitter.speed = 0.1
        emitter.speedVariation = 0.04
        emitter.mainEmitter.acceleration = [0, 0.15, 0]

        emitter.mainEmitter.size = 0.035
        emitter.mainEmitter.sizeVariation = 0.015
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 3.5

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 0.22, green: 0.17, blue: 0.12, alpha: 0.45)),
            end: .single(.init(red: 0.12, green: 0.1, blue: 0.08, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .alpha
        return emitter
    }

    private func createFallbackSphere() -> ModelEntity {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0))
        material.emissiveColor = .init(color: .init(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0))
        material.emissiveIntensity = 5.0
        material.roughness = 0.1

        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.06),
            materials: [material]
        )
        sphere.name = "FallbackFireball"
        sphere.components.set(RotationComponent(speed: 0.5))
        return sphere
    }
}
