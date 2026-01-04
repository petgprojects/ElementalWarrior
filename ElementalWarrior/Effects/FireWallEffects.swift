//
//  FireWallEffects.swift
//  ElementalWarrior
//
//  Multi-layer fire wall particle effects with color state support and dynamic height scaling.
//  Used for the zombie pose gesture to create defensive fire barriers.
//

import RealityKit
import SwiftUI

#if os(macOS)
    import AppKit
    private typealias FireWallColor = NSColor
#else
    import UIKit
    private typealias FireWallColor = UIColor
#endif

// MARK: - Fire Wall Color Palettes

/// Fire wall color set for different visual states
fileprivate struct FireWallColors {
    fileprivate let primary: FireWallColor      // Main flame color
    fileprivate let secondary: FireWallColor    // Inner/bright color
    fileprivate let tertiary: FireWallColor     // Outer/dark color
    fileprivate let lightColor: UIColor         // For point lights
}

/// Get color palette for the given fire wall state
private func getFireWallColors(for state: FireWallColorState) -> FireWallColors {
    switch state {
    case .blue:
        return FireWallColors(
            primary: FireWallColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
            secondary: FireWallColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0),
            tertiary: FireWallColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 1.0),
            lightColor: UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
        )
    case .redOrange:
        return FireWallColors(
            primary: FireWallColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0),
            secondary: FireWallColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0),
            tertiary: FireWallColor(red: 0.8, green: 0.15, blue: 0.0, alpha: 1.0),
            lightColor: UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)
        )
    case .green:
        return FireWallColors(
            primary: FireWallColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1.0),
            secondary: FireWallColor(red: 0.5, green: 1.0, blue: 0.6, alpha: 1.0),
            tertiary: FireWallColor(red: 0.1, green: 0.7, blue: 0.2, alpha: 1.0),
            lightColor: UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0)
        )
    }
}

// MARK: - Fire Wall Creation

/// Creates a fire wall entity with multi-layer particle effects
/// - Parameters:
///   - width: Wall length in meters
///   - height: Wall height as percentage (0.0-1.0), maps to actual meters
///   - colorState: Visual color state (blue, red/orange, green)
/// - Returns: Entity with fire wall particle effects
@MainActor
func createFireWall(
    width: Float,
    height: Float,
    colorState: FireWallColorState
) -> Entity {
    let root = Entity()
    root.name = "FireWall"

    let colors = getFireWallColors(for: colorState)

    // Map height percentage to actual meters
    let actualHeight = height * GestureConstants.fireWallMaxHeight

    // Always show ember line at the base
    root.addChild(createEmberLine(width: width, colors: colors))

    if actualHeight >= 0.1 {
        // Full wall with multiple flame layers
        root.addChild(createFlameBase(width: width, height: actualHeight, colors: colors))
        root.addChild(createFlameBody(width: width, height: actualHeight, colors: colors))
        root.addChild(createFlameTips(width: width, height: actualHeight, colors: colors))
        root.addChild(createWallSmoke(width: width, height: actualHeight))
    }

    // Add dynamic lighting along the wall
    let lightCount = max(1, Int(width / 0.6))
    for i in 0..<lightCount {
        let xOffset = (Float(i) / Float(max(1, lightCount - 1)) - 0.5) * width
        let lightEntity = Entity()
        lightEntity.position = [xOffset, max(0.1, actualHeight * 0.4), 0]

        let intensity: Float = colorState == .blue ? 600 : 900
        let pointLight = PointLightComponent(
            color: colors.lightColor,
            intensity: intensity * max(0.3, actualHeight / 2.0),
            attenuationRadius: 1.5 + actualHeight
        )
        lightEntity.components.set(pointLight)
        root.addChild(lightEntity)
    }

    return root
}

// MARK: - Ember Line (Base of Wall)

