//
//  ScorchMarkEffects.swift
//  ElementalWarrior
//
//  Procedural scorch mark effects with ember glow and lingering smoke.
//

import RealityKit
import SwiftUI
import CoreGraphics

#if os(macOS)
    import AppKit
    private typealias ScorchPlatformColor = NSColor
    private typealias ScorchPlatformImage = NSImage
#else
    import UIKit
    private typealias ScorchPlatformColor = UIColor
    private typealias ScorchPlatformImage = UIImage
#endif

private func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> ScorchPlatformColor {
    ScorchPlatformColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
}

// Cache for the radial gradient texture used with irregular meshes
private var cachedScorchTexture: TextureResource? = nil

// MARK: - Scorch Mark Effect

/// Creates a multi-layered scorch mark with procedural texture, ember glow, and smoke
@MainActor
func createScorchMark() -> Entity {
    let entity = Entity()
    entity.name = "ScorchMark"

    // Generate unique irregular mesh
    let mesh = generateIrregularSootMesh()

    let baseTint = SIMD3<Float>(0.04, 0.03, 0.025)
    let baseAlpha: Float = 1.0
    let baseOpacity: Float = 0.78

    // Create or reuse radial gradient texture for soft edges
    if cachedScorchTexture == nil {
        cachedScorchTexture = generateRadialGradientTexture()
    }

    var material = UnlitMaterial()
    if let texture = cachedScorchTexture {
        material.color = .init(
            tint: rgba(Double(baseTint.x), Double(baseTint.y), Double(baseTint.z), Double(baseAlpha)),
            texture: .init(texture)
        )
    } else {
        material.color = .init(
            tint: rgba(Double(baseTint.x), Double(baseTint.y), Double(baseTint.z), Double(baseAlpha))
        )
    }
    material.blending = .transparent(opacity: .init(floatLiteral: baseOpacity))

    let baseModel = ModelEntity(mesh: mesh, materials: [material])

    // Random rotation for variety
    let twoPi: Float = .pi * 2
    let randomAngle = Float.random(in: 0...twoPi)
    baseModel.orientation = simd_quatf(angle: randomAngle, axis: [0, 0, 1])
    entity.addChild(baseModel)

    if let texture = cachedScorchTexture {
        // Blend layer
        var blendMaterial = UnlitMaterial()
        blendMaterial.color = .init(
            tint: rgba(0.14, 0.1, 0.08, 0.5),
            texture: .init(texture)
        )
        blendMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.45))

        let blendModel = ModelEntity(mesh: mesh, materials: [blendMaterial])
        let blendScale = Float.random(in: 0.88...1.02)
        blendModel.scale = [blendScale, blendScale, 1.0]
        blendModel.orientation = simd_quatf(
            angle: randomAngle + Float.random(in: -0.2...0.2),
            axis: [0, 0, 1]
        )
        blendModel.position = [0, 0, 0.001]
        entity.addChild(blendModel)

        // Feather layer
        var featherMaterial = UnlitMaterial()
        featherMaterial.color = .init(
            tint: rgba(0.18, 0.13, 0.1, 0.35),
            texture: .init(texture)
        )
        featherMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.32))

        let featherModel = ModelEntity(mesh: mesh, materials: [featherMaterial])
        let featherScale = Float.random(in: 1.04...1.18)
        featherModel.scale = [featherScale, featherScale, 1.0]
        featherModel.orientation = simd_quatf(
            angle: randomAngle + Float.random(in: -0.2...0.2),
            axis: [0, 0, 1]
        )
        featherModel.position = [0, 0, 0.0005]
        entity.addChild(featherModel)

        // Ember glow layer
        var glowMaterial = UnlitMaterial()
        glowMaterial.color = .init(
            tint: rgba(1.0, 0.55, 0.2, 0.7),
            texture: .init(texture)
        )
        glowMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.8))

        let glowModel = ModelEntity(mesh: mesh, materials: [glowMaterial])
        let glowScale = Float.random(in: 0.96...1.1)
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
            intensityScale: 0.7,
            baseTint: baseTint,
            baseAlpha: baseAlpha,
            baseOpacity: baseOpacity
        )
    }

    // Lingering Smoke Effect
    let smoke = createLingeringSmoke()
    smoke.position = [0, 0, 0.02]
    entity.addChild(smoke)

    return entity
}

// MARK: - Irregular Soot Mesh Generation

