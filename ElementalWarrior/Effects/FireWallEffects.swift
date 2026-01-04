//
//  FireWallEffects.swift
//  ElementalWarrior
//
//  Ember line and wall of fire visual effects for palms-down wall control.
//

import RealityKit
import SwiftUI

#if os(macOS)
    import AppKit
    typealias FireWallColor = NSColor
#else
    import UIKit
    typealias FireWallColor = UIColor
#endif

struct EmberLineVisual {
    let root: Entity
    let glowEmitter: Entity
    let sparksEmitter: Entity
    let lightEntity: Entity
}

struct FireWallVisual {
    let root: Entity
    let coreEmitter: Entity
    let bodyEmitter: Entity
    let sparksEmitter: Entity
    let smokeEmitter: Entity
    let lightEntity: Entity
}

struct FireWallPalette {
    let coreStart: FireWallColor
    let coreEnd: FireWallColor
    let bodyStart: FireWallColor
    let bodyEnd: FireWallColor
    let sparksStart: FireWallColor
    let sparksEnd: FireWallColor
    let lightColor: FireWallColor
}

private enum FireWallDefaults {
    static let emberThickness: Float = 0.09
    static let emberHeight: Float = 0.02
    static let emberBirthRatePerMeter: Float = 220
    static let emberSparkRatePerMeter: Float = 70

    static let wallThickness: Float = 0.14
    static let wallCoreSpeed: Float = 1.8
    static let wallBodySpeed: Float = 1.2
    static let wallSparksSpeed: Float = 2.4
    static let wallSmokeSpeed: Float = 0.65

    static let wallCoreRatePerMeter: Float = 900
    static let wallBodyRatePerMeter: Float = 700
    static let wallSparksRatePerMeter: Float = 160
    static let wallSmokeRatePerMeter: Float = 220
}

private func clamp(_ value: Float, min minValue: Float, max maxValue: Float) -> Float {
    max(minValue, min(value, maxValue))
}

// MARK: - Ember Line

@MainActor
func createEmberLineEffect(width: Float) -> EmberLineVisual {
    let root = Entity()
    root.name = "EmberLine"

    let glow = Entity()
    glow.name = "EmberGlow"
    glow.components.set(makeEmberGlowEmitter(width: width))
    root.addChild(glow)

    let sparks = Entity()
    sparks.name = "EmberSparks"
    sparks.components.set(makeEmberSparksEmitter(width: width))
    root.addChild(sparks)

    let light = Entity()
    light.name = "EmberLight"
    let lightComponent = PointLightComponent(
        color: .cyan,
        intensity: 600,
        attenuationRadius: 1.4
    )
    light.components.set(lightComponent)
    light.position = [0, 0.08, 0]
    root.addChild(light)

    return EmberLineVisual(root: root, glowEmitter: glow, sparksEmitter: sparks, lightEntity: light)
}

@MainActor
func updateEmberLineEffect(_ visual: EmberLineVisual, width: Float) {
    let clampedWidth = max(0.15, width)

    if var emitter = visual.glowEmitter.components[ParticleEmitterComponent.self] {
        emitter.emitterShapeSize = [clampedWidth, FireWallDefaults.emberHeight, FireWallDefaults.emberThickness]
        emitter.mainEmitter.birthRate = FireWallDefaults.emberBirthRatePerMeter * clampedWidth
        visual.glowEmitter.components.set(emitter)
    }

    if var emitter = visual.sparksEmitter.components[ParticleEmitterComponent.self] {
        emitter.emitterShapeSize = [clampedWidth, FireWallDefaults.emberHeight, FireWallDefaults.emberThickness * 0.7]
        emitter.mainEmitter.birthRate = FireWallDefaults.emberSparkRatePerMeter * clampedWidth
        visual.sparksEmitter.components.set(emitter)
    }

    if var light = visual.lightEntity.components[PointLightComponent.self] {
        light.intensity = 400 + 220 * clampedWidth
        visual.lightEntity.components.set(light)
    }
}

