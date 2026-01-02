//
//  FireEffects.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//
//  Contains all fire-related particle effects: fireballs, trails, and explosions.
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

// MARK: - Explosion Effect

@MainActor
func createExplosionEffect() -> Entity {
    let rootEntity = Entity()
    rootEntity.name = "Explosion"

    // Layer 1: Bright white flash (instant, fades fast)
    let flash = createExplosionLayer(
        color: .white,
        birthRate: 2000,
        size: 0.15,
        speed: 0.8,
        lifeSpan: 0.15,
        burstDuration: 0.05
    )
    rootEntity.addChild(flash)

    // Layer 2: Yellow-orange fireball core
    let core = createExplosionLayer(
        color: PlatformColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),
        birthRate: 1500,
        size: 0.2,
        speed: 1.5,
        lifeSpan: 0.4,
        burstDuration: 0.1
    )
    rootEntity.addChild(core)

    // Layer 3: Orange-red expanding flame
    let flame = createExplosionLayer(
        color: PlatformColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0),
        birthRate: 800,
        size: 0.3,
        speed: 2.5,
        lifeSpan: 0.6,
        burstDuration: 0.15
    )
    rootEntity.addChild(flame)

    // Layer 4: Deep red outer burst
    let outer = createExplosionLayer(
        color: PlatformColor(red: 0.9, green: 0.15, blue: 0.0, alpha: 1.0),
        birthRate: 400,
        size: 0.4,
        speed: 3.0,
        lifeSpan: 0.8,
        burstDuration: 0.2
    )
    rootEntity.addChild(outer)

    // Layer 5: Smoke/debris (darker, longer lasting)
    let smoke = createExplosionSmokeLayer()
    rootEntity.addChild(smoke)

    // Point light for dramatic lighting
    let lightEntity = Entity()
    let pointLight = PointLightComponent(
        color: .orange,
        intensity: 10000,
        attenuationRadius: 8.0
    )
    lightEntity.components.set(pointLight)
    rootEntity.addChild(lightEntity)

    return rootEntity
}

private func createExplosionLayer(
    color: PlatformColor,
    birthRate: Float,
    size: Float,
    speed: Float,
    lifeSpan: Double,
    burstDuration: Double
) -> Entity {
    let entity = Entity()

    var emitter = ParticleEmitterComponent()
    emitter.timing = .once(warmUp: 0, emit: .init(duration: burstDuration))
    emitter.emitterShape = .sphere
    emitter.emitterShapeSize = [0.05, 0.05, 0.05]
    emitter.birthLocation = .surface
    emitter.birthDirection = .normal

    emitter.mainEmitter.birthRate = birthRate
    emitter.mainEmitter.lifeSpan = lifeSpan
    emitter.mainEmitter.lifeSpanVariation = lifeSpan * 0.3

    emitter.speed = speed
    emitter.speedVariation = speed * 0.4
    emitter.mainEmitter.acceleration = [0, -0.5, 0]

    emitter.mainEmitter.size = size
    emitter.mainEmitter.sizeVariation = size * 0.3
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 2.0

    let endColor = color.withAlphaComponent(0.0)
    emitter.mainEmitter.color = .evolving(
        start: .single(color),
        end: .single(endColor)
    )
    emitter.mainEmitter.blendMode = .additive

    emitter.mainEmitter.noiseStrength = 0.2
    emitter.mainEmitter.noiseAnimationSpeed = 2.0

    entity.components.set(emitter)
    return entity
}

private func createExplosionSmokeLayer() -> Entity {
    let entity = Entity()

    var emitter = ParticleEmitterComponent()
    emitter.timing = .once(warmUp: 0, emit: .init(duration: 0.3))
    emitter.emitterShape = .sphere
    emitter.emitterShapeSize = [0.1, 0.1, 0.1]

    emitter.mainEmitter.birthRate = 300
    emitter.mainEmitter.lifeSpan = 1.5
    emitter.mainEmitter.lifeSpanVariation = 0.5

    emitter.speed = 1.0
    emitter.speedVariation = 0.5
    emitter.mainEmitter.acceleration = [0, 0.3, 0]

    emitter.mainEmitter.size = 0.15
    emitter.mainEmitter.sizeVariation = 0.05
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 3.0

    emitter.mainEmitter.color = .evolving(
        start: .single(.init(red: 0.3, green: 0.25, blue: 0.2, alpha: 0.6)),
        end: .single(.init(red: 0.2, green: 0.15, blue: 0.1, alpha: 0.0))
    )
    emitter.mainEmitter.blendMode = .alpha

    emitter.mainEmitter.noiseStrength = 0.15
    emitter.mainEmitter.noiseAnimationSpeed = 0.8

    entity.components.set(emitter)
    return entity
}
