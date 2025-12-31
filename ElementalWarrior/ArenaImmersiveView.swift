//
//  ArenaImmersiveView.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI
import RealityKit
import ARKit

struct ArenaImmersiveView: View {
    @State private var handTrackingManager = HandTrackingManager()

    var body: some View {
        RealityView { content in
            // No floor - full passthrough
            content.add(handTrackingManager.rootEntity)
        }
        .task {
            await handTrackingManager.startHandTracking()
        }
    }
}

@MainActor
final class HandTrackingManager {
    let rootEntity = Entity()

    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()

    // Preloaded fireball template
    private var fireballTemplate: Entity?

    // State tracking
    private struct HandState {
        var fireball: Entity?
        var isShowingFireball: Bool = false
        var isAnimating: Bool = false
    }

    private var leftHandState = HandState()
    private var rightHandState = HandState()

    func startHandTracking() async {
        await loadFireballTemplate()

        do {
            if HandTrackingProvider.isSupported {
                try await session.run([handTracking])
                await processHandUpdates()
            }
        } catch {
            print("Failed to start hand tracking: \(error)")
        }
    }

    private func loadFireballTemplate() async {
        if let url = Bundle.main.url(forResource: "Fireball", withExtension: "usdz") {
            do {
                fireballTemplate = try await Entity(contentsOf: url)
                print("Fireball template loaded successfully")
            } catch {
                print("Failed to load Fireball.usdz: \(error)")
            }
        } else {
            print("Fireball.usdz not found in bundle")
        }
    }

    private func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            let anchor = update.anchor
            let isLeft = anchor.chirality == .left

            guard anchor.isTracked else {
                // Hand lost tracking - extinguish fireball immediately
                if isLeft {
                    await forceExtinguishLeft()
                } else {
                    await forceExtinguishRight()
                }
                continue
            }

            let skeleton = anchor.handSkeleton

            // Check if hand is open with palm facing up
            let shouldShowFireball = checkShouldShowFireball(anchor: anchor, skeleton: skeleton)

            // Get palm position
            let palmPosition = getPalmPosition(anchor: anchor, skeleton: skeleton)