private func makeEmberGlowEmitter(width: Float) -> ParticleEmitterComponent {
    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.2, emit: .init(duration: 10000))
    emitter.emitterShape = .box
    emitter.emitterShapeSize = [width, FireWallDefaults.emberHeight, FireWallDefaults.emberThickness]
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = [0, 1, 0]

    emitter.mainEmitter.birthRate = FireWallDefaults.emberBirthRatePerMeter * width
    emitter.mainEmitter.lifeSpan = 0.85
    emitter.mainEmitter.lifeSpanVariation = 0.2
    emitter.mainEmitter.size = 0.025
    emitter.mainEmitter.sizeVariation = 0.01
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.2

    emitter.speed = 0.25
    emitter.speedVariation = 0.15
    emitter.mainEmitter.acceleration = [0, 0.25, 0]
    emitter.mainEmitter.spreadingAngle = 0.35

    emitter.mainEmitter.color = .evolving(
        start: .single(FireWallColor(red: 0.45, green: 0.85, blue: 1.0, alpha: 0.85)),
        end: .single(FireWallColor(red: 0.15, green: 0.35, blue: 1.0, alpha: 0.0))
    )
    emitter.mainEmitter.blendMode = .additive
    emitter.mainEmitter.noiseStrength = 0.1
    emitter.mainEmitter.noiseAnimationSpeed = 1.2

    return emitter
}

private func makeEmberSparksEmitter(width: Float) -> ParticleEmitterComponent {
    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.2, emit: .init(duration: 10000))
    emitter.emitterShape = .box
    emitter.emitterShapeSize = [width, FireWallDefaults.emberHeight, FireWallDefaults.emberThickness * 0.7]
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = [0, 1, 0]

    emitter.mainEmitter.birthRate = FireWallDefaults.emberSparkRatePerMeter * width
    emitter.mainEmitter.lifeSpan = 1.0
    emitter.mainEmitter.lifeSpanVariation = 0.3
    emitter.mainEmitter.size = 0.015
    emitter.mainEmitter.sizeVariation = 0.008
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.1

    emitter.speed = 0.45
    emitter.speedVariation = 0.2
    emitter.mainEmitter.acceleration = [0, -0.2, 0]
    emitter.mainEmitter.spreadingAngle = 0.6

    emitter.mainEmitter.color = .evolving(
        start: .single(FireWallColor(red: 0.7, green: 0.95, blue: 1.0, alpha: 0.9)),
        end: .single(FireWallColor(red: 0.2, green: 0.55, blue: 1.0, alpha: 0.0))
    )
    emitter.mainEmitter.blendMode = .additive
    emitter.mainEmitter.noiseStrength = 0.08
    emitter.mainEmitter.noiseAnimationSpeed = 1.8

    return emitter
}

// MARK: - Fire Wall

@MainActor
func createFireWallEffect(width: Float, height: Float) -> FireWallVisual {
    let root = Entity()
    root.name = "FireWall"

    let core = Entity()
    core.name = "FireWallCore"
    core.position = [0, 0.01, 0]
    core.components.set(makeFireWallCoreEmitter(width: width, height: height))
    root.addChild(core)

    let body = Entity()
    body.name = "FireWallBody"
    body.position = [0, 0.01, 0]
    body.components.set(makeFireWallBodyEmitter(width: width, height: height))
    root.addChild(body)

    let sparks = Entity()
    sparks.name = "FireWallSparks"
    sparks.position = [0, 0.02, 0]
    sparks.components.set(makeFireWallSparksEmitter(width: width, height: height))
    root.addChild(sparks)

    let smoke = Entity()
    smoke.name = "FireWallSmoke"
    smoke.position = [0, 0.02, 0]
    smoke.components.set(makeFireWallSmokeEmitter(width: width, height: height))
    root.addChild(smoke)

    let light = Entity()
    light.name = "FireWallLight"
    let lightComponent = PointLightComponent(
        color: .orange,
        intensity: 1200,
        attenuationRadius: 4.0
    )
    light.components.set(lightComponent)
    light.position = [0, height * 0.6, FireWallDefaults.wallThickness * 0.2]
    root.addChild(light)

    return FireWallVisual(
        root: root,
        coreEmitter: core,
        bodyEmitter: body,
        sparksEmitter: sparks,
        smokeEmitter: smoke,
        lightEntity: light
    )
}