/// Creates ember/spark line along the ground (base of wall)
private func createEmberLine(width: Float, colors: FireWallColors) -> Entity {
    let entity = Entity()
    entity.name = "FireWallEmbers"

    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.3, emit: .init(duration: 10000))

    // Box emitter shape stretched along X axis (wall length)
    emitter.emitterShape = .box
    emitter.emitterShapeSize = [width, 0.02, 0.05]
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = [0, 1, 0]  // Emit upward

    emitter.mainEmitter.birthRate = 120 * width
    emitter.mainEmitter.lifeSpan = 0.9
    emitter.mainEmitter.lifeSpanVariation = 0.3

    emitter.speed = 0.12
    emitter.speedVariation = 0.08
    emitter.mainEmitter.acceleration = [0, 0.25, 0]
    emitter.mainEmitter.spreadingAngle = 0.35

    emitter.mainEmitter.size = 0.018
    emitter.mainEmitter.sizeVariation = 0.008
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.15

    emitter.mainEmitter.color = .evolving(
        start: .single(colors.secondary),
        end: .single(colors.primary.withAlphaComponent(0))
    )
    emitter.mainEmitter.blendMode = .additive
    emitter.mainEmitter.noiseStrength = 0.06
    emitter.mainEmitter.noiseAnimationSpeed = 1.5

    entity.components.set(emitter)
    entity.position = [0, 0.02, 0]  // Slightly above ground

    return entity
}

// MARK: - Flame Base Layer

/// Creates the base flame layer (wider, slower, brighter core)
private func createFlameBase(width: Float, height: Float, colors: FireWallColors) -> Entity {
    let entity = Entity()
    entity.name = "FireWallFlameBase"

    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.3, emit: .init(duration: 10000))

    emitter.emitterShape = .box
    emitter.emitterShapeSize = [width, 0.06, 0.08]
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = [0, 1, 0]

    // Scale birth rate with width, and adjust lifespan/speed with height
    let heightFactor = max(0.3, height / GestureConstants.fireWallMaxHeight)
    emitter.mainEmitter.birthRate = 350 * width
    emitter.mainEmitter.lifeSpan = Double(0.5 * heightFactor)
    emitter.mainEmitter.lifeSpanVariation = 0.12

    emitter.speed = 1.0 * heightFactor + 0.5
    emitter.speedVariation = 0.25
    emitter.mainEmitter.acceleration = [0, 0.4, 0]
    emitter.mainEmitter.spreadingAngle = 0.15

    emitter.mainEmitter.size = 0.075
    emitter.mainEmitter.sizeVariation = 0.03
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.25

    emitter.mainEmitter.color = .evolving(
        start: .single(colors.secondary),
        end: .single(colors.primary.withAlphaComponent(0))
    )
    emitter.mainEmitter.blendMode = .additive
    emitter.mainEmitter.noiseStrength = 0.08
    emitter.mainEmitter.noiseAnimationSpeed = 2.0

    entity.components.set(emitter)
    entity.position = [0, 0.03, 0]

    return entity
}

// MARK: - Flame Body Layer

/// Creates the main flame body (medium speed, good volume)
private func createFlameBody(width: Float, height: Float, colors: FireWallColors) -> Entity {
    let entity = Entity()
    entity.name = "FireWallFlameBody"

    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.3, emit: .init(duration: 10000))

    emitter.emitterShape = .box
    emitter.emitterShapeSize = [width * 0.9, 0.05, 0.06]
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = [0, 1, 0]

    let heightFactor = max(0.3, height / GestureConstants.fireWallMaxHeight)
    emitter.mainEmitter.birthRate = 280 * width
    emitter.mainEmitter.lifeSpan = Double(0.55 * heightFactor)
    emitter.mainEmitter.lifeSpanVariation = 0.15

    emitter.speed = 1.5 * heightFactor + 0.4
    emitter.speedVariation = 0.4
    emitter.mainEmitter.acceleration = [0, 0.6, 0]
    emitter.mainEmitter.spreadingAngle = 0.12

    emitter.mainEmitter.size = 0.055
    emitter.mainEmitter.sizeVariation = 0.022
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.2

    emitter.mainEmitter.color = .evolving(
        start: .single(colors.primary),
        end: .single(colors.tertiary.withAlphaComponent(0))
    )
    emitter.mainEmitter.blendMode = .additive
    emitter.mainEmitter.noiseStrength = 0.12
    emitter.mainEmitter.noiseAnimationSpeed = 2.2

    entity.components.set(emitter)
    entity.position = [0, 0.04, 0]

    return entity
}

// MARK: - Flame Tips Layer

