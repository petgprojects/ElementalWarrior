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
import CoreGraphics

#if os(macOS)
    import AppKit
    typealias PlatformColor = NSColor
    typealias PlatformImage = NSImage
#else
    import UIKit
    typealias PlatformColor = UIColor
    typealias PlatformImage = UIImage
#endif

// Cache for the procedural scorch texture
private var cachedScorchTexture: TextureResource?

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
        size: 0.075,
        speed: 0.4,
        lifeSpan: 0.15,
        burstDuration: 0.05
    )
    rootEntity.addChild(flash)

    // Layer 2: Yellow-orange fireball core
    let core = createExplosionLayer(
        color: PlatformColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),
        birthRate: 1500,
        size: 0.1,
        speed: 0.75,
        lifeSpan: 0.4,
        burstDuration: 0.1
    )
    rootEntity.addChild(core)

    // Layer 3: Orange-red expanding flame
    let flame = createExplosionLayer(
        color: PlatformColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0),
        birthRate: 800,
        size: 0.15,
        speed: 1.25,
        lifeSpan: 0.6,
        burstDuration: 0.15
    )
    rootEntity.addChild(flame)

    // Layer 4: Deep red outer burst
    let outer = createExplosionLayer(
        color: PlatformColor(red: 0.9, green: 0.15, blue: 0.0, alpha: 1.0),
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

// MARK: - Scorch Mark Effect

@MainActor
func createScorchMark() -> Entity {
    let entity = Entity()
    entity.name = "ScorchMark"
    
    // Ensure we have the texture
    if cachedScorchTexture == nil {
        cachedScorchTexture = generateProceduralScorchTexture()
    }
    
    guard let texture = cachedScorchTexture else {
        return entity
    }
    
    // Use a single layer with PhysicallyBasedMaterial for better lighting integration
    // and to avoid "white circle" artifacts from UnlitMaterial defaults.
    let mesh = MeshResource.generatePlane(width: 0.5, depth: 0.5, cornerRadius: 0.25)
    
    var material = PhysicallyBasedMaterial()
    // Force the base color to be black. The texture's alpha channel will control opacity.
    // Using .black tint ensures that even if there are lighting artifacts, they stay dark (soot).
    material.baseColor = .init(tint: .black, texture: .init(texture))
    material.roughness = .init(floatLiteral: 1.0) // Soot is rough, not shiny
    material.metallic = .init(floatLiteral: 0.0)
    material.blending = .transparent(opacity: 1.0)
    
    let model = ModelEntity(mesh: mesh, materials: [material])
    
    // Random rotation for variety
    let randomAngle = Float.random(in: 0...(2 * .pi))
    model.orientation = simd_quatf(angle: randomAngle, axis: [0, 1, 0])
    
    entity.addChild(model)
    
    // 2. Lingering Smoke Effect
    let smoke = createLingeringSmoke()
    smoke.position = [0, 0.05, 0] 
    smoke.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
    entity.addChild(smoke)
    
    return entity
}

private func generateProceduralScorchTexture() -> TextureResource? {
    let width = 512
    let height = 512
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8
    
    var data = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
    
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * bytesPerPixel
            
            // Normalize coordinates -1 to 1
            let nx = (Float(x) / Float(width)) * 2 - 1
            let ny = (Float(y) / Float(height)) * 2 - 1
            
            // Distance from center
            let dist = sqrt(nx*nx + ny*ny)
            
            // HARD CUTOFF: Force alpha to 0 near the edges to prevent mipmap bleeding
            // This ensures the texture is strictly contained within the circle
            if dist > 0.48 {
                data[offset] = 0
                data[offset + 1] = 0
                data[offset + 2] = 0
                data[offset + 3] = 0
                continue
            }
            
            // Base shape: Radial gradient
            var alpha = max(0, 1.0 - dist)
            
            // Add noise to create holes and irregular edges
            // Simple pseudo-random noise based on position
            let noiseScale: Float = 10.0
            let noise = sin(nx * noiseScale) * cos(ny * noiseScale) * 0.5 + 0.5
            
            // Erode edges and create holes
            // If we are near the edge (dist > 0.5), noise has more effect
            // If we are in center, it's more solid but still has some texture
            let erosion = noise * (0.5 + dist)
            
            alpha = alpha - erosion * 0.5
            
            // Sharpen the transition to make it look like burnt flakes
            alpha = smoothstep(edge0: 0.2, edge1: 0.4, x: alpha)
            
            // Randomize slightly per pixel for grain
            let grain = Float.random(in: 0.8...1.0)
            alpha *= grain
            
            let pixelAlpha = UInt8(max(0, min(255, alpha * 255)))
            
            // Black color, variable alpha
            data[offset] = 0     // R
            data[offset + 1] = 0 // G
            data[offset + 2] = 0 // B
            data[offset + 3] = pixelAlpha // A
        }
    }
    
    guard let provider = CGDataProvider(data: Data(data) as CFData),
          let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bytesPerPixel * 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
          ) else {
        return nil
    }
    
    return try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
}

private func smoothstep(edge0: Float, edge1: Float, x: Float) -> Float {
    let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
}

private func createLingeringSmoke() -> Entity {
    let entity = Entity()
    
    var emitter = ParticleEmitterComponent()
    // Emit for 2 seconds then stop
    emitter.timing = .repeating(warmUp: 0, emit: .init(duration: 2.0))
    
    emitter.emitterShape = .plane
    emitter.emitterShapeSize = [0.2, 0.2, 0.0]
    
    emitter.mainEmitter.birthRate = 15
    emitter.mainEmitter.lifeSpan = 2.0
    emitter.mainEmitter.lifeSpanVariation = 1.0
    
    // Emit along -Z (direction of wall normal)
    emitter.emissionDirection = [0, 0, -1]
    emitter.birthDirection = .local
    
    emitter.speed = 0.05
    emitter.speedVariation = 0.02
    
    emitter.mainEmitter.size = 0.03
    emitter.mainEmitter.sizeVariation = 0.02
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 3.0
    
    emitter.mainEmitter.color = .evolving(
        start: .single(.init(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.3)),
        end: .single(.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0))
    )
    
    entity.components.set(emitter)
    return entity
}