            if isLeft {
                await updateLeftHand(shouldShow: shouldShowFireball, position: palmPosition)
            } else {
                await updateRightHand(shouldShow: shouldShowFireball, position: palmPosition)
            }
        }
    }

    private func updateLeftHand(shouldShow: Bool, position: SIMD3<Float>) async {
        if shouldShow && !leftHandState.isShowingFireball && !leftHandState.isAnimating {
            // Spawn fireball
            leftHandState.isShowingFireball = true
            leftHandState.isAnimating = true

            let fireball = await createHandFireball()
            fireball.position = position
            fireball.scale = [0.01, 0.01, 0.01]
            rootEntity.addChild(fireball)
            leftHandState.fireball = fireball

            await animateSpawnLeft(entity: fireball)

        } else if !shouldShow && leftHandState.isShowingFireball && !leftHandState.isAnimating {
            // Extinguish fireball
            await extinguishLeft()

        } else if shouldShow, let fireball = leftHandState.fireball, !leftHandState.isAnimating {
            // Update position
            fireball.position = position
        }
    }

    private func updateRightHand(shouldShow: Bool, position: SIMD3<Float>) async {
        if shouldShow && !rightHandState.isShowingFireball && !rightHandState.isAnimating {
            // Spawn fireball
            rightHandState.isShowingFireball = true
            rightHandState.isAnimating = true

            let fireball = await createHandFireball()
            fireball.position = position
            fireball.scale = [0.01, 0.01, 0.01]
            rootEntity.addChild(fireball)
            rightHandState.fireball = fireball

            await animateSpawnRight(entity: fireball)

        } else if !shouldShow && rightHandState.isShowingFireball && !rightHandState.isAnimating {
            // Extinguish fireball
            await extinguishRight()

        } else if shouldShow, let fireball = rightHandState.fireball, !rightHandState.isAnimating {
            // Update position
            fireball.position = position
        }
    }

    private func animateSpawnLeft(entity: Entity) async {
        // Fade in over 0.5 seconds
        var transform = entity.transform
        transform.scale = [1.0, 1.0, 1.0]
        entity.move(to: transform, relativeTo: entity.parent, duration: 0.5, timingFunction: .easeOut)
        try? await Task.sleep(for: .milliseconds(500))
        leftHandState.isAnimating = false
    }

    private func animateSpawnRight(entity: Entity) async {
        // Fade in over 0.5 seconds
        var transform = entity.transform
        transform.scale = [1.0, 1.0, 1.0]
        entity.move(to: transform, relativeTo: entity.parent, duration: 0.5, timingFunction: .easeOut)
        try? await Task.sleep(for: .milliseconds(500))
        rightHandState.isAnimating = false
    }

    private func extinguishLeft() async {
        guard let fireball = leftHandState.fireball else { return }

        leftHandState.isAnimating = true

        // Get position for smoke puff
        let position = fireball.position

        // Quickly shrink the fireball
        var transform = fireball.transform
        transform.scale = [0.01, 0.01, 0.01]
        fireball.move(to: transform, relativeTo: fireball.parent, duration: 0.1, timingFunction: .easeIn)

        // Spawn smoke puff at the same location
        let smokePuff = createSmokePuff()
        smokePuff.position = position
        rootEntity.addChild(smokePuff)

        try? await Task.sleep(for: .milliseconds(100))

        fireball.removeFromParent()
        leftHandState.fireball = nil
        leftHandState.isShowingFireball = false
        leftHandState.isAnimating = false

        // Stop emitter after short burst, let particles fade naturally
        Task {
            try? await Task.sleep(for: .milliseconds(150))  // Brief burst
            // Stop emitting new particles
            if var emitter = smokePuff.components[ParticleEmitterComponent.self] {
                emitter.mainEmitter.birthRate = 0
                smokePuff.components.set(emitter)
            }
            // Wait for existing particles to fade (2s lifespan + buffer)
            try? await Task.sleep(for: .milliseconds(2300))
            smokePuff.removeFromParent()
        }
    }

    private func extinguishRight() async {
        guard let fireball = rightHandState.fireball else { return }

        rightHandState.isAnimating = true

        // Get position for smoke puff
        let position = fireball.position

        // Quickly shrink the fireball
        var transform = fireball.transform
        transform.scale = [0.01, 0.01, 0.01]
        fireball.move(to: transform, relativeTo: fireball.parent, duration: 0.1, timingFunction: .easeIn)

        // Spawn smoke puff at the same location
        let smokePuff = createSmokePuff()
        smokePuff.position = position
        rootEntity.addChild(smokePuff)

        try? await Task.sleep(for: .milliseconds(100))

        fireball.removeFromParent()
        rightHandState.fireball = nil
        rightHandState.isShowingFireball = false
        rightHandState.isAnimating = false

        // Stop emitter after short burst, let particles fade naturally
        Task {
            try? await Task.sleep(for: .milliseconds(150))  // Brief burst
            // Stop emitting new particles
            if var emitter = smokePuff.components[ParticleEmitterComponent.self] {
                emitter.mainEmitter.birthRate = 0
                smokePuff.components.set(emitter)
            }
            // Wait for existing particles to fade (2s lifespan + buffer)
            try? await Task.sleep(for: .milliseconds(2300))
            smokePuff.removeFromParent()
        }
    }

    private func forceExtinguishLeft() async {
        if let fireball = leftHandState.fireball {
            let smokePuff = createSmokePuff()
            smokePuff.position = fireball.position
            rootEntity.addChild(smokePuff)
            fireball.removeFromParent()

            // Stop emitter after short burst, let particles fade naturally
            Task {
                try? await Task.sleep(for: .milliseconds(150))  // Brief burst
                // Stop emitting new particles
                if var emitter = smokePuff.components[ParticleEmitterComponent.self] {
                    emitter.mainEmitter.birthRate = 0
                    smokePuff.components.set(emitter)
                }
                // Wait for existing particles to fade (2s lifespan + buffer)
                try? await Task.sleep(for: .milliseconds(2300))
                smokePuff.removeFromParent()
            }
        }
        leftHandState = HandState()
    }

    private func forceExtinguishRight() async {
        if let fireball = rightHandState.fireball {
            let smokePuff = createSmokePuff()
            smokePuff.position = fireball.position
            rootEntity.addChild(smokePuff)
            fireball.removeFromParent()

            // Stop emitter after short burst, let particles fade naturally
            Task {
                try? await Task.sleep(for: .milliseconds(150))  // Brief burst
                // Stop emitting new particles
                if var emitter = smokePuff.components[ParticleEmitterComponent.self] {
                    emitter.mainEmitter.birthRate = 0
                    smokePuff.components.set(emitter)
                }
                // Wait for existing particles to fade (2s lifespan + buffer)
                try? await Task.sleep(for: .milliseconds(2300))
                smokePuff.removeFromParent()
            }
        }
        rightHandState = HandState()
    }

    private func createSmokePuff() -> Entity {
        let puff = Entity()
        puff.name = "SmokePuff"
        puff.components.set(createSmokePuffEmitter())
        return puff
    }

    private func createSmokePuffEmitter() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.06, 0.06, 0.06]  // Slightly smaller emitter area

        // Reduced smoke - 1/4 of previous amount
        emitter.mainEmitter.birthRate = 100  // Was 400
        emitter.mainEmitter.lifeSpan = 2.0  // 2 second gradual fade
        emitter.mainEmitter.lifeSpanVariation = 0.3

        emitter.speed = 0.12
        emitter.speedVariation = 0.06
        emitter.mainEmitter.acceleration = [0, 0.18, 0]  // Rise gently

        emitter.mainEmitter.size = 0.04
        emitter.mainEmitter.sizeVariation = 0.015
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 3.5  // Expand as it fades

        // Gray smoke - gradual alpha fade from visible to zero over 2 seconds
        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 0.4, green: 0.35, blue: 0.3, alpha: 0.8)),
            end: .single(.init(red: 0.25, green: 0.22, blue: 0.18, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .alpha

        return emitter
    }

    private func checkShouldShowFireball(anchor: HandAnchor, skeleton: HandSkeleton?) -> Bool {
        guard let skeleton = skeleton else { return false }

        // Check palm orientation in WORLD space
        let isPalmUp = checkPalmFacingUp(anchor: anchor, skeleton: skeleton)

        // Check if hand is open (not a fist)
        let isHandOpen = checkHandIsOpen(skeleton: skeleton)

        return isPalmUp && isHandOpen
    }

    private func checkPalmFacingUp(anchor: HandAnchor, skeleton: HandSkeleton) -> Bool {
        let wrist = skeleton.joint(.wrist)
        guard wrist.isTracked else { return false }

        // Transform wrist to world space
        let worldWristTransform = anchor.originFromAnchorTransform * wrist.anchorFromJointTransform

        // Extract the Y axis (palm normal) in world space
        // For the wrist, the -Z axis typically points from wrist towards fingers
        // and the Y axis points out of the back of the hand
        // So we want -Y axis (palm side) to point up
        let palmNormal = SIMD3<Float>(
            -worldWristTransform.columns.1.x,
            -worldWristTransform.columns.1.y,
            -worldWristTransform.columns.1.z
        )

        let worldUp = SIMD3<Float>(0, 1, 0)
        let dotProduct = simd_dot(simd_normalize(palmNormal), worldUp)

        // Palm needs to be facing somewhat upward (threshold ~45 degrees)
        return dotProduct > 0.4
    }

    private func checkHandIsOpen(skeleton: HandSkeleton) -> Bool {
        // Check if fingers are extended (not curled into a fist)
        // We check the distance between fingertips and the palm center

        let middleTip = skeleton.joint(.middleFingerTip)
        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        let indexTip = skeleton.joint(.indexFingerTip)
        let indexKnuckle = skeleton.joint(.indexFingerKnuckle)

        guard middleTip.isTracked && middleKnuckle.isTracked &&
              indexTip.isTracked && indexKnuckle.isTracked else {
            return false
        }

        // Calculate finger extension by comparing tip-to-knuckle distance
        let middleTipPos = SIMD3<Float>(middleTip.anchorFromJointTransform.columns.3.x,
                                         middleTip.anchorFromJointTransform.columns.3.y,
                                         middleTip.anchorFromJointTransform.columns.3.z)
        let middleKnucklePos = SIMD3<Float>(middleKnuckle.anchorFromJointTransform.columns.3.x,
                                            middleKnuckle.anchorFromJointTransform.columns.3.y,
                                            middleKnuckle.anchorFromJointTransform.columns.3.z)
        let indexTipPos = SIMD3<Float>(indexTip.anchorFromJointTransform.columns.3.x,
                                        indexTip.anchorFromJointTransform.columns.3.y,
                                        indexTip.anchorFromJointTransform.columns.3.z)
        let indexKnucklePos = SIMD3<Float>(indexKnuckle.anchorFromJointTransform.columns.3.x,
                                           indexKnuckle.anchorFromJointTransform.columns.3.y,
                                           indexKnuckle.anchorFromJointTransform.columns.3.z)

        let middleExtension = simd_distance(middleTipPos, middleKnucklePos)
        let indexExtension = simd_distance(indexTipPos, indexKnucklePos)

        // When fingers are extended, tip-to-knuckle distance is ~7-10cm
        // When making a fist, it's ~3-4cm
        let extensionThreshold: Float = 0.05  // 5cm threshold

        return middleExtension > extensionThreshold && indexExtension > extensionThreshold
    }

    private func getPalmPosition(anchor: HandAnchor, skeleton: HandSkeleton?) -> SIMD3<Float> {
        guard let skeleton = skeleton else {
            return extractPosition(from: anchor.originFromAnchorTransform)
        }

        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        guard middleKnuckle.isTracked else {
            return extractPosition(from: anchor.originFromAnchorTransform)
        }

        let jointTransform = anchor.originFromAnchorTransform * middleKnuckle.anchorFromJointTransform

        return SIMD3<Float>(
            jointTransform.columns.3.x,
            jointTransform.columns.3.y + 0.08,
            jointTransform.columns.3.z
        )
    }

    private func extractPosition(from transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    // MARK: - Fireball Creation with MASSIVE particles

    private func createHandFireball() async -> Entity {
        let root = Entity()
        root.name = "HandFireball"

        // Try to use the preloaded USDZ model
        if let template = fireballTemplate {
            let fireballModel = template.clone(recursive: true)
            fireballModel.scale = [0.9, 0.9, 0.9]
            fireballModel.name = "FireballModel"
            fireballModel.components.set(RotationComponent(speed: 1.0))
            root.addChild(fireballModel)
        } else {
            let fallbackSphere = createFallbackSphere()
            root.addChild(fallbackSphere)
        }

        // MASSIVE particle effects - multiple layers

        // Layer 1: Outer flames
        let outerFlames = Entity()
        outerFlames.name = "OuterFlames"
        outerFlames.components.set(createOuterFlameParticles())
        root.addChild(outerFlames)

        // Layer 2: Mid flames
        let midFlames = Entity()
        midFlames.name = "MidFlames"
        midFlames.components.set(createMidFlameParticles())
        root.addChild(midFlames)

        // Layer 3: Inner core flames
        let innerFlames = Entity()
        innerFlames.name = "InnerFlames"
        innerFlames.components.set(createInnerFlameParticles())
        root.addChild(innerFlames)

        // Layer 4: Hot core
        let hotCore = Entity()
        hotCore.name = "HotCore"
        hotCore.components.set(createHotCoreParticles())
        root.addChild(hotCore)

        // Layer 5: Sparks
        let sparks = Entity()
        sparks.name = "Sparks"
        sparks.components.set(createSparkParticles())
        root.addChild(sparks)

        // Layer 6: Rising wisps
        let wisps = Entity()
        wisps.name = "Wisps"
        wisps.components.set(createWispParticles())
        root.addChild(wisps)

        // Layer 7: Smoke
        let smoke = Entity()
        smoke.name = "Smoke"
        smoke.position = [0, 0.025, 0]
        smoke.components.set(createSmokeParticles())
        root.addChild(smoke)

        // Bright point light
        let light = PointLight()
        light.light.color = .init(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)
        light.light.intensity = 3500
        light.light.attenuationRadius = 1.0
        root.addChild(light)

        RotationSystem.ensureRegistered()

        return root
    }

    private func createFallbackSphere() -> ModelEntity {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0))
        material.emissiveColor = .init(color: .init(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0))
        material.emissiveIntensity = 5.0
        material.roughness = 0.1

        let sphere = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [material])
        sphere.name = "FallbackFireball"
        sphere.components.set(RotationComponent(speed: 1.0))
        return sphere
    }

    private func createOuterFlameParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.07, 0.07, 0.07]

        emitter.mainEmitter.birthRate = 800
        emitter.mainEmitter.lifeSpan = 0.45
        emitter.mainEmitter.lifeSpanVariation = 0.15

        emitter.speed = 0.09
        emitter.speedVariation = 0.04
        emitter.mainEmitter.acceleration = [0, 0.25, 0]

        emitter.mainEmitter.size = 0.022
        emitter.mainEmitter.sizeVariation = 0.009
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.05

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.1, blue: 0.0, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createMidFlameParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.05, 0.05, 0.05]

        emitter.mainEmitter.birthRate = 600
        emitter.mainEmitter.lifeSpan = 0.32
        emitter.mainEmitter.lifeSpanVariation = 0.08

        emitter.speed = 0.06
        emitter.speedVariation = 0.025
        emitter.mainEmitter.acceleration = [0, 0.15, 0]

        emitter.mainEmitter.size = 0.017
        emitter.mainEmitter.sizeVariation = 0.006
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.1

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.3, blue: 0.0, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createInnerFlameParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.03, 0.03, 0.03]

        emitter.mainEmitter.birthRate = 500
        emitter.mainEmitter.lifeSpan = 0.22
        emitter.mainEmitter.lifeSpanVariation = 0.06

        emitter.speed = 0.035
        emitter.speedVariation = 0.012
        emitter.mainEmitter.acceleration = [0, 0.1, 0]

        emitter.mainEmitter.size = 0.014
        emitter.mainEmitter.sizeVariation = 0.005
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.15

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 1.0, blue: 0.7, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.5, blue: 0.1, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createHotCoreParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.018, 0.018, 0.018]

        emitter.mainEmitter.birthRate = 400
        emitter.mainEmitter.lifeSpan = 0.12
        emitter.mainEmitter.lifeSpanVariation = 0.04

        emitter.speed = 0.018
        emitter.speedVariation = 0.006
        emitter.mainEmitter.acceleration = [0, 0.03, 0]

        emitter.mainEmitter.size = 0.009
        emitter.mainEmitter.sizeVariation = 0.003
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.3

        // White-hot core
        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.9, blue: 0.5, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createSparkParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.06, 0.06, 0.06]

        emitter.mainEmitter.birthRate = 200
        emitter.mainEmitter.lifeSpan = 0.5
        emitter.mainEmitter.lifeSpanVariation = 0.2

        emitter.speed = 0.18
        emitter.speedVariation = 0.09
        emitter.mainEmitter.acceleration = [0, 0.5, 0]

        emitter.mainEmitter.size = 0.005
        emitter.mainEmitter.sizeVariation = 0.0025
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.0

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 0.9, blue: 0.5, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.3, blue: 0.0, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createWispParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.06, 0.06, 0.06]

        emitter.mainEmitter.birthRate = 150
        emitter.mainEmitter.lifeSpan = 0.45
        emitter.mainEmitter.lifeSpanVariation = 0.15

        emitter.speed = 0.12
        emitter.speedVariation = 0.06
        emitter.mainEmitter.acceleration = [0, 0.36, 0]

        emitter.mainEmitter.size = 0.012
        emitter.mainEmitter.sizeVariation = 0.006
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.02

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.8)),
            end: .single(.init(red: 1.0, green: 0.2, blue: 0.0, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive
        return emitter
    }

    private func createSmokeParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.04, 0.04, 0.04]

        // More visible continuous smoke rising from active fireball
        emitter.mainEmitter.birthRate = 150
        emitter.mainEmitter.lifeSpan = 2.0  // 2 second fade
        emitter.mainEmitter.lifeSpanVariation = 0.4

        emitter.speed = 0.08
        emitter.speedVariation = 0.03
        emitter.mainEmitter.acceleration = [0, 0.15, 0]  // Rise upward

        emitter.mainEmitter.size = 0.025
        emitter.mainEmitter.sizeVariation = 0.01
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 3.5  // Expand as it rises

        // Gradual fade from visible to transparent over lifespan
        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 0.3, green: 0.25, blue: 0.2, alpha: 0.6)),
            end: .single(.init(red: 0.15, green: 0.12, blue: 0.1, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .alpha
        return emitter
    }
}