/// Creates flame tips (fastest, thinnest, most chaotic)
private func createFlameTips(width: Float, height: Float, colors: FireWallColors) -> Entity {
    let entity = Entity()
    entity.name = "FireWallFlameTips"

    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.3, emit: .init(duration: 10000))

    emitter.emitterShape = .box
    emitter.emitterShapeSize = [width * 0.75, 0.04, 0.05]
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = [0, 1, 0]

    let heightFactor = max(0.3, height / GestureConstants.fireWallMaxHeight)
    emitter.mainEmitter.birthRate = 180 * width
    emitter.mainEmitter.lifeSpan = Double(0.4 * heightFactor)
    emitter.mainEmitter.lifeSpanVariation = 0.12

    emitter.speed = 2.0 * heightFactor + 0.6
    emitter.speedVariation = 0.6
    emitter.mainEmitter.acceleration = [0, 0.9, 0]
    emitter.mainEmitter.spreadingAngle = 0.18

    emitter.mainEmitter.size = 0.04
    emitter.mainEmitter.sizeVariation = 0.018
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.12

    emitter.mainEmitter.color = .evolving(
        start: .single(colors.primary),
        end: .single(colors.tertiary.withAlphaComponent(0))
    )
    emitter.mainEmitter.blendMode = .additive
    emitter.mainEmitter.noiseStrength = 0.2
    emitter.mainEmitter.noiseAnimationSpeed = 2.8

    entity.components.set(emitter)
    entity.position = [0, 0.05, 0]

    return entity
}

// MARK: - Wall Smoke Layer

/// Creates rising smoke above the flames
private func createWallSmoke(width: Float, height: Float) -> Entity {
    let entity = Entity()
    entity.name = "FireWallSmoke"

    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.5, emit: .init(duration: 10000))

    emitter.emitterShape = .box
    emitter.emitterShapeSize = [width * 0.6, 0.1, 0.1]
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = [0, 1, 0]

    emitter.mainEmitter.birthRate = 35 * width
    emitter.mainEmitter.lifeSpan = 1.8
    emitter.mainEmitter.lifeSpanVariation = 0.4

    emitter.speed = 0.25
    emitter.speedVariation = 0.12
    emitter.mainEmitter.acceleration = [0, 0.12, 0]
    emitter.mainEmitter.spreadingAngle = 0.22

    emitter.mainEmitter.size = 0.1
    emitter.mainEmitter.sizeVariation = 0.04
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 2.2

    emitter.mainEmitter.color = .evolving(
        start: .single(FireWallColor(red: 0.22, green: 0.18, blue: 0.15, alpha: 0.28)),
        end: .single(FireWallColor(red: 0.12, green: 0.1, blue: 0.08, alpha: 0.0))
    )
    emitter.mainEmitter.blendMode = .alpha
    emitter.mainEmitter.noiseStrength = 0.18
    emitter.mainEmitter.noiseAnimationSpeed = 0.7

    entity.components.set(emitter)
    entity.position = [0, height * 0.65, 0]

    return entity
}

// MARK: - Despawn Smoke Effect

/// Creates smoke effect when fire wall is despawned
@MainActor
func createFireWallDespawnSmoke(width: Float, height: Float) -> Entity {
    let entity = Entity()
    entity.name = "FireWallDespawnSmoke"

    var emitter = ParticleEmitterComponent()
    emitter.timing = .once(warmUp: 0, emit: .init(duration: 0.5))

    // Spread smoke along the wall length
    let actualHeight = height * GestureConstants.fireWallMaxHeight
    emitter.emitterShape = .box
    emitter.emitterShapeSize = [width, max(0.1, actualHeight * 0.4), 0.15]
    emitter.birthLocation = .volume

    emitter.mainEmitter.birthRate = 500 * width
    emitter.mainEmitter.lifeSpan = 1.4
    emitter.mainEmitter.lifeSpanVariation = 0.35

    emitter.speed = 0.35
    emitter.speedVariation = 0.2
    emitter.mainEmitter.acceleration = [0, 0.25, 0]
    emitter.mainEmitter.spreadingAngle = 0.4

    emitter.mainEmitter.size = 0.1
    emitter.mainEmitter.sizeVariation = 0.04
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 1.8

    emitter.mainEmitter.color = .evolving(
        start: .single(FireWallColor(red: 0.28, green: 0.24, blue: 0.2, alpha: 0.45)),
        end: .single(FireWallColor(red: 0.15, green: 0.12, blue: 0.1, alpha: 0.0))
    )
    emitter.mainEmitter.blendMode = .alpha
    emitter.mainEmitter.noiseStrength = 0.18

    entity.components.set(emitter)
    entity.position = [0, max(0.1, actualHeight * 0.35), 0]

    return entity
}
