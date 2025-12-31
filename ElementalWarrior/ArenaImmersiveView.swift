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
            // Add floor
            let floor = ModelEntity(
                mesh: .generatePlane(width: 4, depth: 4),
                materials: [SimpleMaterial(color: .gray, isMetallic: false)]
            )
            floor.position = [0, -1.2, 0]
            content.add(floor)

            // Add the hand tracking root entity
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

    // State tracking stored in a struct to avoid exclusivity issues
    private struct HandState {
        var fireball: Entity?
        var palmWasUp: Bool = false
    }

    private var leftHandState = HandState()
    private var rightHandState = HandState()

    func startHandTracking() async {
        do {
            if HandTrackingProvider.isSupported {
                try await session.run([handTracking])
                await processHandUpdates()
            }
        } catch {
            print("Failed to start hand tracking: \(error)")
        }
    }

    private func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            let anchor = update.anchor
            let isLeft = anchor.chirality == .left

            guard anchor.isTracked else {
                // Hand lost tracking - remove fireball
                if isLeft {
                    leftHandState.fireball?.removeFromParent()
                    leftHandState = HandState()
                } else {
                    rightHandState.fireball?.removeFromParent()
                    rightHandState = HandState()
                }
                continue
            }

            // Get the hand skeleton
            let skeleton = anchor.handSkeleton

            // Check if palm is facing up
            let isPalmUp = checkPalmFacingUp(skeleton: skeleton)

            // Get palm position for fireball placement
            let palmPosition = getPalmPosition(anchor: anchor, skeleton: skeleton)

            if isLeft {
                updateHandState(state: &leftHandState, isPalmUp: isPalmUp, position: palmPosition)
            } else {
                updateHandState(state: &rightHandState, isPalmUp: isPalmUp, position: palmPosition)
            }
        }
    }

    private func updateHandState(state: inout HandState, isPalmUp: Bool, position: SIMD3<Float>) {
        if isPalmUp {
            if !state.palmWasUp {
                // Palm just turned up - spawn fireball
                let newFireball = createHandFireball()
                newFireball.position = position
                rootEntity.addChild(newFireball)
                state.fireball = newFireball
                state.palmWasUp = true
            } else if let existingFireball = state.fireball {
                // Palm still up - update fireball position
                existingFireball.position = position
            }
        } else {
            if state.palmWasUp {
                // Palm turned away - remove fireball
                state.fireball?.removeFromParent()
                state.fireball = nil
                state.palmWasUp = false
            }
        }
    }

    private func checkPalmFacingUp(skeleton: HandSkeleton?) -> Bool {
        guard let skeleton = skeleton else { return false }

        // Get the wrist joint to determine palm orientation
        let wrist = skeleton.joint(.wrist)

        // Check if joint is tracked
        guard wrist.isTracked else { return false }

        // The palm normal can be approximated by the Y axis of the wrist transform
        // When palm faces up, the Y axis of the wrist points upward (positive Y in world space)
        let wristTransform = wrist.anchorFromJointTransform

        // Extract the Y axis (up direction of the palm)
        let palmNormal = SIMD3<Float>(
            wristTransform.columns.1.x,
            wristTransform.columns.1.y,
            wristTransform.columns.1.z
        )

        // World up vector
        let worldUp = SIMD3<Float>(0, 1, 0)

        // Calculate dot product - if positive and above threshold, palm is facing up
        let dotProduct = simd_dot(palmNormal, worldUp)

        // Threshold of 0.5 means palm is roughly 60 degrees from horizontal
        return dotProduct > 0.5
    }

    private func getPalmPosition(anchor: HandAnchor, skeleton: HandSkeleton?) -> SIMD3<Float> {
        guard let skeleton = skeleton else {
            return extractPosition(from: anchor.originFromAnchorTransform)
        }

        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        guard middleKnuckle.isTracked else {
            return extractPosition(from: anchor.originFromAnchorTransform)
        }

        // Get the middle knuckle position in world space
        let jointTransform = anchor.originFromAnchorTransform * middleKnuckle.anchorFromJointTransform

        // Position fireball slightly above the palm (about 5cm)
        return SIMD3<Float>(
            jointTransform.columns.3.x,
            jointTransform.columns.3.y + 0.05,
            jointTransform.columns.3.z
        )
    }

    private func extractPosition(from transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    private func createHandFireball() -> Entity {
        let root = Entity()
        root.name = "HandFireball"

        // Create the main fireball sphere with emissive material
        var fireballMaterial = PhysicallyBasedMaterial()
        fireballMaterial.baseColor = .init(tint: .init(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0))
        fireballMaterial.emissiveColor = .init(color: .init(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0))
        fireballMaterial.emissiveIntensity = 4.0
        fireballMaterial.roughness = 0.1

        let fireballSphere = ModelEntity(
            mesh: .generateSphere(radius: 0.04),
            materials: [fireballMaterial]
        )
        fireballSphere.name = "FireballCore"
        root.addChild(fireballSphere)

        // Add flame particles
        let flameEntity = Entity()
        flameEntity.name = "FlameParticles"
        flameEntity.components.set(createHandFlameParticles())
        root.addChild(flameEntity)

        // Add smoke particles
        let smokeEntity = Entity()
        smokeEntity.name = "SmokeParticles"
        smokeEntity.position = [0, 0.02, 0]
        smokeEntity.components.set(createHandSmokeParticles())
        root.addChild(smokeEntity)

        // Add point light for glow
        let light = PointLight()
        light.light.color = .init(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)
        light.light.intensity = 1500
        light.light.attenuationRadius = 0.5
        root.addChild(light)

        // Add rotation
        fireballSphere.components.set(RotationComponent(speed: 1.0))
        RotationSystem.ensureRegistered()

        return root
    }

    private func createHandFlameParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()

        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.04, 0.04, 0.04]

        emitter.mainEmitter.birthRate = 100
        emitter.mainEmitter.lifeSpan = 0.3
        emitter.mainEmitter.lifeSpanVariation = 0.1

        emitter.speed = 0.06
        emitter.speedVariation = 0.02
        emitter.mainEmitter.acceleration = [0, 0.1, 0]

        emitter.mainEmitter.size = 0.01
        emitter.mainEmitter.sizeVariation = 0.003
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.1

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.2, blue: 0.0, alpha: 0.0))
        )

        emitter.mainEmitter.blendMode = .additive

        return emitter
    }

    private func createHandSmokeParticles() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()

        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.02, 0.02, 0.02]

        emitter.mainEmitter.birthRate = 15
        emitter.mainEmitter.lifeSpan = 0.8
        emitter.mainEmitter.lifeSpanVariation = 0.2

        emitter.speed = 0.03
        emitter.speedVariation = 0.01
        emitter.mainEmitter.acceleration = [0, 0.04, 0]

        emitter.mainEmitter.size = 0.012
        emitter.mainEmitter.sizeVariation = 0.004
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 2.0

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5)),
            end: .single(.init(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.0))
        )

        emitter.mainEmitter.blendMode = .alpha

        return emitter
    }
}
