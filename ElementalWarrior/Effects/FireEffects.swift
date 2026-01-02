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

// Cache for the radial gradient texture used with irregular meshes
// Set to nil to force regeneration with new parameters
// UPDATED: Now using enhanced radial gradient with burnt texture detail
private var cachedScorchTexture: TextureResource? = nil

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

    // Generate unique irregular mesh - no rectangular bounds!
    let mesh = generateIrregularSootMesh()

    // Create or reuse radial gradient texture for soft edges
    if cachedScorchTexture == nil {
        cachedScorchTexture = generateRadialGradientTexture()
    }

    var material = UnlitMaterial()
    if let texture = cachedScorchTexture {
        material.color = .init(tint: .black, texture: .init(texture))
    } else {
        material.color = .init(tint: .black)
    }
    material.blending = .transparent(opacity: 0.9)

    // DEBUG: Force opacity to see actual mesh shape
    // Uncomment to debug: material.color = .init(tint: .init(white: 0.1, alpha: 1.0))

    let model = ModelEntity(mesh: mesh, materials: [material])

    // Random rotation for variety
    let randomAngle = Float.random(in: 0...(2 * .pi))
    model.orientation = simd_quatf(angle: randomAngle, axis: [0, 1, 0])

    entity.addChild(model)

    // Lingering Smoke Effect
    let smoke = createLingeringSmoke()
    smoke.position = [0, 0.05, 0]
    smoke.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
    entity.addChild(smoke)

    return entity
}

/// Generate a unique irregular soot mark mesh - NO rectangular bounds
/// Creates a circular disc with organic edge variation
private func generateIrregularSootMesh() -> MeshResource {
    let pointCount = 64 // Smooth circle
    let baseRadius: Float = Float.random(in: 0.15...0.22) // 30-44cm diameter, varies per mark

    var vertices: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    var normals: [SIMD3<Float>] = []
    var uvs: [SIMD2<Float>] = []

    // Pre-generate smooth random radius variations
    var radii: [Float] = []
    for i in 0..<pointCount {
        // Base variation
        var r = Float.random(in: 0.88...1.12)
        // Add some waviness for organic splatter look
        let angle = Float(i) / Float(pointCount) * 2.0 * .pi
        let wave1 = sin(angle * Float.random(in: 3...5)) * 0.08
        let wave2 = sin(angle * Float.random(in: 7...9) + 1.0) * 0.04
        r += wave1 + wave2
        radii.append(r)
    }

    // Smooth the radii for organic edges
    var smoothRadii: [Float] = []
    for i in 0..<pointCount {
        let p1 = (i - 2 + pointCount) % pointCount
        let p2 = (i - 1 + pointCount) % pointCount
        let n1 = (i + 1) % pointCount
        let n2 = (i + 2) % pointCount
        let avg = (radii[p1] + radii[p2] * 2 + radii[i] * 3 + radii[n1] * 2 + radii[n2]) / 9.0
        smoothRadii.append(avg)
    }

    // Center vertex
    vertices.append([0, 0, 0])
    normals.append([0, 1, 0])
    uvs.append([0.5, 0.5])

    // Outer vertices - create circle in XZ plane
    for i in 0..<pointCount {
        let angle = Float(i) / Float(pointCount) * 2.0 * .pi
        let r = baseRadius * smoothRadii[i]

        // Circle in XZ plane (Y=0)
        let x = cos(angle) * r
        let z = sin(angle) * r

        vertices.append([x, 0, z])
        normals.append([0, 1, 0])

        // Map UVs based on position relative to max possible radius
        let maxR = baseRadius * 1.3
        let u = 0.5 + x / (maxR * 2.0)
        let v = 0.5 + z / (maxR * 2.0)
        uvs.append([u, v])
    }

    // Fan triangulation from center
    for i in 0..<pointCount {
        indices.append(0) // center
        indices.append(UInt32(i + 1))
        indices.append(UInt32((i + 1) % pointCount + 1))
    }

    var descriptor = MeshDescriptor(name: "SootMark")
    descriptor.positions = MeshBuffer(vertices)
    descriptor.normals = MeshBuffer(normals)
    descriptor.textureCoordinates = MeshBuffer(uvs)
    descriptor.primitives = .triangles(indices)

    do {
        return try MeshResource.generate(from: [descriptor])
    } catch {
        print("Mesh generation failed: \(error)")
        // Fallback - but this shouldn't happen
        return MeshResource.generatePlane(width: 0.3, depth: 0.3, cornerRadius: 0.15)
    }
}

