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
/// - Parameter scale: Scale multiplier for the explosion (1.0 = normal, 2.0 = mega fireball)
@MainActor
func createExplosionEffect(scale: Float = 1.0) -> Entity {
    let rootEntity = Entity()
    rootEntity.name = "Explosion"

    // Layer 1: Bright white flash (instant, fades fast)
    let flash = createExplosionLayer(
        color: .white,
        birthRate: 2000 * scale,
        size: 0.075 * scale,
        speed: 0.4 * scale,
        lifeSpan: 0.15,
        burstDuration: 0.05,
        emitterSize: 0.05 * scale
    )
    rootEntity.addChild(flash)

    // Layer 2: Yellow-orange fireball core
    let core = createExplosionLayer(
        color: ExplosionPlatformColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),
        birthRate: 1500 * scale,
        size: 0.1 * scale,
        speed: 0.75 * scale,
        lifeSpan: 0.4,
        burstDuration: 0.1,
        emitterSize: 0.05 * scale
    )
    rootEntity.addChild(core)

    // Layer 3: Orange-red expanding flame
    let flame = createExplosionLayer(
        color: ExplosionPlatformColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0),
        birthRate: 800 * scale,
        size: 0.15 * scale,
        speed: 1.25 * scale,
        lifeSpan: 0.6,
        burstDuration: 0.15,
        emitterSize: 0.05 * scale
    )
    rootEntity.addChild(flame)

    // Layer 4: Deep red outer burst
    let outer = createExplosionLayer(
        color: ExplosionPlatformColor(red: 0.9, green: 0.15, blue: 0.0, alpha: 1.0),
        birthRate: 400 * scale,
        size: 0.2 * scale,
        speed: 1.5 * scale,
        lifeSpan: 0.8,
        burstDuration: 0.2,
        emitterSize: 0.05 * scale
    )
    rootEntity.addChild(outer)

    // Layer 5: Smoke/debris (darker, longer lasting)
    let smoke = createExplosionSmokeLayer(scale: scale)
    rootEntity.addChild(smoke)

    // Point light for dramatic lighting (intensity scales with explosion size)
    let lightEntity = Entity()
    let pointLight = PointLightComponent(
        color: .orange,
        intensity: 5000 * scale,
        attenuationRadius: 4.0 * scale
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
    burstDuration: Double,
    emitterSize: Float = 0.05
) -> Entity {
    let entity = Entity()

    var emitter = ParticleEmitterComponent()
    emitter.timing = .once(warmUp: 0, emit: .init(duration: burstDuration))
    emitter.emitterShape = .sphere
    emitter.emitterShapeSize = [emitterSize, emitterSize, emitterSize]
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
private func createExplosionSmokeLayer(scale: Float = 1.0) -> Entity {
    let entity = Entity()

    var emitter = ParticleEmitterComponent()
    emitter.timing = .once(warmUp: 0, emit: .init(duration: 0.3))
    emitter.emitterShape = .sphere
    emitter.emitterShapeSize = [0.05 * scale, 0.05 * scale, 0.05 * scale]

    emitter.mainEmitter.birthRate = 300 * scale
    emitter.mainEmitter.lifeSpan = 1.5
    emitter.mainEmitter.lifeSpanVariation = 0.5

    emitter.speed = 0.5 * scale
    emitter.speedVariation = 0.25 * scale
    emitter.mainEmitter.acceleration = [0, 0.3 * scale, 0]

    emitter.mainEmitter.size = 0.075 * scale
    emitter.mainEmitter.sizeVariation = 0.025 * scale
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
