import RealityKit
import SwiftUI

#if os(macOS)
    import AppKit
    typealias PlatformColor = NSColor
#else
    import UIKit
    typealias PlatformColor = UIColor
#endif

@MainActor
func createRealisticFireball() -> Entity {
    let rootEntity = Entity()
    rootEntity.name = "RealisticFireball"
    
    // 1. Rigid Core (White Hot) - Small, intense center
    let whiteCore = createFlameEmitter(
        color: .white,
        birthRate: 1000,
        size: 0.025,
        speed: 0.02,
        acceleration: [0, 0.0, 0],
        lifeSpan: 0.3,
        spreadingAngle: 0.0,
        noiseStrength: 0.0
    )
    rootEntity.addChild(whiteCore)
    
    // 2. Inner Flame (Yellow/Orange) - The main body
    let innerFlame = createFlameEmitter(
        color: .yellow,
        birthRate: 600,
        size: 0.06,
        speed: 0.1,
        acceleration: [0, 0.2, 0],
        lifeSpan: 0.6,
        spreadingAngle: 0.2,
        noiseStrength: 0.02
    )
    rootEntity.addChild(innerFlame)
    
    // 3. Rising Spikes (Orange/Red) - Fast moving tongues of fire
    let spikes = createFlameEmitter(
        color: PlatformColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0), // Orange-Red
        birthRate: 400,
        size: 0.05,
        speed: 0.5,
        acceleration: [0, 1.2, 0], // High upward acceleration
        lifeSpan: 0.5,
        spreadingAngle: 0.1, // Narrow angle for spikes
        noiseStrength: 0.15
    )
    rootEntity.addChild(spikes)
    
    // 4. Outer Flame/Smoke (Deep Red) - Volume and trail
    let outerFlame = createFlameEmitter(
        color: PlatformColor(red: 0.8, green: 0.1, blue: 0.0, alpha: 1.0), // Deep Red
        birthRate: 200,
        size: 0.12,
        speed: 0.3,
        acceleration: [0, 0.4, 0],
        lifeSpan: 0.9,
        spreadingAngle: 0.4,
        noiseStrength: 0.08
    )
    rootEntity.addChild(outerFlame)
    
    // 5. Add a Point Light to cast light on surroundings
    let lightEntity = Entity()
    let pointLight = PointLightComponent(color: .orange, intensity: 2000, attenuationRadius: 4.0)
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
    noiseStrength: Float
) -> Entity {
    let entity = Entity()
    
    var particles = ParticleEmitterComponent()
    
    // Timing
    particles.timing = .repeating(warmUp: 1.0, emit: .init(duration: 10000.0))
    
    // Emitter Properties
    particles.emitterShape = .sphere
    particles.birthLocation = .volume
    particles.birthDirection = .local
    particles.emissionDirection = [0, 1, 0] // Upwards
    particles.mainEmitter.spreadingAngle = spreadingAngle
    
    // Particle Properties
    particles.mainEmitter.birthRate = birthRate
    particles.mainEmitter.size = size
    particles.mainEmitter.lifeSpan = lifeSpan
    
    // Color & Opacity over life: Start visible, fade out
    let startColor = color
    let endColor = color.withAlphaComponent(0.0)
    
    particles.mainEmitter.color = .evolving(
        start: .single(startColor),
        end: .single(endColor)
    )
    
    // Movement
    particles.speed = speed
    particles.mainEmitter.acceleration = acceleration
    
    // Noise / Turbulence (Makes it sway and look organic)
    particles.mainEmitter.noiseStrength = noiseStrength
    particles.mainEmitter.noiseAnimationSpeed = 1.0
    particles.mainEmitter.noiseScale = 2.0
    
    // Appearance
    // Note: In a real app, you'd want a texture for the particles (like a smoke puff or flame wisp).
    // For now, we'll use the default particle appearance which is a soft circle.
    particles.mainEmitter.blendMode = .additive // Makes it look glowing/hot
    
    // Size over life: Grow then shrink
    // We use sizeMultiplierAtEndOfLifespan for a simple shrink effect
    particles.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.1
    
    entity.components.set(particles)
    return entity
}