/// Generate a radial gradient texture with burnt soot detail
private func generateRadialGradientTexture() -> TextureResource? {
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

            // Base radial gradient - solid center fading to edges
            var alpha = 1.0 - smoothstep(edge0: 0.3, edge1: 1.0, x: dist)

            // Add burnt texture detail (high-frequency noise)
            let texNoise = sin(nx * 40.0) * cos(ny * 40.0)
            let turbulence = texNoise * 0.5 + 0.5

            // Center is more solid, edges are patchy (like burnt material)
            let solidCore = 1.0 - smoothstep(edge0: 0.0, edge1: 0.6, x: dist)
            let textureMix = solidCore * 0.95 + (1.0 - solidCore) * turbulence

            alpha *= textureMix

            // Add random grain for realism
            let grain = Float.random(in: 0.85...1.0)
            alpha *= grain

            // Extra edge softness to prevent any visible boundary
            if dist > 0.7 {
                let distToEdge = 1.0 - dist
                let edgeFade = smoothstep(edge0: 0.0, edge1: 0.3, x: distToEdge)
                alpha *= edgeFade
            }

            let pixelAlpha = UInt8(max(0, min(255, alpha * 255)))

            // Black color with calculated alpha
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

    return try? TextureResource(image: cgImage, options: .init(semantic: .color))
}

// DEPRECATED: Old texture generation - keeping for reference
private func generateProceduralScorchTexture_UNUSED() -> TextureResource? {
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
            
            // Polar coordinates
            let dist = sqrt(nx*nx + ny*ny)
            let angle = atan2(ny, nx)

            // 1. Starburst / Splatter Shape with procedural variation
            // Texture fills most of the space for tight geometric bounds
            let frequency1: Float = 5.0
            let frequency2: Float = 11.0
            let frequency3: Float = 23.0

            let noise1 = sin(angle * frequency1)
            let noise2 = sin(angle * frequency2 + 2.0)
            let noise3 = sin(angle * frequency3 + 4.0)

            // Radius variation - soot fills ~85% of texture radius with organic edges
            let radiusVariation = (noise1 * 0.08) + (noise2 * 0.05) + (noise3 * 0.03)
            // Base radius 0.85 (85% of texture), plus variation for irregular edges
            let maxRadius = 0.85 + radiusVariation

            // 2. Ultra-smooth radial falloff - no hard edges, perfectly feathered
            // Very aggressive softness ensures no visible boundary
            let edgeSoftness: Float = 0.35
            var alpha = 1.0 - smoothstep(edge0: maxRadius - edgeSoftness, edge1: maxRadius + edgeSoftness, x: dist)

            // 3. Internal Turbulence for burnt texture detail
            let texNoise = sin(nx * 40.0) * cos(ny * 40.0)
            let turbulence = (texNoise * 0.5 + 0.5)

            // Center is darker/solid, edges are patchy and irregular
            let solidCore = 1.0 - smoothstep(edge0: 0.0, edge1: 0.6, x: dist)
            let textureMix = solidCore * 0.9 + (1.0 - solidCore) * turbulence

            alpha *= textureMix

            // 4. Random grain for texture variation
            alpha *= Float.random(in: 0.8...1.0)

            // 5. Final edge feathering - ensure absolute smoothness at boundaries
            // This prevents ANY hard edges that could catch light
            if dist > 0.75 {
                let distanceToEdge = 1.0 - dist
                let edgeFade = smoothstep(edge0: 0.0, edge1: 0.25, x: distanceToEdge)
                alpha *= edgeFade
            }

            // Clamp alpha
            let pixelAlpha = UInt8(max(0, min(255, alpha * 255)))
            
            // Output: Black color with calculated alpha
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
    
    return try? TextureResource(image: cgImage, options: .init(semantic: .color))
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
