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
        material.color = .init(tint: .init(white: 0.02, alpha: 1.0), texture: .init(texture))
    } else {
        material.color = .init(tint: .init(white: 0.02, alpha: 1.0))
    }
    material.blending = .transparent(opacity: 0.9)

    // DEBUG: Force opacity to see actual mesh shape
    // Uncomment to debug: material.color = .init(tint: .init(white: 0.1, alpha: 1.0))

    let baseModel = ModelEntity(mesh: mesh, materials: [material])

    // Random rotation for variety
    let twoPi: Float = .pi * 2
    let randomAngle = Float.random(in: 0...twoPi)
    baseModel.orientation = simd_quatf(angle: randomAngle, axis: [0, 0, 1])
    entity.addChild(baseModel)

    if let texture = cachedScorchTexture {
        var glowMaterial = UnlitMaterial()
        glowMaterial.color = .init(
            tint: .init(red: 1.0, green: 0.55, blue: 0.2, alpha: 0.7),
            texture: .init(texture)
        )
        glowMaterial.blending = .transparent(opacity: 0.8)

        let glowModel = ModelEntity(mesh: mesh, materials: [glowMaterial])
        let glowScale = Float.random(in: 0.72...0.95)
        let glowBaseScale: SIMD3<Float> = [glowScale, glowScale, 1.0]
        glowModel.scale = glowBaseScale
        glowModel.orientation = simd_quatf(
            angle: randomAngle + Float.random(in: -0.4...0.4),
            axis: [0, 0, 1]
        )
        glowModel.position = [0, 0, 0.002]
        entity.addChild(glowModel)
        animateEmberGlow(
            model: glowModel,
            texture: texture,
            baseScale: glowBaseScale,
            intensityScale: 0.75
        )
    }

    // Lingering Smoke Effect
    let smoke = createLingeringSmoke()
    smoke.position = [0, 0, 0.02]
    entity.addChild(smoke)

    return entity
}