@MainActor
func updateFireWallEffect(_ visual: FireWallVisual, width: Float, height: Float) {
    let clampedWidth = max(0.2, width)
    let clampedHeight = clamp(height, min: 0.05, max: 4.0)

    if var emitter = visual.coreEmitter.components[ParticleEmitterComponent.self] {
        configureFireWallEmitter(
            &emitter,
            width: clampedWidth,
            height: clampedHeight,
            baseSpeed: FireWallDefaults.wallCoreSpeed,
            birthRatePerMeter: FireWallDefaults.wallCoreRatePerMeter
        )
        visual.coreEmitter.components.set(emitter)
    }

    if var emitter = visual.bodyEmitter.components[ParticleEmitterComponent.self] {
        configureFireWallEmitter(
            &emitter,
            width: clampedWidth,
            height: clampedHeight,
            baseSpeed: FireWallDefaults.wallBodySpeed,
            birthRatePerMeter: FireWallDefaults.wallBodyRatePerMeter
        )
        visual.bodyEmitter.components.set(emitter)
    }

    if var emitter = visual.sparksEmitter.components[ParticleEmitterComponent.self] {
        configureFireWallEmitter(
            &emitter,
            width: clampedWidth,
            height: clampedHeight,
            baseSpeed: FireWallDefaults.wallSparksSpeed,
            birthRatePerMeter: FireWallDefaults.wallSparksRatePerMeter
        )
        visual.sparksEmitter.components.set(emitter)
    }

    if var emitter = visual.smokeEmitter.components[ParticleEmitterComponent.self] {
        configureFireWallEmitter(
            &emitter,
            width: clampedWidth,
            height: clampedHeight,
            baseSpeed: FireWallDefaults.wallSmokeSpeed,
            birthRatePerMeter: FireWallDefaults.wallSmokeRatePerMeter
        )
        visual.smokeEmitter.components.set(emitter)
    }

    if var light = visual.lightEntity.components[PointLightComponent.self] {
        light.intensity = 800 + 260 * clampedWidth
        light.attenuationRadius = max(2.5, clampedWidth * 1.6)
        visual.lightEntity.position = [0, clampedHeight * 0.6, FireWallDefaults.wallThickness * 0.2]
        visual.lightEntity.components.set(light)
    }
}

func applyFireWallPalette(_ visual: FireWallVisual, palette: FireWallPalette) {
    if var emitter = visual.coreEmitter.components[ParticleEmitterComponent.self] {
        emitter.mainEmitter.color = .evolving(
            start: .single(palette.coreStart),
            end: .single(palette.coreEnd)
        )
        visual.coreEmitter.components.set(emitter)
    }

    if var emitter = visual.bodyEmitter.components[ParticleEmitterComponent.self] {
        emitter.mainEmitter.color = .evolving(
            start: .single(palette.bodyStart),
            end: .single(palette.bodyEnd)
        )
        visual.bodyEmitter.components.set(emitter)
    }

    if var emitter = visual.sparksEmitter.components[ParticleEmitterComponent.self] {
        emitter.mainEmitter.color = .evolving(
            start: .single(palette.sparksStart),
            end: .single(palette.sparksEnd)
        )
        visual.sparksEmitter.components.set(emitter)
    }

    if var light = visual.lightEntity.components[PointLightComponent.self] {
        light.color = palette.lightColor
        visual.lightEntity.components.set(light)
    }
}

func defaultFireWallPalette() -> FireWallPalette {
    FireWallPalette(
        coreStart: FireWallColor(red: 1.0, green: 0.92, blue: 0.75, alpha: 1.0),
        coreEnd: FireWallColor(red: 1.0, green: 0.45, blue: 0.1, alpha: 0.0),
        bodyStart: FireWallColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 0.8),
        bodyEnd: FireWallColor(red: 0.9, green: 0.2, blue: 0.05, alpha: 0.0),
        sparksStart: FireWallColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 0.9),
        sparksEnd: FireWallColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 0.0),
        lightColor: FireWallColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1.0)
    )
}

func highlightFireWallPalette() -> FireWallPalette {
    FireWallPalette(
        coreStart: FireWallColor(red: 0.6, green: 0.9, blue: 1.0, alpha: 0.9),
        coreEnd: FireWallColor(red: 0.2, green: 0.45, blue: 1.0, alpha: 0.0),
        bodyStart: FireWallColor(red: 0.25, green: 0.75, blue: 1.0, alpha: 0.7),
        bodyEnd: FireWallColor(red: 0.1, green: 0.35, blue: 0.9, alpha: 0.0),
        sparksStart: FireWallColor(red: 0.8, green: 0.95, blue: 1.0, alpha: 0.9),
        sparksEnd: FireWallColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.0),
        lightColor: FireWallColor(red: 0.4, green: 0.75, blue: 1.0, alpha: 1.0)
    )
}

