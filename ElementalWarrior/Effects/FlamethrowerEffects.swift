//
//  FlamethrowerEffects.swift
//  ElementalWarrior
//
//  Forward-facing flamethrower stream used for the stop-sign palm gesture.
//

import RealityKit
import SwiftUI

#if os(macOS)
    import AppKit
    private typealias FlamethrowerColor = NSColor
#else
    import UIKit
    private typealias FlamethrowerColor = UIColor
#endif

// MARK: - Flamethrower Stream

/// Creates a layered flamethrower stream oriented along +Z in local space.
/// The caller should position/orient the returned entity at the palm.
@MainActor
func createFlamethrowerStream(scale: Float = 1.0) -> Entity {
    let root = Entity()
    root.name = "FlamethrowerStream"

    root.addChild(createCoreJet(scale: scale))
    root.addChild(createBodyJet(scale: scale))
    root.addChild(createSparkSpray(scale: scale))
    root.addChild(createHeatSmoke(scale: scale))
    root.addChild(createMuzzleFlash(scale: scale))

    // Add a warm light near the palm for extra realism
    let lightEntity = Entity()
    let pointLight = PointLightComponent(
        color: .orange,
        intensity: 1400 * scale,
        attenuationRadius: 3.5 * scale
    )
    lightEntity.components.set(pointLight)
    lightEntity.position = [0, 0, 0.05 * scale]
    root.addChild(lightEntity)

    return root
}

// MARK: - Layers

private func baseEmitter(emitterShapeSize: SIMD3<Float>, emissionDirection: SIMD3<Float>) -> ParticleEmitterComponent {
    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.2, emit: .init(duration: 10000))
    emitter.emitterShape = .sphere
    emitter.emitterShapeSize = emitterShapeSize
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = emissionDirection
    return emitter
}

private func createCoreJet(scale: Float) -> Entity {
    var emitter = baseEmitter(emitterShapeSize: [0.035 * scale, 0.035 * scale, 0.035 * scale], emissionDirection: [0, 0, 1])

    emitter.mainEmitter.birthRate = 2200 * scale
    emitter.mainEmitter.lifeSpan = 0.38
    emitter.mainEmitter.lifeSpanVariation = 0.08
    emitter.mainEmitter.size = 0.055 * scale
    emitter.mainEmitter.sizeVariation = 0.02 * scale
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.35

    emitter.speed = 4.5 * scale
    emitter.speedVariation = 0.4 * scale
    emitter.mainEmitter.acceleration = [0, 0.8 * scale, 0]
    emitter.mainEmitter.spreadingAngle = 0.14

    emitter.mainEmitter.color = .evolving(
        start: .single(FlamethrowerColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1.0)),
        end: .single(FlamethrowerColor(red: 1.0, green: 0.5, blue: 0.15, alpha: 0.0))
    )
    emitter.mainEmitter.noiseStrength = 0.05 * scale
    emitter.mainEmitter.noiseAnimationSpeed = 1.2
    emitter.mainEmitter.blendMode = .additive

    let entity = Entity()
    entity.name = "FlamethrowerCore"
    entity.components.set(emitter)
    return entity
}

private func createBodyJet(scale: Float) -> Entity {
    var emitter = baseEmitter(emitterShapeSize: [0.05 * scale, 0.05 * scale, 0.05 * scale], emissionDirection: [0, 0, 1])

    emitter.mainEmitter.birthRate = 1600 * scale
    emitter.mainEmitter.lifeSpan = 0.6
    emitter.mainEmitter.lifeSpanVariation = 0.12
    emitter.mainEmitter.size = 0.09 * scale
    emitter.mainEmitter.sizeVariation = 0.04 * scale
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.25

    emitter.speed = 3.2 * scale
    emitter.speedVariation = 0.5 * scale
    emitter.mainEmitter.acceleration = [0, 0.5 * scale, 0]
    emitter.mainEmitter.spreadingAngle = 0.22

    emitter.mainEmitter.color = .evolving(
        start: .single(FlamethrowerColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 0.8)),
        end: .single(FlamethrowerColor(red: 0.8, green: 0.25, blue: 0.05, alpha: 0.0))
    )
    emitter.mainEmitter.noiseStrength = 0.14 * scale
    emitter.mainEmitter.noiseScale = 1.2
    emitter.mainEmitter.noiseAnimationSpeed = 1.8
    emitter.mainEmitter.blendMode = .additive

    let entity = Entity()
    entity.name = "FlamethrowerBody"
    entity.components.set(emitter)
    return entity
}