/// Generate a unique irregular soot mark mesh - NO rectangular bounds
/// Creates a circular disc with organic edge variation
private func generateIrregularSootMesh() -> MeshResource {
    let pointCount = 96
    let baseRadius: Float = Float.random(in: 0.13...0.22) // 26-44cm diameter, varies per mark

    var vertices: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    var normals: [SIMD3<Float>] = []
    var uvs: [SIMD2<Float>] = []

    let twoPi: Float = .pi * 2
    let lobe1 = Float(Int.random(in: 2...4))
    let lobe2 = Float(Int.random(in: 5...8))
    let lobe3 = Float(Int.random(in: 9...13))
    let phase1 = Float.random(in: 0...twoPi)
    let phase2 = Float.random(in: 0...twoPi)
    let phase3 = Float.random(in: 0...twoPi)

    let spurCount = Int.random(in: 3...6)
    var spurs: [(center: Float, width: Float, strength: Float)] = []
    spurs.reserveCapacity(spurCount)
    for _ in 0..<spurCount {
        let center = Float.random(in: 0...twoPi)
        let width = Float.random(in: 0.15...0.35)
        let strength = Float.random(in: 0.12...0.25)
        spurs.append((center: center, width: width, strength: strength))
    }

    func angularDistance(_ a: Float, _ b: Float) -> Float {
        let diff = abs(a - b)
        return min(diff, twoPi - diff)
    }

    @inline(__always)
    func sinf(_ value: Float) -> Float {
        Float(sin(Double(value)))
    }

    @inline(__always)
    func cosf(_ value: Float) -> Float {
        Float(cos(Double(value)))
    }

    // Pre-generate radius variations
    var radii: [Float] = []
    for i in 0..<pointCount {
        let angle = Float(i) / Float(pointCount) * twoPi
        var r: Float = 1.0
        r += sinf(angle * lobe1 + phase1) * 0.12
        r += sinf(angle * lobe2 + phase2) * 0.06
        r += sinf(angle * lobe3 + phase3) * 0.03
        r += Float.random(in: -0.05...0.05)

        for spur in spurs {
            let dist = angularDistance(angle, spur.center)
            let t = max(Float(0.0), 1.0 - dist / spur.width)
            r += spur.strength * t * t
        }

        r = max(0.55, r)
        radii.append(r)
    }

    // Smooth the radii for organic edges
    var smoothRadii = radii
    for _ in 0..<2 {
        var next = smoothRadii
        for i in 0..<pointCount {
            let p = (i - 1 + pointCount) % pointCount
            let n = (i + 1) % pointCount
            next[i] = (smoothRadii[p] + smoothRadii[i] * 2 + smoothRadii[n]) / 4.0
        }
        smoothRadii = next
    }

    // Center vertex
    vertices.append([0, 0, 0])
    normals.append([0, 0, 1])
    uvs.append([0.5, 0.5])

    let maxScale = smoothRadii.max() ?? 1.0
    let maxRadius = baseRadius * maxScale

    // Outer vertices - create circle in XY plane
    for i in 0..<pointCount {
        let angle = Float(i) / Float(pointCount) * twoPi
        let r = baseRadius * smoothRadii[i]

        // Circle in XY plane (Z=0)
        let x = cosf(angle) * r
        let y = sinf(angle) * r

        vertices.append([x, y, 0])
        normals.append([0, 0, 1])

        // Map UVs based on position relative to max possible radius
        let u = 0.5 + x / (maxRadius * 2.0)
        let v = 0.5 + y / (maxRadius * 2.0)
        uvs.append([min(max(u, 0.0), 1.0), min(max(v, 0.0), 1.0)])
    }

    // Fan triangulation from center
    for i in 0..<pointCount {
        let next = (i + 1) % pointCount
        indices.append(0) // center
        indices.append(UInt32(i + 1))
        indices.append(UInt32(next + 1))

        // Reverse winding for backface visibility without relying on cull settings
        indices.append(0)
        indices.append(UInt32(next + 1))
        indices.append(UInt32(i + 1))
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
        return MeshResource.generateSphere(radius: baseRadius * 0.1)
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

    let coarseSize = 24
    let fineSize = 64
    let coarseNoise = (0..<(coarseSize * coarseSize)).map { _ in Float.random(in: 0.0...1.0) }
    let fineNoise = (0..<(fineSize * fineSize)).map { _ in Float.random(in: 0.0...1.0) }

    func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t
    }

    func fract(_ v: Float) -> Float {
        v - floorf(v)
    }

    func sampleNoise(_ x: Float, _ y: Float, size: Int, data: [Float]) -> Float {
        let fx = x * Float(size - 1)
        let fy = y * Float(size - 1)
        let x0 = min(max(Int(floorf(fx)), 0), size - 1)
        let y0 = min(max(Int(floorf(fy)), 0), size - 1)
        let x1 = min(x0 + 1, size - 1)
        let y1 = min(y0 + 1, size - 1)
        let tx = fx - Float(x0)
        let ty = fy - Float(y0)

        let v00 = data[y0 * size + x0]
        let v10 = data[y0 * size + x1]
        let v01 = data[y1 * size + x0]
        let v11 = data[y1 * size + x1]

        let vx0 = lerp(v00, v10, tx)
        let vx1 = lerp(v01, v11, tx)
        return lerp(vx0, vx1, ty)
    }

    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * bytesPerPixel

            // Normalize coordinates -1 to 1
            let fx = Float(x) / Float(max(1, width - 1))
            let fy = Float(y) / Float(max(1, height - 1))
            let nx = fx * 2 - 1
            let ny = fy * 2 - 1

            // Distance from center
            let dist = sqrt(nx*nx + ny*ny)

            // Base radial gradient - solid center fading to edges
            var alpha = 1.0 - smoothstep(edge0: 0.3, edge1: 1.0, x: dist)

            // Add burnt texture detail (smooth noise, avoids grid artifacts)
            let coarse = sampleNoise(fx, fy, size: coarseSize, data: coarseNoise)
            let fine = sampleNoise(
                fract(fx * 2.2 + 0.13),
                fract(fy * 2.2 + 0.37),
                size: fineSize,
                data: fineNoise
            )
            let turbulence = (coarse * 0.7 + fine * 0.3)

            // Center is more solid, edges are patchy (like burnt material)
            let solidCore = 1.0 - smoothstep(edge0: 0.0, edge1: 0.6, x: dist)
            let textureMix = solidCore * 0.95 + (1.0 - solidCore) * (0.7 + 0.3 * turbulence)

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

            // White color with calculated alpha (lets tint control color)
            data[offset] = 255     // R
            data[offset + 1] = 255 // G
            data[offset + 2] = 255 // B
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
    
    emitter.emitterShape = .sphere
    emitter.emitterShapeSize = [0.06, 0.06, 0.06]
    
    emitter.mainEmitter.birthRate = 8
    emitter.mainEmitter.lifeSpan = 2.5
    emitter.mainEmitter.lifeSpanVariation = 0.6
    
    // Emit out along +Z (wall normal in local space)
    emitter.emissionDirection = [0, 0, 1]
    emitter.birthDirection = .local
    
    emitter.speed = 0.035
    emitter.speedVariation = 0.015
    emitter.mainEmitter.acceleration = [0.0, 0.02, 0.05]
    
    emitter.mainEmitter.size = 0.028
    emitter.mainEmitter.sizeVariation = 0.02
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 2.6
    
    emitter.mainEmitter.color = .evolving(
        start: .single(.init(red: 0.12, green: 0.1, blue: 0.08, alpha: 0.25)),
        end: .single(.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0))
    )
    
    entity.components.set(emitter)
    return entity
}

private func animateEmberGlow(
    model: ModelEntity,
    texture: TextureResource,
    baseScale: SIMD3<Float>,
    intensityScale: Double
) {
    Task { @MainActor in
        let start = Date()
        let duration = Double.random(in: 6.0...8.5)
        let phase = Double.random(in: 0...(2.0 * Double.pi))

        while Date().timeIntervalSince(start) < duration {
            guard model.parent != nil else { break }
            let t = Date().timeIntervalSince(start)
            let cooling = max(0.0, 1.0 - t / duration)
            let pulse = 0.5 + 0.5 * sin(t * 5.0 + phase)
            let flicker = Double.random(in: -0.12...0.12)
            let intensity = max(0.0, min(1.0, (pulse + flicker) * cooling * intensityScale))

            let green = 0.15 + 0.75 * intensity
            let blue = 0.03 + 0.3 * intensity
            let alpha = 0.1 + 0.7 * intensity

            var material = UnlitMaterial()
            material.color = .init(
                tint: .init(red: 1.0, green: green, blue: blue, alpha: alpha),
                texture: .init(texture)
            )
            material.blending = .transparent(opacity: 0.85)

            if var modelComponent = model.model {
                modelComponent.materials = [material]
                model.model = modelComponent
            }

            let scalePulse = Float(1.0 + 0.03 * sin(t * 4.0 + phase * 0.6))
            model.scale = baseScale * scalePulse

            try? await Task.sleep(for: .milliseconds(70))
        }

        guard model.parent != nil else { return }
        var material = UnlitMaterial()
        material.color = .init(
            tint: .init(red: 0.25, green: 0.07, blue: 0.03, alpha: 0.2),
            texture: .init(texture)
        )
        material.blending = .transparent(opacity: 0.5)
        if var modelComponent = model.model {
            modelComponent.materials = [material]
            model.model = modelComponent
        }
    }
}