func selectingFireWallPalette() -> FireWallPalette {
    FireWallPalette(
        coreStart: FireWallColor(red: 0.55, green: 1.0, blue: 0.6, alpha: 0.95),
        coreEnd: FireWallColor(red: 0.15, green: 0.7, blue: 0.25, alpha: 0.0),
        bodyStart: FireWallColor(red: 0.2, green: 0.9, blue: 0.35, alpha: 0.75),
        bodyEnd: FireWallColor(red: 0.1, green: 0.55, blue: 0.2, alpha: 0.0),
        sparksStart: FireWallColor(red: 0.75, green: 1.0, blue: 0.7, alpha: 0.9),
        sparksEnd: FireWallColor(red: 0.25, green: 0.75, blue: 0.35, alpha: 0.0),
        lightColor: FireWallColor(red: 0.45, green: 0.95, blue: 0.55, alpha: 1.0)
    )
}

func lerpFireWallPalette(from: FireWallPalette, to: FireWallPalette, t: Float) -> FireWallPalette {
    FireWallPalette(
        coreStart: lerpColor(from.coreStart, to.coreStart, t: t),
        coreEnd: lerpColor(from.coreEnd, to.coreEnd, t: t),
        bodyStart: lerpColor(from.bodyStart, to.bodyStart, t: t),
        bodyEnd: lerpColor(from.bodyEnd, to.bodyEnd, t: t),
        sparksStart: lerpColor(from.sparksStart, to.sparksStart, t: t),
        sparksEnd: lerpColor(from.sparksEnd, to.sparksEnd, t: t),
        lightColor: lerpColor(from.lightColor, to.lightColor, t: t)
    )
}

private func configureFireWallEmitter(
    _ emitter: inout ParticleEmitterComponent,
    width: Float,
    height: Float,
    baseSpeed: Float,
    birthRatePerMeter: Float
) {
    emitter.emitterShapeSize = [width, 0.05, FireWallDefaults.wallThickness]
    emitter.mainEmitter.birthRate = birthRatePerMeter * width
    emitter.speed = baseSpeed

    let lifeSpan = Double(clamp(height / max(0.1, baseSpeed), min: 0.08, max: 2.6))
    emitter.mainEmitter.lifeSpan = lifeSpan
    emitter.mainEmitter.lifeSpanVariation = lifeSpan * 0.25
}

private func lerpColor(_ from: FireWallColor, _ to: FireWallColor, t: Float) -> FireWallColor {
    #if os(macOS)
        guard let fromRGBA = from.usingColorSpace(.deviceRGB),
              let toRGBA = to.usingColorSpace(.deviceRGB) else {
            return from
        }
        let r = fromRGBA.redComponent + (toRGBA.redComponent - fromRGBA.redComponent) * CGFloat(t)
        let g = fromRGBA.greenComponent + (toRGBA.greenComponent - fromRGBA.greenComponent) * CGFloat(t)
        let b = fromRGBA.blueComponent + (toRGBA.blueComponent - fromRGBA.blueComponent) * CGFloat(t)
        let a = fromRGBA.alphaComponent + (toRGBA.alphaComponent - fromRGBA.alphaComponent) * CGFloat(t)
        return FireWallColor(red: r, green: g, blue: b, alpha: a)
    #else
        var fromR: CGFloat = 0
        var fromG: CGFloat = 0
        var fromB: CGFloat = 0
        var fromA: CGFloat = 0
        var toR: CGFloat = 0
        var toG: CGFloat = 0
        var toB: CGFloat = 0
        var toA: CGFloat = 0
        from.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
        to.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)
        let r = fromR + (toR - fromR) * CGFloat(t)
        let g = fromG + (toG - fromG) * CGFloat(t)
        let b = fromB + (toB - fromB) * CGFloat(t)
        let a = fromA + (toA - fromA) * CGFloat(t)
        return FireWallColor(red: r, green: g, blue: b, alpha: a)
    #endif
}