private func createSparkSpray(scale: Float) -> Entity {
    var emitter = baseEmitter(emitterShapeSize: [0.03 * scale, 0.03 * scale, 0.03 * scale], emissionDirection: [0, 0.1, 1])

    emitter.mainEmitter.birthRate = 260 * scale
    emitter.mainEmitter.lifeSpan = 0.7
    emitter.mainEmitter.lifeSpanVariation = 0.15
    emitter.mainEmitter.size = 0.018 * scale
    emitter.mainEmitter.sizeVariation = 0.01 * scale
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.1

    emitter.speed = 6.0 * scale
    emitter.speedVariation = 1.2 * scale
    emitter.mainEmitter.acceleration = [0, -0.8 * scale, 0]
    emitter.mainEmitter.spreadingAngle = 0.26

    emitter.mainEmitter.color = .evolving(
        start: .single(FlamethrowerColor(red: 1.0, green: 0.9, blue: 0.55, alpha: 0.9)),
        end: .single(FlamethrowerColor(red: 1.0, green: 0.5, blue: 0.05, alpha: 0.0))
    )
    emitter.mainEmitter.noiseStrength = 0.08 * scale
    emitter.mainEmitter.noiseAnimationSpeed = 2.0
    emitter.mainEmitter.blendMode = .additive

    let entity = Entity()
    entity.name = "FlamethrowerSparks"
    entity.components.set(emitter)
    return entity
}

private func createHeatSmoke(scale: Float) -> Entity {
    var emitter = baseEmitter(emitterShapeSize: [0.055 * scale, 0.055 * scale, 0.055 * scale], emissionDirection: [0, 0, 1])

    emitter.mainEmitter.birthRate = 520 * scale
    emitter.mainEmitter.lifeSpan = 1.25
    emitter.mainEmitter.lifeSpanVariation = 0.2
    emitter.mainEmitter.size = 0.11 * scale
    emitter.mainEmitter.sizeVariation = 0.05 * scale
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.45

    emitter.speed = 1.4 * scale
    emitter.speedVariation = 0.5 * scale
    emitter.mainEmitter.acceleration = [0, 0.6 * scale, 0]
    emitter.mainEmitter.spreadingAngle = 0.3

    emitter.mainEmitter.color = .evolving(
        start: .single(FlamethrowerColor(red: 0.22, green: 0.16, blue: 0.12, alpha: 0.4)),
        end: .single(FlamethrowerColor(red: 0.1, green: 0.08, blue: 0.06, alpha: 0.0))
    )
    emitter.mainEmitter.noiseStrength = 0.18 * scale
    emitter.mainEmitter.noiseScale = 1.6
    emitter.mainEmitter.noiseAnimationSpeed = 1.4
    emitter.mainEmitter.blendMode = .alpha

    let entity = Entity()
    entity.name = "FlamethrowerSmoke"
    entity.position = [0, 0.02 * scale, 0]
    entity.components.set(emitter)
    return entity
}

private func createMuzzleFlash(scale: Float) -> Entity {
    var emitter = baseEmitter(emitterShapeSize: [0.035 * scale, 0.035 * scale, 0.035 * scale], emissionDirection: [0, 0, 1])

    emitter.timing = .repeating(warmUp: 0.0, emit: .init(duration: 10000))
    emitter.mainEmitter.birthRate = 900 * scale
    emitter.mainEmitter.lifeSpan = 0.18
    emitter.mainEmitter.lifeSpanVariation = 0.05
    emitter.mainEmitter.size = 0.12 * scale
    emitter.mainEmitter.sizeVariation = 0.05 * scale
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.05

    emitter.speed = 0.6 * scale
    emitter.speedVariation = 0.2 * scale
    emitter.mainEmitter.spreadingAngle = 0.25

    emitter.mainEmitter.color = .evolving(
        start: .single(FlamethrowerColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 0.8)),
        end: .single(FlamethrowerColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.0))
    )
    emitter.mainEmitter.blendMode = .additive

    let entity = Entity()
    entity.name = "FlamethrowerMuzzle"
    entity.components.set(emitter)
    return entity
}
