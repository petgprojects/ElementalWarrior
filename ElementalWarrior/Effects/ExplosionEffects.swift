//
//  ExplosionEffects.swift
//  ElementalWarrior
//
//  Explosion particle effects with multi-layered fire and smoke.
//

import RealityKit
import SwiftUI

#if os(macOS)
    import AppKit
    private typealias ExplosionPlatformColor = NSColor
#else
    import UIKit
    private typealias ExplosionPlatformColor = UIColor
#endif

// MARK: - Explosion Effect

/// Creates a 5-layer explosion effect with flash, core, flame, outer burst, and smoke
@MainActor
func createExplosionEffect() -> Entity {
    let rootEntity = Entity()
    rootEntity.name = "Explosion"

    // Layer 1: Bright white flash (instant, fades fast)
    let flash = createExplosionLayer(
        color: .white,
        birthRate: 2000,
        size: 0.075,
        speed: 0.4,
        lifeSpan: 0.15,
        burstDuration: 0.05
    )
    rootEntity.addChild(flash)

    // Layer 2: Yellow-orange fireball core
    let core = createExplosionLayer(
        color: ExplosionPlatformColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),
        birthRate: 1500,
        size: 0.1,
        speed: 0.75,
        lifeSpan: 0.4,
        burstDuration: 0.1
    )
    rootEntity.addChild(core)

    // Layer 3: Orange-red expanding flame
    let flame = createExplosionLayer(
        color: ExplosionPlatformColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0),
        birthRate: 800,
        size: 0.15,
        speed: 1.25,
        lifeSpan: 0.6,
        burstDuration: 0.15
    )
    rootEntity.addChild(flame)

    // Layer 4: Deep red outer burst
    let outer = createExplosionLayer(
        color: ExplosionPlatformColor(red: 0.9, green: 0.15, blue: 0.0, alpha: 1.0),
        birthRate: 400,
        size: 0.2,
        speed: 1.5,
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
        intensity: 5000,
        attenuationRadius: 4.0
    )
    lightEntity.components.set(pointLight)
    rootEntity.addChild(lightEntity)

    return rootEntity
}

/// Creates a single explosion particle layer
private func createExplosionLayer(
    color: ExplosionPlatformColor,
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

/// Creates the smoke layer for explosions
private func createExplosionSmokeLayer() -> Entity {
    let entity = Entity()

    var emitter = ParticleEmitterComponent()
    emitter.timing = .once(warmUp: 0, emit: .init(duration: 0.3))
    emitter.emitterShape = .sphere
    emitter.emitterShapeSize = [0.05, 0.05, 0.05]

    emitter.mainEmitter.birthRate = 300
    emitter.mainEmitter.lifeSpan = 1.5
    emitter.mainEmitter.lifeSpanVariation = 0.5

    emitter.speed = 0.5
    emitter.speedVariation = 0.25
    emitter.mainEmitter.acceleration = [0, 0.3, 0]

    emitter.mainEmitter.size = 0.075
    emitter.mainEmitter.sizeVariation = 0.025
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