private func makeFireWallCoreEmitter(width: Float, height: Float) -> ParticleEmitterComponent {
    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.2, emit: .init(duration: 10000))
    emitter.emitterShape = .box
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = [0, 1, 0]

    emitter.mainEmitter.size = 0.08
    emitter.mainEmitter.sizeVariation = 0.03
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.2

    emitter.mainEmitter.acceleration = [0, 0.8, 0]
    emitter.mainEmitter.spreadingAngle = 0.22
    emitter.mainEmitter.noiseStrength = 0.08
    emitter.mainEmitter.noiseAnimationSpeed = 1.4
    emitter.mainEmitter.blendMode = .additive

    emitter.mainEmitter.color = .evolving(
        start: .single(FireWallColor(red: 1.0, green: 0.92, blue: 0.75, alpha: 1.0)),
        end: .single(FireWallColor(red: 1.0, green: 0.45, blue: 0.1, alpha: 0.0))
    )

    configureFireWallEmitter(
        &emitter,
        width: width,
        height: height,
        baseSpeed: FireWallDefaults.wallCoreSpeed,
        birthRatePerMeter: FireWallDefaults.wallCoreRatePerMeter
    )
    return emitter
}

private func makeFireWallBodyEmitter(width: Float, height: Float) -> ParticleEmitterComponent {
    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.2, emit: .init(duration: 10000))
    emitter.emitterShape = .box
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = [0, 1, 0]

    emitter.mainEmitter.size = 0.12
    emitter.mainEmitter.sizeVariation = 0.05
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.25

    emitter.mainEmitter.acceleration = [0, 0.5, 0]
    emitter.mainEmitter.spreadingAngle = 0.3
    emitter.mainEmitter.noiseStrength = 0.14
    emitter.mainEmitter.noiseAnimationSpeed = 1.6
    emitter.mainEmitter.blendMode = .additive

    emitter.mainEmitter.color = .evolving(
        start: .single(FireWallColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 0.8)),
        end: .single(FireWallColor(red: 0.9, green: 0.2, blue: 0.05, alpha: 0.0))
    )

    configureFireWallEmitter(
        &emitter,
        width: width,
        height: height,
        baseSpeed: FireWallDefaults.wallBodySpeed,
        birthRatePerMeter: FireWallDefaults.wallBodyRatePerMeter
    )
    return emitter
}

private func makeFireWallSparksEmitter(width: Float, height: Float) -> ParticleEmitterComponent {
    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.2, emit: .init(duration: 10000))
    emitter.emitterShape = .box
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = [0, 1, 0]

    emitter.mainEmitter.size = 0.03
    emitter.mainEmitter.sizeVariation = 0.02
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.05

    emitter.mainEmitter.acceleration = [0, -0.2, 0]
    emitter.mainEmitter.spreadingAngle = 0.5
    emitter.mainEmitter.noiseStrength = 0.12
    emitter.mainEmitter.noiseAnimationSpeed = 1.9
    emitter.mainEmitter.blendMode = .additive

    emitter.mainEmitter.color = .evolving(
        start: .single(FireWallColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 0.9)),
        end: .single(FireWallColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 0.0))
    )

    configureFireWallEmitter(
        &emitter,
        width: width,
        height: height,
        baseSpeed: FireWallDefaults.wallSparksSpeed,
        birthRatePerMeter: FireWallDefaults.wallSparksRatePerMeter
    )
    return emitter
}

private func makeFireWallSmokeEmitter(width: Float, height: Float) -> ParticleEmitterComponent {
    var emitter = ParticleEmitterComponent()
    emitter.timing = .repeating(warmUp: 0.2, emit: .init(duration: 10000))
    emitter.emitterShape = .box
    emitter.birthLocation = .volume
    emitter.birthDirection = .local
    emitter.emissionDirection = [0, 1, 0]

    emitter.mainEmitter.size = 0.15
    emitter.mainEmitter.sizeVariation = 0.08
    emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.45

    emitter.mainEmitter.acceleration = [0, 0.3, 0]
    emitter.mainEmitter.spreadingAngle = 0.35
    emitter.mainEmitter.noiseStrength = 0.22
    emitter.mainEmitter.noiseAnimationSpeed = 1.2
    emitter.mainEmitter.blendMode = .alpha

    emitter.mainEmitter.color = .evolving(
        start: .single(FireWallColor(red: 0.22, green: 0.18, blue: 0.16, alpha: 0.35)),
        end: .single(FireWallColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 0.0))
    )

    configureFireWallEmitter(
        &emitter,
        width: width,
        height: height,
        baseSpeed: FireWallDefaults.wallSmokeSpeed,
        birthRatePerMeter: FireWallDefaults.wallSmokeRatePerMeter
    )
    return emitter
}
