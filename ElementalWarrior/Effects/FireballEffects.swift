//
//  FireballEffects.swift
//  ElementalWarrior
//
//  Fireball and fire trail particle effects.
//

import RealityKit
import SwiftUI

#if os(macOS)
    import AppKit
    typealias PlatformColor = NSColor
#else
    import UIKit
    typealias PlatformColor = UIColor
#endif

// MARK: - Fireball Effect

/// Creates a multi-layered realistic fireball effect with 4 particle layers and dynamic lighting
@MainActor
func createRealisticFireball(scale: Float = 1.0) -> Entity {
    let rootEntity = Entity()
    rootEntity.name = "RealisticFireball"

    // 1. Rigid Core (White Hot) - Small, intense center
    let whiteCore = createFlameEmitter(
        color: .white,
        birthRate: 1000,
        size: 0.025 * scale,
        speed: 0.02 * scale,
        acceleration: [0, 0.0, 0],
        lifeSpan: 0.3,
        spreadingAngle: 0.0,
        noiseStrength: 0.0 * scale,
        scale: scale
    )
    rootEntity.addChild(whiteCore)

    // 2. Inner Flame (Yellow/Orange) - The main body
    let innerFlame = createFlameEmitter(
        color: .yellow,
        birthRate: 600,
        size: 0.06 * scale,
        speed: 0.1 * scale,
        acceleration: [0, 0.2 * scale, 0],
        lifeSpan: 0.6,
        spreadingAngle: 0.2,
        noiseStrength: 0.02 * scale,
        scale: scale
    )
    rootEntity.addChild(innerFlame)

    // 3. Rising Spikes (Orange/Red) - Fast moving tongues of fire
    let spikes = createFlameEmitter(
        color: PlatformColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0),
        birthRate: 400,
        size: 0.05 * scale,
        speed: 0.5 * scale,
        acceleration: [0, 1.2 * scale, 0],
        lifeSpan: 0.5,
        spreadingAngle: 0.1,
        noiseStrength: 0.15 * scale,
        scale: scale
    )
    rootEntity.addChild(spikes)

    // 4. Outer Flame/Smoke (Deep Red) - Volume and trail
    let outerFlame = createFlameEmitter(
        color: PlatformColor(red: 0.8, green: 0.1, blue: 0.0, alpha: 1.0),
        birthRate: 200,
        size: 0.12 * scale,
        speed: 0.3 * scale,
        acceleration: [0, 0.4 * scale, 0],
        lifeSpan: 0.9,
        spreadingAngle: 0.4,
        noiseStrength: 0.08 * scale,
        scale: scale
    )
    rootEntity.addChild(outerFlame)

    // 5. Add a Point Light to cast light on surroundings
    let lightEntity = Entity()
    let pointLight = PointLightComponent(color: .orange, intensity: 2000, attenuationRadius: 4.0 * scale)
    lightEntity.components.set(pointLight)
    rootEntity.addChild(lightEntity)

    return rootEntity
}

/// Creates a single flame emitter layer with specified properties
private func createFlameEmitter(
    color: PlatformColor,
    birthRate: Float,
    size: Float,
    speed: Float,
    acceleration: SIMD3<Float>,
    lifeSpan: Double,
    spreadingAngle: Float,
    noiseStrength: Float,
    scale: Float
) -> Entity {
    let entity = Entity()

    var particles = ParticleEmitterComponent()

    particles.timing = .repeating(warmUp: 1.0, emit: .init(duration: 10000.0))
    particles.emitterShape = .sphere
    particles.birthLocation = .volume
    particles.birthDirection = .local
    particles.emissionDirection = [0, 1, 0]
    particles.mainEmitter.spreadingAngle = spreadingAngle
    particles.emitterShapeSize = SIMD3<Float>(repeating: size)

    particles.mainEmitter.birthRate = birthRate
    particles.mainEmitter.size = size
    particles.mainEmitter.lifeSpan = lifeSpan

    let startColor = color
    let endColor = color.withAlphaComponent(0.0)

    particles.mainEmitter.color = .evolving(
        start: .single(startColor),
        end: .single(endColor)
    )

    particles.speed = speed
    particles.mainEmitter.acceleration = acceleration
    particles.mainEmitter.noiseStrength = noiseStrength
    particles.mainEmitter.noiseAnimationSpeed = 1.0
    particles.mainEmitter.noiseScale = 2.0 * scale
    particles.mainEmitter.blendMode = .additive
    particles.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.1

    entity.components.set(particles)
    return entity
}

// MARK: - Fire Trail Effect

/// Creates a fire trail effect for flying projectiles
@MainActor
func createFireTrail() -> Entity {
    let trailEntity = Entity()
    trailEntity.name = "FireTrail"

    var emitter = ParticleEmitterComponent()
    emitter.emitterShape = .sphere
    emitter.emitterShapeSize = [0.02, 0.02, 0.02]

    emitter.mainEmitter.birthRate = 800
    emitter.mainEmitter.lifeSpan = 0.4
    emitter.mainEmitter.lifeSpanVariation = 0.1

    emitter.speed = 0.05
    emitter.speedVariation = 0.03
    emitter.mainEmitter.acceleration = [0, 0.3, 0]

    emitter.mainEmitter.size = 0.04
    emitter.mainEmitter.sizeVariation = 0.02
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.2

    emitter.mainEmitter.color = .evolving(
        start: .single(.init(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.9)),
        end: .single(.init(red: 0.8, green: 0.2, blue: 0.0, alpha: 0.0))
    )
    emitter.mainEmitter.blendMode = .additive

    emitter.mainEmitter.noiseStrength = 0.05
    emitter.mainEmitter.noiseAnimationSpeed = 1.5

    trailEntity.components.set(emitter)
    return trailEntity
}

// MARK: - Smoke Puff Effect

/// Creates a smoke puff effect for when fireballs extinguish
@MainActor
func createSmokePuff() -> Entity {
    let puff = Entity()
    puff.name = "SmokePuff"
    puff.components.set(createSmokePuffEmitter())
    return puff
}

/// Creates the particle emitter component for smoke puffs
func createSmokePuffEmitter() -> ParticleEmitterComponent {
    var emitter = ParticleEmitterComponent()
    emitter.emitterShape = .sphere
    emitter.emitterShapeSize = [0.025, 0.025, 0.025]

    emitter.mainEmitter.birthRate = 2000
    emitter.mainEmitter.lifeSpan = 2.0
    emitter.mainEmitter.lifeSpanVariation = 0.5

    emitter.speed = 0.05
    emitter.speedVariation = 0.04
    emitter.mainEmitter.acceleration = [0, 0.05, 0]

    emitter.mainEmitter.noiseStrength = 0.1
    emitter.mainEmitter.noiseAnimationSpeed = 0.5
    emitter.mainEmitter.noiseScale = 1.0

    emitter.mainEmitter.size = 0.01
    emitter.mainEmitter.sizeVariation = 0.005
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 2.0

    emitter.mainEmitter.color = .evolving(
        start: .single(.init(red: 0.4, green: 0.35, blue: 0.3, alpha: 0.5)),
        end: .single(.init(red: 0.25, green: 0.22, blue: 0.18, alpha: 0.0))
    )
    emitter.mainEmitter.blendMode = .alpha

    return emitter
}