/// Generate a unique irregular soot mark mesh with organic edge variation
private func generateIrregularSootMesh() -> MeshResource {
    let pointCount = 96
    let baseRadius: Float = Float.random(in: 0.13...0.22)

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

        let x = cosf(angle) * r
        let y = sinf(angle) * r

        vertices.append([x, y, 0])
        normals.append([0, 0, 1])

        let u = 0.5 + x / (maxRadius * 2.0)
        let v = 0.5 + y / (maxRadius * 2.0)
        uvs.append([min(max(u, 0.0), 1.0), min(max(v, 0.0), 1.0)])
    }

    // Fan triangulation from center
    for i in 0..<pointCount {
        let next = (i + 1) % pointCount
        indices.append(0)
        indices.append(UInt32(i + 1))
        indices.append(UInt32(next + 1))

        // Reverse winding for backface visibility
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

// MARK: - Radial Gradient Texture

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

            let fx = Float(x) / Float(max(1, width - 1))
            let fy = Float(y) / Float(max(1, height - 1))
            let nx = fx * 2 - 1
            let ny = fy * 2 - 1

            let dist = sqrt(nx*nx + ny*ny)

            var alpha = 1.0 - smoothstep(edge0: 0.3, edge1: 1.0, x: dist)

            let coarse = sampleNoise(fx, fy, size: coarseSize, data: coarseNoise)
            let fine = sampleNoise(
                fract(fx * 2.2 + 0.13),
                fract(fy * 2.2 + 0.37),
                size: fineSize,
                data: fineNoise
            )
            let turbulence = (coarse * 0.7 + fine * 0.3)

            let solidCore = 1.0 - smoothstep(edge0: 0.0, edge1: 0.6, x: dist)
            let textureMix = solidCore * 0.95 + (1.0 - solidCore) * (0.7 + 0.3 * turbulence)

            alpha *= textureMix

            let grain = Float.random(in: 0.85...1.0)
            alpha *= grain

            if dist > 0.7 {
                let distToEdge = 1.0 - dist
                let edgeFade = smoothstep(edge0: 0.0, edge1: 0.3, x: distToEdge)
                alpha *= edgeFade
            }

            let pixelAlpha = UInt8(max(0, min(255, alpha * 255)))

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

// MARK: - Smoothstep Helper

func smoothstep(edge0: Float, edge1: Float, x: Float) -> Float {
    let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
}

// MARK: - Lingering Smoke

/// Creates lingering smoke that rises from the scorch mark
private func createLingeringSmoke() -> Entity {
    let entity = Entity()

    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0, emit: .init(duration: 2.0))

    emitter.emitterShape = .sphere
    emitter.emitterShapeSize = [0.06, 0.06, 0.06]

    emitter.mainEmitter.birthRate = 8
    emitter.mainEmitter.lifeSpan = 2.5
    emitter.mainEmitter.lifeSpanVariation = 0.6

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

// MARK: - Ember Glow Animation

/// Animates the ember glow layer with pulsing heat effect
private func animateEmberGlow(
    model: ModelEntity,
    texture: TextureResource,
    baseScale: SIMD3<Float>,
    intensityScale: Double,
    baseTint: SIMD3<Float>,
    baseAlpha: Float,
    baseOpacity: Float
) {
    Task { @MainActor in
        let start = Date()
        let duration = Double.random(in: 7.0...9.0)
        let phase = Double.random(in: 0...(2.0 * Double.pi))

        while Date().timeIntervalSince(start) < duration {
            guard model.parent != nil else { break }
            let t = Date().timeIntervalSince(start)
            let progress = Float(t / duration)
            let fade = 1.0 - smoothstep(edge0: 0.55, edge1: 1.0, x: progress)
            let pulse = 0.5 + 0.5 * sin(t * 5.0 + phase)
            let flicker = Double.random(in: -0.12...0.12)
            let intensity = max(
                0.0,
                min(1.0, (pulse + flicker) * Double(fade) * intensityScale)
            )

            let baseR = Double(baseTint.x)
            let baseG = Double(baseTint.y)
            let baseB = Double(baseTint.z)
            let baseA = Double(baseAlpha)

            let heatR = 1.0
            let heatG = 0.15 + 0.75 * intensity
            let heatB = 0.03 + 0.3 * intensity
            let heatA = 0.1 + 0.7 * intensity

            let mix = intensity
            let red = baseR + (heatR - baseR) * mix
            let green = baseG + (heatG - baseG) * mix
            let blue = baseB + (heatB - baseB) * mix
            let alpha = baseA + (heatA - baseA) * mix

            var material = UnlitMaterial()
            material.color = .init(
                tint: rgba(red, green, blue, alpha),
                texture: .init(texture)
            )
            let opacity = Double(baseOpacity) + (0.85 - Double(baseOpacity)) * mix
            material.blending = .transparent(opacity: .init(floatLiteral: Float(opacity)))

            if var modelComponent = model.model {
                modelComponent.materials = [material]
                model.model = modelComponent
            }

            let scalePulse = Float(1.0 + 0.03 * sin(t * 4.0 + phase * 0.6))
            model.scale = baseScale * scalePulse

            try? await Task.sleep(for: .milliseconds(70))
        }

        guard model.parent != nil else { return }
        let fadeSteps = 20
        for step in 0..<fadeSteps {
            guard model.parent != nil else { break }
            let mix = 1.0 - Double(step + 1) / Double(fadeSteps)
            let intensity = max(0.0, min(1.0, mix)) * intensityScale

            let baseR = Double(baseTint.x)
            let baseG = Double(baseTint.y)
            let baseB = Double(baseTint.z)
            let baseA = Double(baseAlpha)

            let heatR = 1.0
            let heatG = 0.15 + 0.75 * intensity
            let heatB = 0.03 + 0.3 * intensity
            let heatA = 0.1 + 0.7 * intensity

            let red = baseR + (heatR - baseR) * intensity
            let green = baseG + (heatG - baseG) * intensity
            let blue = baseB + (heatB - baseB) * intensity
            let alpha = baseA + (heatA - baseA) * intensity

            var material = UnlitMaterial()
            material.color = .init(
                tint: rgba(red, green, blue, alpha),
                texture: .init(texture)
            )
            let opacity = Double(baseOpacity) + (0.85 - Double(baseOpacity)) * intensity
            material.blending = .transparent(opacity: .init(floatLiteral: Float(opacity)))

            if var modelComponent = model.model {
                modelComponent.materials = [material]
                model.model = modelComponent
            }

            let scalePulse = Float(1.0 + 0.02 * Float(mix))
            model.scale = baseScale * scalePulse
            try? await Task.sleep(for: .milliseconds(70))
        }

        guard model.parent != nil else { return }
        var material = UnlitMaterial()
        material.color = .init(
            tint: rgba(Double(baseTint.x), Double(baseTint.y), Double(baseTint.z), Double(baseAlpha)),
            texture: .init(texture)
        )
        material.blending = .transparent(opacity: .init(floatLiteral: baseOpacity))
        if var modelComponent = model.model {
            modelComponent.materials = [material]
            model.model = modelComponent
        }
    }
}
