//
//  HandTrackingManager.swift
//  ElementalWarrior
//
//  Central manager for hand tracking, fireball spawning, and projectile system.
//  Orchestrates gesture detection, collision, and scene reconstruction modules.
//

import SwiftUI
import RealityKit
import ARKit
import QuartzCore
import UIKit

// MARK: - Hand Tracking Manager

@MainActor
@Observable
final class HandTrackingManager {
    let rootEntity = Entity()

    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    private let worldTracking = WorldTrackingProvider()
    private var sceneReconstruction: SceneReconstructionProvider?

    // Preloaded templates
    private var fireballTemplate: Entity?
    private var explosionTemplate: Entity?
    private var flamethrowerTemplate: Entity?
    private var combinedFlamethrowerTemplate: Entity?

    // Combined flamethrower state (exists only while both hands are close together)
    private var combinedFlamethrower: Entity?
    private var combinedFlamethrowerAudio: AudioPlaybackController?

    // Audio Resources
    private var crackleSound: AudioFileResource?
    private var flamethrowerSound: AudioFileResource?
    private var wooshSound: AudioFileResource?
    private var explosionSound: AudioFileResource?

    // Active projectiles in flight
    private var activeProjectiles: [UUID: ProjectileState] = [:]

    // Scene mesh anchors for collision detection (live from ARKit)
    private var sceneMeshAnchors: [UUID: MeshAnchor] = [:]

    // PERSISTENT mesh cache - keeps geometry even when ARKit removes anchors
    private var persistentMeshCache: [UUID: CachedMeshGeometry] = [:]

    // Visual mesh entities for showing scanned areas
    private var scanVisualizationEntities: [UUID: Entity] = [:]

    // Scanning visualization state - observable for UI
    var isScanVisualizationEnabled: Bool = false {
        didSet {
            Task { @MainActor in
                await updateScanVisualization()
            }
        }
    }
    var scannedMeshCount: Int = 0
    var scannedTriangleCount: Int = 0
    var scannedAreaDescription: String = "No areas scanned"

    // State tracking
    private var leftHandState = HandState()
    private var rightHandState = HandState()

    // Fire Wall State
    private var confirmedFireWalls: [UUID: FireWallState] = [:]
    private var editingWallState = FireWallEditingState()

    // Store latest hand anchors for zombie pose detection (requires both hands)
    private var latestLeftAnchor: HandAnchor?
    private var latestRightAnchor: HandAnchor?

    // Gaze selection for fire walls
    private var gazeSelectedWallID: UUID?
    private var gazeSelectionStartTime: TimeInterval?

    // Simultaneous fist detection for fire wall confirmation
    private var leftFistTime: TimeInterval?
    private var rightFistTime: TimeInterval?

    // Debug state - observable for UI
    var leftHandGestureState: HandGestureState = .none
    var rightHandGestureState: HandGestureState = .none
    var leftDebugInfo: String = ""
    var rightDebugInfo: String = ""

    // MARK: - Initialization

    func startHandTracking() async {
        await loadFireballTemplate()
        await loadExplosionTemplate()
        await loadFlamethrowerTemplate()
        await loadAudioResources()

        do {
            var providers: [any DataProvider] = []

            if HandTrackingProvider.isSupported {
                providers.append(handTracking)
            }

            if WorldTrackingProvider.isSupported {
                providers.append(worldTracking)
            }

            if SceneReconstructionProvider.isSupported {
                sceneReconstruction = SceneReconstructionProvider()
                providers.append(sceneReconstruction!)
            }

            if !providers.isEmpty {
                try await session.run(providers)

                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await self.processHandUpdates() }
                    group.addTask { await self.processSceneReconstruction() }
                    group.addTask { await self.updateProjectiles() }
                }
            }
        } catch {
            print("Failed to start ARKit session: \(error)")
        }
    }

    // MARK: - Template Loading

    private func loadFireballTemplate() async {
        fireballTemplate = await MainActor.run {
            createRealisticFireball(scale: 0.7)
        }
        print("Fireball template created programmatically")
    }

    private func loadExplosionTemplate() async {
        explosionTemplate = await MainActor.run {
            createExplosionEffect()
        }
        print("Explosion template created programmatically")
    }

    private func loadFlamethrowerTemplate() async {
        flamethrowerTemplate = await MainActor.run {
            createFlamethrowerStream()
        }
        print("Flamethrower template created programmatically")

        combinedFlamethrowerTemplate = await MainActor.run {
            createCombinedFlamethrowerStream()
        }
        print("Combined flamethrower template created programmatically")
    }

    private func loadAudioResources() async {
        crackleSound = await loadAudio(named: "fire_crackle", ext: "wav", shouldLoop: true)
        flamethrowerSound = await loadAudio(named: "flamethrower_clipped", ext: "wav", shouldLoop: true)
        wooshSound = await loadAudio(named: "fire_woosh_clipped", ext: "wav", shouldLoop: false)
        explosionSound = await loadAudio(named: "explosion_clipped", ext: "wav", shouldLoop: false)
    }

    private func loadAudio(named name: String, ext: String, shouldLoop: Bool) async -> AudioFileResource? {
        do {
            let config = AudioFileResource.Configuration(shouldLoop: shouldLoop)
            if let resource = try? await AudioFileResource.load(named: "\(name).\(ext)", configuration: config) {
                return resource
            }

            if let asset = NSDataAsset(name: name) {
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent("\(name).\(ext)")
                try asset.data.write(to: tempURL)
                let resource = try await AudioFileResource.load(contentsOf: tempURL, configuration: config)
                return resource
            }

            print("Audio file '\(name)' not found in bundle or assets")
            return nil
        } catch {
            print("Failed to load audio '\(name)': \(error)")
            return nil
        }
    }

    // MARK: - Hand Update Loop

    private func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            let anchor = update.anchor
            let isLeft = anchor.chirality == .left

            // Store latest anchors for zombie pose detection
            if isLeft {
                latestLeftAnchor = anchor
            } else {
                latestRightAnchor = anchor
            }

            guard anchor.isTracked else {
                if isLeft {
                    await handleTrackingLost(isLeft: true)
                } else {
                    await handleTrackingLost(isLeft: false)
                }
                continue
            }

            let skeleton = anchor.handSkeleton
            let deviceTransform = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())?.originFromAnchorTransform

            let shouldShowFireball = GestureDetection.checkShouldShowFireball(anchor: anchor, skeleton: skeleton)
            let shouldUseFlamethrower = GestureDetection.checkShouldFireFlamethrower(
                anchor: anchor,
                skeleton: skeleton,
                deviceTransform: deviceTransform
            )
            let (isFist, fistDebugInfo) = GestureDetection.checkHandIsFist(skeleton: skeleton, isLeft: isLeft)
            let palmNormal = GestureDetection.getPalmNormal(anchor: anchor, skeleton: skeleton)

            let earlyFistPosition = GestureDetection.getFistPosition(anchor: anchor, skeleton: skeleton)

            let distToLeftFireball: Float? = leftHandState.fireball.map { simd_distance(earlyFistPosition, $0.position) }
            let distToRightFireball: Float? = rightHandState.fireball.map { simd_distance(earlyFistPosition, $0.position) }

            let isCollidingWithFireball = isFist && (
                (distToLeftFireball != nil && distToLeftFireball! < GestureConstants.punchProximityThreshold) ||
                (distToRightFireball != nil && distToRightFireball! < GestureConstants.punchProximityThreshold)
            )

            let distInfo = distToLeftFireball.map { "toL:\(String(format: "%.2f", $0))m" } ?? ""
            let distInfo2 = distToRightFireball.map { "toR:\(String(format: "%.2f", $0))m" } ?? ""
            let distString = [distInfo, distInfo2].filter { !$0.isEmpty }.joined(separator: " ")
            let hasSkeleton = skeleton != nil

            if isLeft {
                if isCollidingWithFireball {
                    leftHandGestureState = .collision
                } else if shouldUseFlamethrower {
                    leftHandGestureState = .flamethrower
                } else if isFist {
                    leftHandGestureState = .fist
                } else if shouldShowFireball {
                    leftHandGestureState = leftHandState.isShowingFireball ? .holdingFireball : .summon
                } else {
                    leftHandGestureState = .none
                }
                leftDebugInfo = "skel:\(hasSkeleton ? "✓" : "✗") \(distString)\n\(fistDebugInfo)"
            } else {
                if isCollidingWithFireball {
                    rightHandGestureState = .collision
                } else if shouldUseFlamethrower {
                    rightHandGestureState = .flamethrower
                } else if isFist {
                    rightHandGestureState = .fist
                } else if shouldShowFireball {
                    rightHandGestureState = rightHandState.isShowingFireball ? .holdingFireball : .summon
                } else {
                    rightHandGestureState = .none
                }
                rightDebugInfo = "skel:\(hasSkeleton ? "✓" : "✗") \(distString)\n\(fistDebugInfo)"
            }

            let hasLeftFireball = leftHandState.fireball != nil
            let hasRightFireball = rightHandState.fireball != nil
            if (hasLeftFireball || hasRightFireball) && Int.random(in: 0..<60) == 0 {
                print("[HAND UPDATE] \(isLeft ? "LEFT" : "RIGHT") - isFist=\(isFist), hasLeftFB=\(hasLeftFireball), hasRightFB=\(hasRightFireball), leftPending=\(leftHandState.isPendingDespawn), rightPending=\(rightHandState.isPendingDespawn)")
            }

            let palmPosition = GestureDetection.getPalmPosition(anchor: anchor, skeleton: skeleton)
            let fistPosition = GestureDetection.getFistPosition(anchor: anchor, skeleton: skeleton)

            if isLeft {
                await handleTrackingRecovered(isLeft: true, position: palmPosition)
                await updateLeftHand(
                    shouldShow: shouldShowFireball,
                    shouldFlamethrower: shouldUseFlamethrower,
                    position: palmPosition,
                    palmNormal: palmNormal,
                    fistPosition: fistPosition,
                    isFist: isFist,
                    anchor: anchor
                )
            } else {
                await handleTrackingRecovered(isLeft: false, position: palmPosition)
                await updateRightHand(
                    shouldShow: shouldShowFireball,
                    shouldFlamethrower: shouldUseFlamethrower,
                    position: palmPosition,
                    palmNormal: palmNormal,
                    fistPosition: fistPosition,
                    isFist: isFist,
                    anchor: anchor
                )
            }

            // Check for fireball combining after processing hand update
            await checkFireballCombine()

            // Check for flamethrower combining after processing hand update
            await checkFlamethrowerCombine()

            // Check for zombie pose (fire wall gesture) - requires both hands
            let deviceTransformForZombie = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())?.originFromAnchorTransform
            let zombieResult = GestureDetection.checkZombiePose(
                leftAnchor: latestLeftAnchor,
                rightAnchor: latestRightAnchor,
                deviceTransform: deviceTransformForZombie
            )

            if zombieResult.isZombiePose, let leftPos = zombieResult.leftPosition, let rightPos = zombieResult.rightPosition {
                await handleZombiePose(
                    leftPosition: leftPos,
                    rightPosition: rightPos,
                    heightPercent: zombieResult.heightPercent,
                    deviceTransform: deviceTransformForZombie
                )
                await updateGazeSelection(deviceTransform: deviceTransformForZombie)

                // Update debug state
                if isLeft {
                    leftHandGestureState = .fireWall
                } else {
                    rightHandGestureState = .fireWall
                }
            } else if editingWallState.isActive {
                await cancelFireWallEditing()
            }

            // Check for simultaneous fist confirmation (fire wall)
            await checkFireWallFistConfirmation(leftIsFist: isFist && isLeft, rightIsFist: isFist && !isLeft)
        }
    }

    // MARK: - Fireball Combining

    private func checkFireballCombine() async {
        // Both hands must have fireballs and not be animating
        guard let leftFireball = leftHandState.fireball,
              let rightFireball = rightHandState.fireball,
              leftHandState.isShowingFireball,
              rightHandState.isShowingFireball,
              !leftHandState.isAnimating,
              !rightHandState.isAnimating,
              !leftHandState.isMegaFireball,  // Don't combine if already mega
              !rightHandState.isMegaFireball else {
            return
        }

        // Check if fireballs are close enough to combine
        let distance = simd_distance(leftFireball.position, rightFireball.position)
        guard distance < GestureConstants.fireballCombineDistance else {
            return
        }

        // Determine receiver based on velocity (more stationary hand receives the mega fireball)
        let leftVelocity = GestureDetection.calculateVelocity(from: leftHandState.lastPositions)
        let rightVelocity = GestureDetection.calculateVelocity(from: rightHandState.lastPositions)
        let leftSpeed = simd_length(leftVelocity)
        let rightSpeed = simd_length(rightVelocity)

        let receiverIsLeft = leftSpeed <= rightSpeed

        await combineFireballs(receiverIsLeft: receiverIsLeft)
    }

    private func combineFireballs(receiverIsLeft: Bool) async {
        guard let receiverFireball = receiverIsLeft ? leftHandState.fireball : rightHandState.fireball,
              let donorFireball = receiverIsLeft ? rightHandState.fireball : leftHandState.fireball else {
            return
        }

        print("Combining fireballs! Receiver hand: \(receiverIsLeft ? "LEFT" : "RIGHT")")

        // Mark both as animating to prevent interference
        if receiverIsLeft {
            leftHandState.isAnimating = true
            rightHandState.isAnimating = true
        } else {
            rightHandState.isAnimating = true
            leftHandState.isAnimating = true
        }

        // Create a flash effect at the merge point
        let mergePoint = (receiverFireball.position + donorFireball.position) / 2
        let flashEntity = createMergeFlash()
        flashEntity.position = mergePoint
        rootEntity.addChild(flashEntity)

        // Remove flash after brief duration
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            flashEntity.removeFromParent()
        }

        // Prevent immediate re-summon on the donor hand until it releases the gesture
        if receiverIsLeft {
            rightHandState.suppressSpawnUntilRelease = true
        } else {
            leftHandState.suppressSpawnUntilRelease = true
        }

        // Fade out and pull in the donor fireball
        if receiverIsLeft {
            rightHandState.crackleController?.fade(to: -80, duration: 0.2)
        } else {
            leftHandState.crackleController?.fade(to: -80, duration: 0.2)
        }

        var donorTransform = donorFireball.transform
        donorTransform.translation = mergePoint
        donorTransform.scale = [0.2, 0.2, 0.2]
        donorFireball.move(to: donorTransform, relativeTo: donorFireball.parent, duration: 0.18, timingFunction: .easeIn)

        // Scale up the receiver fireball with a brief overshoot
        var receiverTransform = receiverFireball.transform
        receiverTransform.scale = SIMD3<Float>(repeating: GestureConstants.megaFireballScale * 1.15)
        receiverFireball.move(to: receiverTransform, relativeTo: receiverFireball.parent, duration: 0.18, timingFunction: .easeOut)

        // Boost crackle audio for mega fireball (+3dB while holding)
        if receiverIsLeft {
            leftHandState.crackleController?.fade(to: 3, duration: 0.3)
        } else {
            rightHandState.crackleController?.fade(to: 3, duration: 0.3)
        }

        try? await Task.sleep(for: .milliseconds(180))

        var donorFinalTransform = donorTransform
        donorFinalTransform.translation = receiverFireball.position
        donorFinalTransform.scale = [0.01, 0.01, 0.01]
        donorFireball.move(to: donorFinalTransform, relativeTo: donorFireball.parent, duration: 0.22, timingFunction: .easeIn)

        receiverTransform.scale = SIMD3<Float>(repeating: GestureConstants.megaFireballScale)
        receiverFireball.move(to: receiverTransform, relativeTo: receiverFireball.parent, duration: 0.22, timingFunction: .easeInOut)

        // Wait for animations to complete
        try? await Task.sleep(for: .milliseconds(240))

        // Remove donor fireball and clean up its state
        donorFireball.removeFromParent()
        if receiverIsLeft {
            rightHandState.crackleController?.stop()
            rightHandState.crackleController = nil
            rightHandState.fireball = nil
            rightHandState.isShowingFireball = false
            rightHandState.isPendingDespawn = false
            rightHandState.isAnimating = false
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = nil
        } else {
            leftHandState.crackleController?.stop()
            leftHandState.crackleController = nil
            leftHandState.fireball = nil
            leftHandState.isShowingFireball = false
            leftHandState.isPendingDespawn = false
            leftHandState.isAnimating = false
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = nil
        }

        // Mark the receiver hand as having a mega fireball
        if receiverIsLeft {
            leftHandState.isMegaFireball = true
            leftHandState.isAnimating = false
        } else {
            rightHandState.isMegaFireball = true
            rightHandState.isAnimating = false
        }

        print("Mega fireball created on \(receiverIsLeft ? "LEFT" : "RIGHT") hand!")
    }

    private func createMergeFlash() -> Entity {
        let entity = Entity()
        entity.name = "MergeFlash"

        var emitter = ParticleEmitterComponent()
        emitter.timing = .once(warmUp: 0, emit: .init(duration: 0.1))
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.1, 0.1, 0.1]
        emitter.birthLocation = .volume

        emitter.mainEmitter.birthRate = 3000
        emitter.mainEmitter.lifeSpan = 0.2
        emitter.mainEmitter.lifeSpanVariation = 0.05

        emitter.speed = 0.8
        emitter.speedVariation = 0.3

        emitter.mainEmitter.size = 0.04
        emitter.mainEmitter.sizeVariation = 0.02
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.1

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 1.0, green: 0.9, blue: 0.6, alpha: 1.0)),
            end: .single(.init(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .additive

        entity.components.set(emitter)

        // Add bright light flash
        let lightEntity = Entity()
        let pointLight = PointLightComponent(
            color: .orange,
            intensity: 8000,
            attenuationRadius: 3.0
        )
        lightEntity.components.set(pointLight)
        entity.addChild(lightEntity)

        return entity
    }

    // MARK: - Flamethrower Combining

    private func checkFlamethrowerCombine() async {
        // Both hands must be using flamethrowers
        guard leftHandState.isUsingFlamethrower,
              rightHandState.isUsingFlamethrower,
              let leftFlamethrower = leftHandState.flamethrower,
              let rightFlamethrower = rightHandState.flamethrower else {
            // If we were combined but one hand stopped, separate
            if combinedFlamethrower != nil {
                await separateFlamethrowers()
            }
            return
        }

        // Get the distance between hands (using flamethrower positions)
        let distance = simd_distance(leftFlamethrower.position, rightFlamethrower.position)

        let isCombined = combinedFlamethrower != nil

        if isCombined {
            // Already combined - use larger split distance for hysteresis
            if distance > GestureConstants.flamethrowerSplitDistance {
                await separateFlamethrowers()
            } else {
                // Still combined, update position/orientation
                await updateCombinedFlamethrower()
            }
        } else {
            // Not combined - check if close enough to combine
            if distance < GestureConstants.flamethrowerCombineDistance && !leftHandState.isPartOfCombinedFlamethrower {
                await combineFlamethrowers()
            }
        }
    }

    private func combineFlamethrowers() async {
        guard let leftFlamethrower = leftHandState.flamethrower,
              let rightFlamethrower = rightHandState.flamethrower else {
            return
        }

        print("Combining flamethrowers!")

        // Calculate midpoint and average direction BEFORE hiding individual flamethrowers
        let midpoint = (leftFlamethrower.position + rightFlamethrower.position) / 2

        // Extract direction from transform - columns.2 is the local Z axis in world space
        // The flamethrower stream is oriented along +Z, so this gives us the flame direction
        let leftDir = simd_normalize(SIMD3<Float>(
            leftFlamethrower.transform.matrix.columns.2.x,
            leftFlamethrower.transform.matrix.columns.2.y,
            leftFlamethrower.transform.matrix.columns.2.z
        ))
        let rightDir = simd_normalize(SIMD3<Float>(
            rightFlamethrower.transform.matrix.columns.2.x,
            rightFlamethrower.transform.matrix.columns.2.y,
            rightFlamethrower.transform.matrix.columns.2.z
        ))
        let avgDirection = simd_normalize((leftDir + rightDir) / 2)

        // Create a merge flash effect at the midpoint (like fireball combining)
        let flashEntity = createMergeFlash()
        flashEntity.position = midpoint
        rootEntity.addChild(flashEntity)

        // Remove flash after brief duration
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            flashEntity.removeFromParent()
        }

        // Fade out individual audio smoothly
        leftHandState.flamethrowerAudio?.fade(to: -80, duration: 0.2)
        rightHandState.flamethrowerAudio?.fade(to: -80, duration: 0.2)

        // Create combined flamethrower starting small for scale-up animation
        let combined = await createCombinedFlamethrower()

        var transform = combined.transform
        transform.translation = midpoint
        transform.rotation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: avgDirection)
        transform.scale = [0.3, 0.3, 0.3]  // Start small
        combined.transform = transform

        rootEntity.addChild(combined)
        combinedFlamethrower = combined

        // Animate combined flamethrower scaling up with overshoot
        var targetTransform = transform
        targetTransform.scale = [1.15, 1.15, 1.15]  // Slight overshoot
        combined.move(to: targetTransform, relativeTo: combined.parent, duration: 0.18, timingFunction: .easeOut)

        // Start combined audio with boost
        if let flameSound = flamethrowerSound {
            let controller = combined.playAudio(flameSound)
            controller.gain = -80
            controller.fade(to: GestureConstants.combinedFlamethrowerAudioBoost, duration: 0.25)
            combinedFlamethrowerAudio = controller
        }

        // Wait for overshoot animation
        try? await Task.sleep(for: .milliseconds(180))

        // Settle to final scale
        var finalTransform = combined.transform
        finalTransform.scale = [1.0, 1.0, 1.0]
        combined.move(to: finalTransform, relativeTo: combined.parent, duration: 0.12, timingFunction: .easeInOut)

        // Now hide individual flamethrowers (after combined is visible)
        leftFlamethrower.isEnabled = false
        rightFlamethrower.isEnabled = false

        // Mark hands as part of combined flamethrower
        leftHandState.isPartOfCombinedFlamethrower = true
        rightHandState.isPartOfCombinedFlamethrower = true

        print("Flamethrowers combined!")
    }

    private func updateCombinedFlamethrower() async {
        guard let combined = combinedFlamethrower,
              let leftFlamethrower = leftHandState.flamethrower,
              let rightFlamethrower = rightHandState.flamethrower else {
            return
        }

        // Update position to midpoint
        let midpoint = (leftFlamethrower.position + rightFlamethrower.position) / 2

        // Calculate average direction - columns.2 is the local Z axis (flame direction)
        let leftDir = simd_normalize(SIMD3<Float>(
            leftFlamethrower.transform.matrix.columns.2.x,
            leftFlamethrower.transform.matrix.columns.2.y,
            leftFlamethrower.transform.matrix.columns.2.z
        ))
        let rightDir = simd_normalize(SIMD3<Float>(
            rightFlamethrower.transform.matrix.columns.2.x,
            rightFlamethrower.transform.matrix.columns.2.y,
            rightFlamethrower.transform.matrix.columns.2.z
        ))
        let avgDirection = simd_normalize((leftDir + rightDir) / 2)

        // Get hit distance for length scaling (use average of both hands' last hit distances)
        let avgHitDistance = (leftHandState.lastFlamethrowerHitDistance + rightHandState.lastFlamethrowerHitDistance) / 2
        let lengthFactor = max(0.25, avgHitDistance / GestureConstants.flamethrowerRange)

        var transform = combined.transform
        transform.translation = midpoint
        transform.rotation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: avgDirection)
        transform.scale = [1, 1, lengthFactor]
        combined.transform = transform

        // Handle scorch marks from combined beam
        let now = CACurrentMediaTime()
        let avgScorchTime = max(leftHandState.lastFlamethrowerScorchTime, rightHandState.lastFlamethrowerScorchTime)
        if now - avgScorchTime > GestureConstants.flamethrowerScorchCooldown {
            // Raycast from combined position
            if let hit = CollisionSystem.raycastBeam(
                origin: midpoint + avgDirection * 0.02,
                direction: avgDirection,
                maxDistance: GestureConstants.flamethrowerRange,
                meshCache: persistentMeshCache
            ) {
                leftHandState.lastFlamethrowerScorchTime = now
                rightHandState.lastFlamethrowerScorchTime = now
                // Larger scorch for combined flamethrower
                await spawnFlamethrowerScorch(at: hit.position, normal: hit.normal, scale: GestureConstants.flamethrowerScorchScale * 1.5)
            }
        }
    }

    private func separateFlamethrowers() async {
        print("Separating flamethrowers!")

        guard let combined = combinedFlamethrower else {
            // Just clean up state if no combined flamethrower exists
            leftHandState.isPartOfCombinedFlamethrower = false
            rightHandState.isPartOfCombinedFlamethrower = false
            return
        }

        // Create a split flash effect at the combined position
        let flashEntity = createMergeFlash()
        flashEntity.position = combined.position
        rootEntity.addChild(flashEntity)

        // Remove flash after brief duration
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            flashEntity.removeFromParent()
        }

        // Fade out combined audio
        combinedFlamethrowerAudio?.fade(to: -80, duration: 0.2)

        // Animate combined flamethrower shrinking
        var shrinkTransform = combined.transform
        shrinkTransform.scale = [0.2, 0.2, 0.2]
        combined.move(to: shrinkTransform, relativeTo: combined.parent, duration: 0.15, timingFunction: .easeIn)

        // Re-enable individual flamethrowers with scale-up animation
        if let leftFlamethrower = leftHandState.flamethrower {
            leftFlamethrower.isEnabled = true
            // Start small and scale up
            var leftTransform = leftFlamethrower.transform
            let originalScale = leftTransform.scale
            leftTransform.scale = [0.3, 0.3, 0.3]
            leftFlamethrower.transform = leftTransform
            leftTransform.scale = originalScale
            leftFlamethrower.move(to: leftTransform, relativeTo: leftFlamethrower.parent, duration: 0.2, timingFunction: .easeOut)
            leftHandState.flamethrowerAudio?.fade(to: 0, duration: 0.25)
        }
        if let rightFlamethrower = rightHandState.flamethrower {
            rightFlamethrower.isEnabled = true
            // Start small and scale up
            var rightTransform = rightFlamethrower.transform
            let originalScale = rightTransform.scale
            rightTransform.scale = [0.3, 0.3, 0.3]
            rightFlamethrower.transform = rightTransform
            rightTransform.scale = originalScale
            rightFlamethrower.move(to: rightTransform, relativeTo: rightFlamethrower.parent, duration: 0.2, timingFunction: .easeOut)
            rightHandState.flamethrowerAudio?.fade(to: 0, duration: 0.25)
        }

        // Wait for shrink animation then remove combined
        try? await Task.sleep(for: .milliseconds(160))

        combined.removeFromParent()
        combinedFlamethrower = nil

        // Stop combined audio
        combinedFlamethrowerAudio?.stop()
        combinedFlamethrowerAudio = nil

        // Mark hands as no longer combined
        leftHandState.isPartOfCombinedFlamethrower = false
        rightHandState.isPartOfCombinedFlamethrower = false

        print("Flamethrowers separated!")
    }

    private func createCombinedFlamethrower() async -> Entity {
        if let template = combinedFlamethrowerTemplate {
            return template.clone(recursive: true)
        }
        return Entity()
    }

    // MARK: - Left Hand Update

    private func updateLeftHand(
        shouldShow: Bool,
        shouldFlamethrower: Bool,
        position: SIMD3<Float>,
        palmNormal: SIMD3<Float>?,
        fistPosition: SIMD3<Float>,
        isFist: Bool,
        anchor: HandAnchor
    ) async {
        GestureDetection.updatePositionHistory(for: &leftHandState, position: fistPosition)

        if shouldFlamethrower {
            await updateFlamethrower(for: .left, position: position, palmNormal: palmNormal)
            return
        } else if leftHandState.isUsingFlamethrower {
            await stopFlamethrower(for: .left)
        }

        if leftHandState.suppressSpawnUntilRelease && !shouldShow {
            leftHandState.suppressSpawnUntilRelease = false
        }
        let canSummon = CACurrentMediaTime() >= leftHandState.nextSummonAllowedTime

        // Same-hand punch
        if isFist, let fireball = leftHandState.fireball,
           (leftHandState.isShowingFireball || leftHandState.isPendingDespawn) && !leftHandState.isAnimating {
            let velocity = GestureDetection.calculateVelocity(from: leftHandState.lastPositions)
            let speed = simd_length(velocity)
            let distance = simd_distance(fistPosition, fireball.position)

            print("[LEFT SAME-HAND] isFist=\(isFist), speed=\(speed), distance=\(distance), threshold=\(GestureConstants.punchProximityThreshold)")

            if speed > GestureConstants.punchVelocityThreshold && distance < GestureConstants.punchProximityThreshold {
                print("[LEFT SAME-HAND] LAUNCHING FIREBALL!")
                await launchFireball(from: .left)
                return
            }
        }

        // Cross-hand punch
        if isFist, let rightFireball = rightHandState.fireball,
           (rightHandState.isShowingFireball || rightHandState.isPendingDespawn) && !rightHandState.isAnimating {
            let velocity = GestureDetection.calculateVelocity(from: leftHandState.lastPositions)
            let speed = simd_length(velocity)
            let distance = simd_distance(fistPosition, rightFireball.position)

            print("[LEFT CROSS-HAND] isFist=\(isFist), speed=\(speed), distance=\(distance), threshold=\(GestureConstants.punchProximityThreshold)")

            if speed > GestureConstants.punchVelocityThreshold && distance < GestureConstants.punchProximityThreshold {
                print("[LEFT CROSS-HAND] LAUNCHING RIGHT FIREBALL!")
                rightHandState.nextSummonAllowedTime = CACurrentMediaTime() + GestureConstants.crossPunchResummonDelay
                await launchFireball(from: .right)
                return
            }
        }

        // State transitions
        if shouldShow && canSummon && !leftHandState.isShowingFireball && !leftHandState.isAnimating && !leftHandState.suppressSpawnUntilRelease {
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = nil
            leftHandState.isPendingDespawn = false

            leftHandState.isShowingFireball = true
            leftHandState.isAnimating = true

            let fireball = await createHandFireball()
            fireball.position = position
            fireball.scale = [0.01, 0.01, 0.01]

            if let crackle = crackleSound {
                let controller = fireball.playAudio(crackle)
                controller.gain = -80
                controller.fade(to: 0, duration: 0.5)
                leftHandState.crackleController = controller
            }

            rootEntity.addChild(fireball)
            leftHandState.fireball = fireball

            await animateSpawnLeft(entity: fireball)

        } else if shouldShow && leftHandState.isPendingDespawn {
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = nil
            leftHandState.isPendingDespawn = false

        } else if !shouldShow && leftHandState.isShowingFireball && !leftHandState.isAnimating && !leftHandState.isPendingDespawn {
            leftHandState.isPendingDespawn = true
            leftHandState.despawnTask = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(for: .milliseconds(Int(GestureConstants.despawnDelayDuration * 1000)))
                guard !Task.isCancelled else { return }
                if self.leftHandState.isPendingDespawn {
                    await self.extinguishLeft()
                }
            }

        } else if leftHandState.isShowingFireball, let fireball = leftHandState.fireball, !leftHandState.isAnimating {
            if shouldShow {
                fireball.position = position
            }
        }
    }

    // MARK: - Right Hand Update

    private func updateRightHand(
        shouldShow: Bool,
        shouldFlamethrower: Bool,
        position: SIMD3<Float>,
        palmNormal: SIMD3<Float>?,
        fistPosition: SIMD3<Float>,
        isFist: Bool,
        anchor: HandAnchor
    ) async {
        GestureDetection.updatePositionHistory(for: &rightHandState, position: fistPosition)

        if shouldFlamethrower {
            await updateFlamethrower(for: .right, position: position, palmNormal: palmNormal)
            return
        } else if rightHandState.isUsingFlamethrower {
            await stopFlamethrower(for: .right)
        }

        if rightHandState.suppressSpawnUntilRelease && !shouldShow {
            rightHandState.suppressSpawnUntilRelease = false
        }
        let canSummon = CACurrentMediaTime() >= rightHandState.nextSummonAllowedTime

        // Same-hand punch
        if isFist, let fireball = rightHandState.fireball,
           (rightHandState.isShowingFireball || rightHandState.isPendingDespawn) && !rightHandState.isAnimating {
            let velocity = GestureDetection.calculateVelocity(from: rightHandState.lastPositions)
            let speed = simd_length(velocity)
            let distance = simd_distance(fistPosition, fireball.position)

            print("[RIGHT SAME-HAND] isFist=\(isFist), speed=\(speed), distance=\(distance), threshold=\(GestureConstants.punchProximityThreshold)")

            if speed > GestureConstants.punchVelocityThreshold && distance < GestureConstants.punchProximityThreshold {
                print("[RIGHT SAME-HAND] LAUNCHING FIREBALL!")
                await launchFireball(from: .right)
                return
            }
        }

        // Cross-hand punch
        if isFist, let leftFireball = leftHandState.fireball,
           (leftHandState.isShowingFireball || leftHandState.isPendingDespawn) && !leftHandState.isAnimating {
            let velocity = GestureDetection.calculateVelocity(from: rightHandState.lastPositions)
            let speed = simd_length(velocity)
            let distance = simd_distance(fistPosition, leftFireball.position)

            print("[RIGHT CROSS-HAND] isFist=\(isFist), speed=\(speed), distance=\(distance), threshold=\(GestureConstants.punchProximityThreshold)")

            if speed > GestureConstants.punchVelocityThreshold && distance < GestureConstants.punchProximityThreshold {
                print("[RIGHT CROSS-HAND] LAUNCHING LEFT FIREBALL!")
                leftHandState.nextSummonAllowedTime = CACurrentMediaTime() + GestureConstants.crossPunchResummonDelay
                await launchFireball(from: .left)
                return
            }
        }

        // State transitions
        if shouldShow && canSummon && !rightHandState.isShowingFireball && !rightHandState.isAnimating && !rightHandState.suppressSpawnUntilRelease {
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = nil
            rightHandState.isPendingDespawn = false

            rightHandState.isShowingFireball = true
            rightHandState.isAnimating = true

            let fireball = await createHandFireball()
            fireball.position = position
            fireball.scale = [0.01, 0.01, 0.01]

            if let crackle = crackleSound {
                let controller = fireball.playAudio(crackle)
                controller.gain = -80
                controller.fade(to: 0, duration: 0.5)
                rightHandState.crackleController = controller
            }

            rootEntity.addChild(fireball)
            rightHandState.fireball = fireball

            await animateSpawnRight(entity: fireball)

        } else if shouldShow && rightHandState.isPendingDespawn {
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = nil
            rightHandState.isPendingDespawn = false

        } else if !shouldShow && rightHandState.isShowingFireball && !rightHandState.isAnimating && !rightHandState.isPendingDespawn {
            rightHandState.isPendingDespawn = true
            rightHandState.despawnTask = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(for: .milliseconds(Int(GestureConstants.despawnDelayDuration * 1000)))
                guard !Task.isCancelled else { return }
                if self.rightHandState.isPendingDespawn {
                    await self.extinguishRight()
                }
            }

        } else if rightHandState.isShowingFireball, let fireball = rightHandState.fireball, !rightHandState.isAnimating {
            if shouldShow {
                fireball.position = position
            }
        }
    }

    // MARK: - Flamethrower

    private func updateFlamethrower(
        for hand: HandAnchor.Chirality,
        position: SIMD3<Float>,
        palmNormal: SIMD3<Float>?
    ) async {
        guard let palmNormal = palmNormal, simd_length(palmNormal) > 0.001 else {
            await stopFlamethrower(for: hand)
            return
        }

        if hand == .left, leftHandState.fireball != nil {
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = nil
            await extinguishLeft()
        } else if hand == .right, rightHandState.fireball != nil {
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = nil
            await extinguishRight()
        }

        var state = hand == .left ? leftHandState : rightHandState

        if state.flamethrower == nil {
            let stream = await createFlamethrower()
            stream.transform.scale = [1, 1, 1]
            rootEntity.addChild(stream)

            if state.flamethrowerAudio == nil, let flame = flamethrowerSound {
                let controller = stream.playAudio(flame)
                controller.gain = -80
                controller.fade(to: 0, duration: 0.5)
                state.flamethrowerAudio = controller
            }

            state.flamethrower = stream
        }

        guard let flamethrower = state.flamethrower else { return }

        // Slight upward bias to keep the jet aligned with palm instead of dipping
        let direction = simd_normalize(palmNormal + SIMD3<Float>(0, 0.08, 0))
        let origin = position + direction * 0.02  // bring emission closer to palm

        let maxRange = GestureConstants.flamethrowerRange
        let now = CACurrentMediaTime()
        var hit: CollisionSystem.HitResult? = nil

        // Limit expensive mesh raycasts to reduce main-actor load
        if now - state.lastFlamethrowerRaycastTime > GestureConstants.flamethrowerRaycastInterval {
            hit = CollisionSystem.raycastBeam(
                origin: origin,
                direction: direction,
                maxDistance: maxRange,
                meshCache: persistentMeshCache
            )
            state.lastFlamethrowerRaycastTime = now
            state.lastFlamethrowerHitDistance = hit.map { simd_distance(origin, $0.position) } ?? maxRange
        } else {
            // Reuse last distance to keep stream length stable between raycasts
            hit = nil
        }

        var lengthFactor: Float = 1.0

        if let hit = hit {
            let distance = min(simd_distance(origin, hit.position), maxRange)
            lengthFactor = max(0.25, distance / maxRange)

            // Only spawn scorch marks if NOT part of combined flamethrower
            // (combined flamethrower handles its own scorch marks)
            let now = CACurrentMediaTime()
            if !state.isPartOfCombinedFlamethrower &&
               now - state.lastFlamethrowerScorchTime > GestureConstants.flamethrowerScorchCooldown {
                state.lastFlamethrowerScorchTime = now
                await spawnFlamethrowerScorch(at: hit.position, normal: hit.normal)
            }
        } else {
            let distance = min(state.lastFlamethrowerHitDistance, maxRange)
            lengthFactor = max(0.25, distance / maxRange)
        }

        var transform = flamethrower.transform
        transform.translation = origin
        transform.rotation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
        transform.scale = [1, 1, lengthFactor]
        flamethrower.transform = transform

        state.isUsingFlamethrower = true

        if hand == .left {
            leftHandState = state
        } else {
            rightHandState = state
        }
    }

    private func stopFlamethrower(for hand: HandAnchor.Chirality) async {
        var state = hand == .left ? leftHandState : rightHandState

        guard state.isUsingFlamethrower || state.flamethrower != nil else { return }

        let flamethrowerEntity = state.flamethrower
        state.flamethrowerDespawnTask?.cancel()
        state.flamethrowerDespawnTask = nil

        if let audio = state.flamethrowerAudio {
            audio.fade(to: -80, duration: 0.5)
            Task {
                try? await Task.sleep(for: .milliseconds(520))
                audio.stop()
            }
        }

        if let stream = flamethrowerEntity {
            Task { @MainActor in
                await fadeOutScorch(stream, duration: 0.5)
                stream.removeFromParent()
            }

            let smoke = await createFlamethrowerShutdownSmoke()
            smoke.transform = stream.transform
            rootEntity.addChild(smoke)

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                if var emitter = smoke.components[ParticleEmitterComponent.self] {
                    emitter.mainEmitter.birthRate = 0
                    smoke.components.set(emitter)
                }
                try? await Task.sleep(for: .milliseconds(1100))
                smoke.removeFromParent()
            }
        }

        state.flamethrower = nil
        state.flamethrowerAudio = nil
        state.isUsingFlamethrower = false
        state.lastFlamethrowerScorchTime = 0
        state.isPartOfCombinedFlamethrower = false

        if hand == .left {
            leftHandState = state
        } else {
            rightHandState = state
        }
    }

    @MainActor
    private func spawnFlamethrowerScorch(at position: SIMD3<Float>, normal: SIMD3<Float>, scale: Float? = nil) async {
        let baseScale = scale ?? GestureConstants.flamethrowerScorchScale
        let scorchScale = baseScale * Float.random(in: 0.9...1.05)
        let scorch = createFlamethrowerScorchMark(scale: scorchScale)
        let scorchPosition = position + normal * 0.008
        scorch.position = scorchPosition
        scorch.look(at: scorchPosition - normal, from: scorchPosition, relativeTo: nil)
        scorch.scale = [scorchScale, scorchScale, scorchScale]

        rootEntity.addChild(scorch)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(GestureConstants.flamethrowerScorchLifetime * 1000)))
            await fadeOutScorch(scorch, duration: 0.45)
            scorch.removeFromParent()
        }
    }

    // MARK: - Spawn Animations

    private func animateSpawnLeft(entity: Entity) async {
        var transform = entity.transform
        transform.scale = [1.0, 1.0, 1.0]
        entity.move(to: transform, relativeTo: entity.parent, duration: 0.5, timingFunction: .easeOut)
        try? await Task.sleep(for: .milliseconds(500))
        leftHandState.isAnimating = false
    }

    private func animateSpawnRight(entity: Entity) async {
        var transform = entity.transform
        transform.scale = [1.0, 1.0, 1.0]
        entity.move(to: transform, relativeTo: entity.parent, duration: 0.5, timingFunction: .easeOut)
        try? await Task.sleep(for: .milliseconds(500))
        rightHandState.isAnimating = false
    }

    // MARK: - Extinguish Animations

    private func extinguishLeft() async {
        guard let fireball = leftHandState.fireball else { return }

        leftHandState.crackleController?.fade(to: -80, duration: 0.25)

        leftHandState.isAnimating = true
        let position = fireball.position

        let smokePuff = createSmokePuff()
        smokePuff.position = position
        smokePuff.scale = [0.01, 0.01, 0.01]
        rootEntity.addChild(smokePuff)

        let duration = 0.25

        var fireTransform = fireball.transform
        fireTransform.scale = [0.001, 0.001, 0.001]
        fireball.move(to: fireTransform, relativeTo: fireball.parent, duration: duration, timingFunction: .linear)

        var smokeTransform = smokePuff.transform
        smokeTransform.scale = [1.0, 1.0, 1.0]
        smokePuff.move(to: smokeTransform, relativeTo: smokePuff.parent, duration: duration, timingFunction: .linear)

        try? await Task.sleep(for: .milliseconds(Int(duration * 1000) + 50))

        fireball.removeFromParent()
        leftHandState.fireball = nil
        leftHandState.isShowingFireball = false
        leftHandState.isPendingDespawn = false
        leftHandState.isAnimating = false
        leftHandState.isMegaFireball = false

        leftHandState.crackleController?.stop()
        leftHandState.crackleController = nil

        Task {
            try? await Task.sleep(for: .milliseconds(100))
            if var emitter = smokePuff.components[ParticleEmitterComponent.self] {
                emitter.mainEmitter.birthRate = 0
                smokePuff.components.set(emitter)
            }
            try? await Task.sleep(for: .milliseconds(2500))
            smokePuff.removeFromParent()
        }
    }

    private func extinguishRight() async {
        guard let fireball = rightHandState.fireball else { return }

        rightHandState.crackleController?.fade(to: -80, duration: 0.25)

        rightHandState.isAnimating = true
        let position = fireball.position

        let smokePuff = createSmokePuff()
        smokePuff.position = position
        smokePuff.scale = [0.01, 0.01, 0.01]
        rootEntity.addChild(smokePuff)

        let duration = 0.25

        var fireTransform = fireball.transform
        fireTransform.scale = [0.001, 0.001, 0.001]
        fireball.move(to: fireTransform, relativeTo: fireball.parent, duration: duration, timingFunction: .linear)

        var smokeTransform = smokePuff.transform
        smokeTransform.scale = [1.0, 1.0, 1.0]
        smokePuff.move(to: smokeTransform, relativeTo: smokePuff.parent, duration: duration, timingFunction: .linear)

        try? await Task.sleep(for: .milliseconds(Int(duration * 1000) + 50))

        fireball.removeFromParent()
        rightHandState.fireball = nil
        rightHandState.isShowingFireball = false
        rightHandState.isPendingDespawn = false
        rightHandState.isAnimating = false
        rightHandState.isMegaFireball = false

        rightHandState.crackleController?.stop()
        rightHandState.crackleController = nil

        Task {
            try? await Task.sleep(for: .milliseconds(100))
            if var emitter = smokePuff.components[ParticleEmitterComponent.self] {
                emitter.mainEmitter.birthRate = 0
                smokePuff.components.set(emitter)
            }
            try? await Task.sleep(for: .milliseconds(2500))
            smokePuff.removeFromParent()
        }
    }

    private func forceExtinguishLeft() async {
        await stopFlamethrower(for: .left)
        if let fireball = leftHandState.fireball {
            leftHandState.crackleController?.stop()
            let smokePuff = createSmokePuff()
            smokePuff.position = fireball.position
            rootEntity.addChild(smokePuff)
            fireball.removeFromParent()

            Task {
                try? await Task.sleep(for: .milliseconds(150))
                if var emitter = smokePuff.components[ParticleEmitterComponent.self] {
                    emitter.mainEmitter.birthRate = 0
                    smokePuff.components.set(emitter)
                }
                try? await Task.sleep(for: .milliseconds(2300))
                smokePuff.removeFromParent()
            }
        }
        leftHandState = HandState()
    }

    private func forceExtinguishRight() async {
        await stopFlamethrower(for: .right)
        if let fireball = rightHandState.fireball {
            rightHandState.crackleController?.stop()
            let smokePuff = createSmokePuff()
            smokePuff.position = fireball.position
            rootEntity.addChild(smokePuff)
            fireball.removeFromParent()

            Task {
                try? await Task.sleep(for: .milliseconds(150))
                if var emitter = smokePuff.components[ParticleEmitterComponent.self] {
                    emitter.mainEmitter.birthRate = 0
                    smokePuff.components.set(emitter)
                }
                try? await Task.sleep(for: .milliseconds(2300))
                smokePuff.removeFromParent()
            }
        }
        rightHandState = HandState()
    }

    // MARK: - Tracking Recovery

    private func handleTrackingLost(isLeft: Bool) async {
        if isLeft {
            if leftHandState.isTrackingLost { return }
            leftHandState.isTrackingLost = true
            leftHandState.lastKnownPosition = leftHandState.fireball?.position
            leftHandState.despawnTask?.cancel()
            if leftHandState.fireball != nil {
                leftHandState.despawnTask = Task { [weak self] in
                    guard let self = self else { return }
                    try? await Task.sleep(for: .milliseconds(Int(GestureConstants.trackingLostGraceDuration * 1000)))
                    guard !Task.isCancelled else { return }
                    await self.forceExtinguishLeft()
                }
            }

            if leftHandState.isUsingFlamethrower {
                leftHandState.flamethrowerDespawnTask?.cancel()
                leftHandState.flamethrowerDespawnTask = Task { [weak self] in
                    guard let self = self else { return }
                    try? await Task.sleep(for: .milliseconds(Int(GestureConstants.flamethrowerTrackingGraceDuration * 1000)))
                    guard !Task.isCancelled else { return }
                    await self.stopFlamethrower(for: .left)
                }
            }
        } else {
            if rightHandState.isTrackingLost { return }
            rightHandState.isTrackingLost = true
            rightHandState.lastKnownPosition = rightHandState.fireball?.position
            rightHandState.despawnTask?.cancel()
            if rightHandState.fireball != nil {
                rightHandState.despawnTask = Task { [weak self] in
                    guard let self = self else { return }
                    try? await Task.sleep(for: .milliseconds(Int(GestureConstants.trackingLostGraceDuration * 1000)))
                    guard !Task.isCancelled else { return }
                    await self.forceExtinguishRight()
                }
            }

            if rightHandState.isUsingFlamethrower {
                rightHandState.flamethrowerDespawnTask?.cancel()
                rightHandState.flamethrowerDespawnTask = Task { [weak self] in
                    guard let self = self else { return }
                    try? await Task.sleep(for: .milliseconds(Int(GestureConstants.flamethrowerTrackingGraceDuration * 1000)))
                    guard !Task.isCancelled else { return }
                    await self.stopFlamethrower(for: .right)
                }
            }
        }
    }

    private func handleTrackingRecovered(isLeft: Bool, position: SIMD3<Float>) async {
        if isLeft {
            guard leftHandState.isTrackingLost else { return }
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = nil
            leftHandState.flamethrowerDespawnTask?.cancel()
            leftHandState.flamethrowerDespawnTask = nil
            leftHandState.isTrackingLost = false
            if let fireball = leftHandState.fireball {
                var transform = fireball.transform
                transform.translation = position
                fireball.move(to: transform, relativeTo: fireball.parent, duration: 0.2, timingFunction: .easeOut)
            }
            if let flamethrower = leftHandState.flamethrower {
                var transform = flamethrower.transform
                transform.translation = position
                flamethrower.move(to: transform, relativeTo: flamethrower.parent, duration: 0.2, timingFunction: .easeOut)
            }
            leftHandState.lastKnownPosition = nil
        } else {
            guard rightHandState.isTrackingLost else { return }
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = nil
            rightHandState.flamethrowerDespawnTask?.cancel()
            rightHandState.flamethrowerDespawnTask = nil
            rightHandState.isTrackingLost = false
            if let fireball = rightHandState.fireball {
                var transform = fireball.transform
                transform.translation = position
                fireball.move(to: transform, relativeTo: fireball.parent, duration: 0.2, timingFunction: .easeOut)
            }
            if let flamethrower = rightHandState.flamethrower {
                var transform = flamethrower.transform
                transform.translation = position
                flamethrower.move(to: transform, relativeTo: flamethrower.parent, duration: 0.2, timingFunction: .easeOut)
            }
            rightHandState.lastKnownPosition = nil
        }
    }

    // MARK: - Gaze Direction

    private func getGazeDirection() -> SIMD3<Float>? {
        guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        let transform = deviceAnchor.originFromAnchorTransform
        let forward = SIMD3<Float>(
            -transform.columns.2.x,
            -transform.columns.2.y,
            -transform.columns.2.z
        )
        return simd_normalize(forward)
    }

    // MARK: - Fireball Launch

    private func launchFireball(from chirality: HandAnchor.Chirality) async {
        let state = chirality == .left ? leftHandState : rightHandState
        guard let fireball = state.fireball else { return }

        let launchDirection: SIMD3<Float>
        if let gazeDir = getGazeDirection() {
            launchDirection = gazeDir
        } else {
            let velocity = GestureDetection.calculateVelocity(from: state.lastPositions)
            if simd_length(velocity) > 0.1 {
                launchDirection = simd_normalize(velocity)
            } else {
                launchDirection = SIMD3<Float>(0, 0, -1)
            }
        }

        await launchWithDirection(fireball: fireball, direction: launchDirection, hand: chirality)
    }

    private func launchWithDirection(fireball: Entity, direction: SIMD3<Float>, hand: HandAnchor.Chirality) async {
        // Capture mega state before clearing hand state
        let isMega: Bool
        if hand == .left {
            isMega = leftHandState.isMegaFireball
            leftHandState.crackleController?.fade(to: -80, duration: 0.1)
            leftHandState.crackleController = nil

            leftHandState.fireball = nil
            leftHandState.isShowingFireball = false
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = nil
            leftHandState.isPendingDespawn = false
            leftHandState.lastPositions = []
            leftHandState.isMegaFireball = false
        } else {
            isMega = rightHandState.isMegaFireball
            rightHandState.crackleController?.fade(to: -80, duration: 0.1)
            rightHandState.crackleController = nil

            rightHandState.fireball = nil
            rightHandState.isShowingFireball = false
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = nil
            rightHandState.isPendingDespawn = false
            rightHandState.lastPositions = []
            rightHandState.isMegaFireball = false
        }

        if let woosh = wooshSound {
            let controller = fireball.playAudio(woosh)
            // Boost woosh volume for mega fireballs
            if isMega {
                controller.gain = GestureConstants.megaAudioGainBoost
            }
        }

        let projectileID = UUID()
        let startPos = fireball.position

        let trail = createFireTrail()
        fireball.addChild(trail)

        activeProjectiles[projectileID] = ProjectileState(
            entity: fireball,
            direction: direction,
            startPosition: startPos,
            startTime: CACurrentMediaTime(),
            speed: GestureConstants.projectileSpeed,
            trailEntity: trail,
            previousPosition: startPos,
            isMegaFireball: isMega
        )

        print("Launched \(isMega ? "MEGA " : "")fireball from \(hand) in direction \(direction)")
    }

    // MARK: - Projectile Update Loop

    private func updateProjectiles() async {
        while true {
            try? await Task.sleep(for: .milliseconds(16))

            let currentTime = CACurrentMediaTime()
            var projectilesToRemove: [UUID] = []
            var projectilesToUpdate: [(UUID, SIMD3<Float>)] = []

            for (id, projectile) in activeProjectiles {
                let elapsed = Float(currentTime - projectile.startTime)
                let travelDistance = elapsed * projectile.speed

                if travelDistance > GestureConstants.maxProjectileRange {
                    await triggerExplosion(at: projectile.entity.position, projectileID: id, isMega: projectile.isMegaFireball)
                    projectilesToRemove.append(id)
                    continue
                }

                let newPosition = projectile.startPosition + projectile.direction * travelDistance

                if let hit = CollisionSystem.checkProjectileCollision(
                    projectilePosition: newPosition,
                    direction: projectile.direction,
                    previousPosition: projectile.previousPosition,
                    meshCache: persistentMeshCache
                ) {
                    await triggerExplosion(at: hit.position, normal: hit.normal, projectileID: id, isMega: projectile.isMegaFireball)
                    projectilesToRemove.append(id)
                    print("\(projectile.isMegaFireball ? "MEGA " : "")Fireball hit real-world surface at \(hit.position)")
                    continue
                }

                projectile.entity.position = newPosition
                projectilesToUpdate.append((id, newPosition))
            }

            for (id, newPosition) in projectilesToUpdate {
                if var projectile = activeProjectiles[id] {
                    projectile.previousPosition = newPosition
                    activeProjectiles[id] = projectile
                }
            }

            for id in projectilesToRemove {
                activeProjectiles.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Scene Reconstruction

    private func processSceneReconstruction() async {
        guard let sceneReconstruction = sceneReconstruction else { return }

        for await update in sceneReconstruction.anchorUpdates {
            let anchor = update.anchor

            switch update.event {
            case .added, .updated:
                sceneMeshAnchors[anchor.id] = anchor

                let cachedGeometry = CachedMeshGeometry(from: anchor)
                persistentMeshCache[anchor.id] = cachedGeometry

                updateScanStatistics()

                let collisionEntity = await createCollisionMesh(from: anchor)
                if let existing = rootEntity.findEntity(named: "SceneMesh_\(anchor.id)") {
                    existing.removeFromParent()
                }
                collisionEntity.name = "SceneMesh_\(anchor.id)"
                rootEntity.addChild(collisionEntity)

                if isScanVisualizationEnabled {
                    await createOrUpdateVisualization(for: anchor)
                }

            case .removed:
                sceneMeshAnchors.removeValue(forKey: anchor.id)

                if let existing = rootEntity.findEntity(named: "SceneMesh_\(anchor.id)") {
                    existing.removeFromParent()
                }

                print("Mesh \(anchor.id) removed from ARKit but kept in persistent cache")

            @unknown default:
                break
            }
        }
    }

    // MARK: - Scan Statistics

    private func updateScanStatistics() {
        scannedMeshCount = persistentMeshCache.count
        scannedTriangleCount = persistentMeshCache.values.reduce(0) { $0 + $1.triangleIndices.count }

        let estimatedArea = Float(scannedTriangleCount) * 0.01
        if estimatedArea < 1 {
            scannedAreaDescription = String(format: "%.0f triangles scanned", Float(scannedTriangleCount))
        } else {
            scannedAreaDescription = String(format: "~%.1f m² scanned (%d meshes)", estimatedArea, scannedMeshCount)
        }
    }

    // MARK: - Scan Visualization

    func toggleScanVisualization() {
        isScanVisualizationEnabled.toggle()
    }

    func clearScannedData() {
        persistentMeshCache.removeAll()

        for (_, entity) in scanVisualizationEntities {
            entity.removeFromParent()
        }
        scanVisualizationEntities.removeAll()

        updateScanStatistics()
        print("Cleared all persistent mesh data")
    }

    private func updateScanVisualization() async {
        if isScanVisualizationEnabled {
            for (id, cached) in persistentMeshCache {
                await createVisualizationFromCache(id: id, cached: cached)
            }
        } else {
            for (_, entity) in scanVisualizationEntities {
                entity.removeFromParent()
            }
            scanVisualizationEntities.removeAll()
        }
    }

    private func createOrUpdateVisualization(for anchor: MeshAnchor) async {
        guard isScanVisualizationEnabled else { return }

        if let existing = scanVisualizationEntities[anchor.id] {
            existing.removeFromParent()
        }

        let vizEntity = await createWireframeMesh(from: anchor)
        vizEntity.name = "ScanViz_\(anchor.id)"
        rootEntity.addChild(vizEntity)
        scanVisualizationEntities[anchor.id] = vizEntity
    }

    private func createVisualizationFromCache(id: UUID, cached: CachedMeshGeometry) async {
        if let existing = scanVisualizationEntities[id] {
            existing.removeFromParent()
        }

        let vizEntity = Entity()
        vizEntity.transform = Transform(matrix: cached.transform)
        vizEntity.name = "ScanViz_\(id)"

        do {
            var descr = MeshDescriptor(name: "cachedMesh")
            descr.positions = MeshBuffer(cached.vertices)

            var indices: [UInt32] = []
            for tri in cached.triangleIndices {
                indices.append(tri.0)
                indices.append(tri.1)
                indices.append(tri.2)
            }
            descr.primitives = .triangles(indices)

            let mesh = try MeshResource.generate(from: [descr])

            var material = UnlitMaterial()
            material.color = .init(tint: .init(red: 0, green: 0.8, blue: 1, alpha: 0.15))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.15))

            let modelComponent = ModelComponent(mesh: mesh, materials: [material])
            vizEntity.components.set(modelComponent)
        } catch {
            print("Failed to create visualization mesh: \(error)")
        }

        rootEntity.addChild(vizEntity)
        scanVisualizationEntities[id] = vizEntity
    }

    private func createWireframeMesh(from anchor: MeshAnchor) async -> Entity {
        let entity = Entity()
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)

        do {
            let geometry = anchor.geometry

            var vertices: [SIMD3<Float>] = []
            let vertexBuffer = geometry.vertices
            let vertexPointer = vertexBuffer.buffer.contents()
            let vertexStride = vertexBuffer.stride

            for i in 0..<vertexBuffer.count {
                let vertexPtr = vertexPointer.advanced(by: i * vertexStride)
                    .bindMemory(to: SIMD3<Float>.self, capacity: 1)
                vertices.append(vertexPtr.pointee)
            }

            let faceBuffer = geometry.faces
            let indexPointer = faceBuffer.buffer.contents()
            let bytesPerIndex = faceBuffer.bytesPerIndex
            var indices: [UInt32] = []

            for faceIndex in 0..<faceBuffer.count {
                if bytesPerIndex == 2 {
                    let indexPtr = indexPointer.advanced(by: faceIndex * 3 * bytesPerIndex)
                        .bindMemory(to: UInt16.self, capacity: 3)
                    indices.append(UInt32(indexPtr[0]))
                    indices.append(UInt32(indexPtr[1]))
                    indices.append(UInt32(indexPtr[2]))
                } else {
                    let indexPtr = indexPointer.advanced(by: faceIndex * 3 * bytesPerIndex)
                        .bindMemory(to: UInt32.self, capacity: 3)
                    indices.append(indexPtr[0])
                    indices.append(indexPtr[1])
                    indices.append(indexPtr[2])
                }
            }

            var descr = MeshDescriptor(name: "scanMesh")
            descr.positions = MeshBuffer(vertices)
            descr.primitives = .triangles(indices)

            let mesh = try MeshResource.generate(from: [descr])

            var material = UnlitMaterial()
            material.color = .init(tint: .init(red: 0, green: 0.8, blue: 1, alpha: 0.15))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.15))

            let modelComponent = ModelComponent(mesh: mesh, materials: [material])
            entity.components.set(modelComponent)
        } catch {
            print("Failed to create wireframe mesh: \(error)")
        }

        return entity
    }

    private func createCollisionMesh(from anchor: MeshAnchor) async -> Entity {
        let entity = Entity()
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)

        do {
            let shape = try await ShapeResource.generateStaticMesh(from: anchor)
            var collision = CollisionComponent(shapes: [shape])
            collision.filter = CollisionFilter(
                group: CollisionGroup(rawValue: 1 << 1),
                mask: CollisionGroup(rawValue: 1 << 0)
            )
            entity.components.set(collision)
        } catch {
            print("Failed to generate collision shape: \(error)")
        }

        return entity
    }

    // MARK: - Explosion System

    private func triggerExplosion(at position: SIMD3<Float>, normal: SIMD3<Float>? = nil, projectileID: UUID, isMega: Bool = false) async {
        if let projectile = activeProjectiles[projectileID] {
            projectile.entity.removeFromParent()
            activeProjectiles.removeValue(forKey: projectileID)
        }

        // Use scaled explosion for mega fireballs
        let scale = isMega ? GestureConstants.megaExplosionScale : 1.0
        let explosion = createExplosionEffect(scale: scale)

        explosion.position = position

        var audioController: AudioPlaybackController?
        if let explosionSound = explosionSound {
            audioController = explosion.playAudio(explosionSound)
            // Boost audio for mega explosions
            if isMega {
                audioController?.gain = GestureConstants.megaAudioGainBoost
            }
        }

        rootEntity.addChild(explosion)

        if let normal = normal {
            Task {
                // Use scaled scorch mark for mega fireballs
                let scorchScale = isMega ? GestureConstants.megaScorchScale : 1.0
                let scorch = createScorchMark(scale: scorchScale)
                let scorchPosition = position + normal * 0.01
                scorch.position = scorchPosition

                scorch.look(at: scorchPosition - normal, from: scorchPosition, relativeTo: nil)

                // Animate from 70% to full size
                let baseScale = scorchScale * 0.7
                let fullScale = scorchScale
                scorch.scale = [baseScale, baseScale, baseScale]

                rootEntity.addChild(scorch)

                var transform = scorch.transform
                transform.scale = [fullScale, fullScale, fullScale]
                scorch.move(to: transform, relativeTo: scorch.parent, duration: 0.5, timingFunction: .easeOut)

                Task {
                    try? await Task.sleep(for: .seconds(16))
                    await fadeOutScorch(scorch, duration: 1.0)
                    scorch.removeFromParent()
                }
            }
        }

        print("Explosion at \(position)\(isMega ? " (MEGA)" : "")")

        // Light intensity scales with mega explosions
        let baseIntensity: Float = isMega ? 5000 * scale : 5000
        Task {
            if let lightEntity = explosion.children.first(where: {
                $0.components[PointLightComponent.self] != nil
            }) {
                let steps = 20
                for i in 0..<steps {
                    try? await Task.sleep(for: .milliseconds(50))
                    if var light = lightEntity.components[PointLightComponent.self] {
                        light.intensity = baseIntensity * Float(steps - i) / Float(steps)
                        lightEntity.components.set(light)
                    }
                }
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(1500))

            audioController?.fade(to: -80, duration: 0.3)

            try? await Task.sleep(for: .milliseconds(300))
            explosion.removeFromParent()
        }
    }

    @MainActor
    private func fadeOutScorch(_ entity: Entity, duration: Double) async {
        let steps = 20
        let stepDuration = duration / Double(steps)

        entity.components.set(OpacityComponent(opacity: 1.0))
        for step in 0..<steps {
            guard entity.parent != nil else { return }
            let t = Float(1.0 - Double(step + 1) / Double(steps))
            entity.components.set(OpacityComponent(opacity: t))
            try? await Task.sleep(for: .seconds(stepDuration))
        }
    }

    // MARK: - Fireball Creation

    private func createHandFireball() async -> Entity {
        if let template = fireballTemplate {
            return template.clone(recursive: true)
        }
        return Entity()
    }

    private func createFlamethrower() async -> Entity {
        if let template = flamethrowerTemplate {
            return template.clone(recursive: true)
        }
        return Entity()
    }

    // MARK: - Fire Wall System

    /// Handle zombie pose gesture for fire wall creation/editing
    private func handleZombiePose(
        leftPosition: SIMD3<Float>,
        rightPosition: SIMD3<Float>,
        heightPercent: Float,
        deviceTransform: simd_float4x4?
    ) async {
        // Cancel any active fireball or flamethrower when in zombie pose
        if leftHandState.fireball != nil {
            leftHandState.despawnTask?.cancel()
            await extinguishLeft()
        }
        if rightHandState.fireball != nil {
            rightHandState.despawnTask?.cancel()
            await extinguishRight()
        }
        if leftHandState.isUsingFlamethrower {
            await stopFlamethrower(for: .left)
        }
        if rightHandState.isUsingFlamethrower {
            await stopFlamethrower(for: .right)
        }

        // Calculate wall parameters from hand positions
        let handSeparation = GestureDetection.calculateHandSeparation(left: leftPosition, right: rightPosition)
        let rotation = GestureDetection.calculateWallRotation(
            left: leftPosition,
            right: rightPosition,
            deviceTransform: deviceTransform
        )

        // Map hand separation to wall width (20cm-120cm hand spread → 20cm-4m wall)
        let normalizedSeparation = (handSeparation - 0.2) / 1.0
        let width = GestureConstants.fireWallMinWidth +
            normalizedSeparation * (GestureConstants.fireWallMaxWidth - GestureConstants.fireWallMinWidth)
        let clampedWidth = max(GestureConstants.fireWallMinWidth,
                               min(GestureConstants.fireWallMaxWidth, width))

        if !editingWallState.isActive {
            // Start new wall creation
            await startFireWallCreation(
                gazePosition: calculateGazeFloorPosition(deviceTransform: deviceTransform),
                width: clampedWidth,
                height: heightPercent,
                rotation: rotation,
                deviceTransform: deviceTransform
            )
        } else {
            // Update existing wall being edited
            await updateFireWall(
                width: clampedWidth,
                height: heightPercent,
                rotation: rotation,
                leftPosition: leftPosition,
                rightPosition: rightPosition
            )
        }
    }

    /// Start creating a new fire wall at the gaze position
    private func startFireWallCreation(
        gazePosition: SIMD3<Float>,
        width: Float,
        height: Float,
        rotation: Float,
        deviceTransform: simd_float4x4?
    ) async {
        // Check wall limit
        let confirmedCount = confirmedFireWalls.values.filter { $0.colorState == .redOrange }.count
        guard confirmedCount < GestureConstants.fireWallMaxCount else {
            print("Maximum fire walls reached (\(GestureConstants.fireWallMaxCount))")
            return
        }

        let wallID = UUID()
        let now = CACurrentMediaTime()

        // Create wall entity
        let wallEntity = createFireWall(
            width: width,
            height: max(0.01, height),
            colorState: .blue
        )

        // Use gaze position directly - floor Y is already estimated in calculateGazeFloorPosition
        let floorPosition = gazePosition

        wallEntity.position = floorPosition

        print("Fire wall spawn position: \(floorPosition)")

        // Rotate perpendicular to gaze, then apply user rotation
        if let deviceTransform = deviceTransform {
            let gazeDir = SIMD3<Float>(
                -deviceTransform.columns.2.x,
                0,
                -deviceTransform.columns.2.z
            )
            let baseRotation = atan2(gazeDir.x, gazeDir.z)
            wallEntity.orientation = simd_quatf(angle: baseRotation + rotation + Float.pi / 2, axis: [0, 1, 0])

            // Store base user rotation for later adjustments
            editingWallState.baseUserRotation = baseRotation
        }

        rootEntity.addChild(wallEntity)

        // Start audio (reuse fire crackle)
        var audioController: AudioPlaybackController?
        if let crackle = crackleSound {
            audioController = wallEntity.playAudio(crackle)
            audioController?.gain = -20
            audioController?.fade(to: -8, duration: 0.5)
        }

        // Create state
        let wallState = FireWallState(
            id: wallID,
            entity: wallEntity,
            position: floorPosition,
            rotation: rotation,
            width: width,
            height: height,
            colorState: .blue,
            creationTime: now,
            lastModifiedTime: now,
            audioController: audioController
        )

        // Update editing state
        editingWallState = FireWallEditingState(
            isActive: true,
            currentWall: wallID,
            isCreatingNew: true,
            initialWallWidth: width,
            initialWallRotation: rotation,
            baseUserRotation: editingWallState.baseUserRotation
        )

        // Store temporarily (not confirmed yet)
        confirmedFireWalls[wallID] = wallState

        print("Started fire wall creation: \(wallID)")
    }

    /// Update the fire wall being edited with new parameters
    private func updateFireWall(
        width: Float,
        height: Float,
        rotation: Float,
        leftPosition: SIMD3<Float>,
        rightPosition: SIMD3<Float>
    ) async {
        guard let wallID = editingWallState.currentWall,
              var wallState = confirmedFireWalls[wallID],
              let wallEntity = wallState.entity else {
            return
        }

        // Update dimensions
        wallState.width = width
        wallState.height = height
        wallState.rotation = rotation
        wallState.lastModifiedTime = CACurrentMediaTime()

        // Rebuild wall with new dimensions
        for child in wallEntity.children {
            child.removeFromParent()
        }

        let newWall = createFireWall(
            width: width,
            height: max(0.01, height),
            colorState: wallState.colorState
        )
        for child in newWall.children {
            wallEntity.addChild(child.clone(recursive: true))
        }

        // Update position based on hand midpoint movement
        let handMidpoint = (leftPosition + rightPosition) / 2
        if let lastLeft = editingWallState.lastLeftHandPosition,
           let lastRight = editingWallState.lastRightHandPosition {
            let lastMidpoint = (lastLeft + lastRight) / 2
            let delta = SIMD3<Float>(handMidpoint.x - lastMidpoint.x, 0, handMidpoint.z - lastMidpoint.z)
            wallState.position += delta
            wallEntity.position = wallState.position
        }

        // Update rotation
        let finalRotation = editingWallState.baseUserRotation + rotation + Float.pi / 2
        wallEntity.orientation = simd_quatf(angle: finalRotation, axis: [0, 1, 0])

        // Update editing state tracking
        editingWallState.lastLeftHandPosition = leftPosition
        editingWallState.lastRightHandPosition = rightPosition

        confirmedFireWalls[wallID] = wallState
    }

    /// Check for simultaneous fist clench to confirm/edit/despawn fire walls
    private func checkFireWallFistConfirmation(leftIsFist: Bool, rightIsFist: Bool) async {
        let now = CACurrentMediaTime()

        // Track fist timing for each hand
        if leftIsFist && leftFistTime == nil {
            leftFistTime = now
        } else if !leftIsFist {
            leftFistTime = nil
        }

        if rightIsFist && rightFistTime == nil {
            rightFistTime = now
        } else if !rightIsFist {
            rightFistTime = nil
        }

        // Check for simultaneous fists within window
        guard let leftTime = leftFistTime,
              let rightTime = rightFistTime else {
            return
        }

        let timeDiff = abs(leftTime - rightTime)
        if timeDiff < GestureConstants.fireWallFistConfirmWindow {
            if editingWallState.isActive {
                if let wallID = editingWallState.currentWall,
                   let wallState = confirmedFireWalls[wallID] {

                    // Check if at minimum height (despawn)
                    if wallState.isEmbersOnly && !editingWallState.isCreatingNew {
                        await despawnFireWall(wallID: wallID)
                    } else if wallState.isEmbersOnly && editingWallState.isCreatingNew {
                        // Cancel creation if confirming at ember-only height
                        await cancelFireWallEditing()
                    } else {
                        // Confirm the wall
                        await confirmFireWall(wallID: wallID)
                    }
                }
            } else if let selectedID = gazeSelectedWallID {
                // Enter edit mode for selected wall
                await enterFireWallEditMode(wallID: selectedID)
            }

            // Reset fist timing to prevent repeated triggers
            leftFistTime = nil
            rightFistTime = nil
        }
    }

    /// Confirm a fire wall (transition from blue to red/orange)
    private func confirmFireWall(wallID: UUID) async {
        guard var wallState = confirmedFireWalls[wallID],
              let wallEntity = wallState.entity else {
            return
        }

        print("Confirming fire wall: \(wallID)")

        // Transition to red/orange
        wallState.colorState = .redOrange
        wallState.isEditing = false

        // Rebuild with new color
        for child in wallEntity.children {
            child.removeFromParent()
        }
        let newWall = createFireWall(
            width: wallState.width,
            height: wallState.height,
            colorState: .redOrange
        )
        for child in newWall.children {
            wallEntity.addChild(child.clone(recursive: true))
        }

        // Boost audio for confirmed wall
        wallState.audioController?.fade(to: -3, duration: 0.3)

        confirmedFireWalls[wallID] = wallState

        // Exit editing mode
        editingWallState = FireWallEditingState()

        print("Fire wall confirmed! Total walls: \(confirmedFireWalls.count)")
    }

    /// Update gaze selection for existing fire walls
    private func updateGazeSelection(deviceTransform: simd_float4x4?) async {
        guard let deviceTransform = deviceTransform else { return }

        let gazeOrigin = GestureDetection.extractPosition(from: deviceTransform)
        let gazeDir = SIMD3<Float>(
            -deviceTransform.columns.2.x,
            -deviceTransform.columns.2.y,
            -deviceTransform.columns.2.z
        )

        var closestWall: UUID?
        var closestDistance: Float = Float.infinity

        // Find wall being looked at
        for (id, wallState) in confirmedFireWalls {
            // Only select confirmed (red/orange) walls, not walls currently being edited
            guard wallState.colorState == .redOrange else { continue }

            // Simple distance check from gaze ray to wall center
            let toWall = wallState.position - gazeOrigin
            let projection = simd_dot(toWall, gazeDir)

            if projection > 0 && projection < 10 {  // In front, within 10m
                let closestPoint = gazeOrigin + gazeDir * projection
                let distance = simd_distance(closestPoint, wallState.position)

                if distance < GestureConstants.fireWallGazeSelectionRadius && distance < closestDistance {
                    closestDistance = distance
                    closestWall = id
                }
            }
        }

        let now = CACurrentMediaTime()

        if let wallID = closestWall {
            if gazeSelectedWallID == wallID {
                // Continue dwelling
                if let startTime = gazeSelectionStartTime,
                   now - startTime > GestureConstants.fireWallGazeDwellDuration {
                    // Dwell complete - highlight wall green
                    await highlightWallForSelection(wallID: wallID)
                }
            } else {
                // New wall being looked at
                if let previousID = gazeSelectedWallID {
                    await unhighlightWall(wallID: previousID)
                }
                gazeSelectedWallID = wallID
                gazeSelectionStartTime = now
            }
        } else {
            // No wall being looked at
            if let previousID = gazeSelectedWallID {
                await unhighlightWall(wallID: previousID)
            }
            gazeSelectedWallID = nil
            gazeSelectionStartTime = nil
        }
    }

    /// Highlight a wall green to indicate it's selected
    private func highlightWallForSelection(wallID: UUID) async {
        guard var wallState = confirmedFireWalls[wallID],
              let wallEntity = wallState.entity,
              wallState.colorState != .green else {
            return
        }

        wallState.colorState = .green

        // Rebuild with green color
        for child in wallEntity.children {
            child.removeFromParent()
        }
        let newWall = createFireWall(
            width: wallState.width,
            height: wallState.height,
            colorState: .green
        )
        for child in newWall.children {
            wallEntity.addChild(child.clone(recursive: true))
        }

        confirmedFireWalls[wallID] = wallState
    }

    /// Unhighlight a wall (revert to red/orange)
    private func unhighlightWall(wallID: UUID) async {
        guard var wallState = confirmedFireWalls[wallID],
              let wallEntity = wallState.entity,
              wallState.colorState == .green else {
            return
        }

        wallState.colorState = .redOrange

        // Rebuild with red/orange color
        for child in wallEntity.children {
            child.removeFromParent()
        }
        let newWall = createFireWall(
            width: wallState.width,
            height: wallState.height,
            colorState: .redOrange
        )
        for child in newWall.children {
            wallEntity.addChild(child.clone(recursive: true))
        }

        confirmedFireWalls[wallID] = wallState
    }

    /// Enter edit mode for an existing fire wall
    private func enterFireWallEditMode(wallID: UUID) async {
        guard var wallState = confirmedFireWalls[wallID],
              let wallEntity = wallState.entity else {
            return
        }

        print("Entering edit mode for wall: \(wallID)")

        wallState.colorState = .blue
        wallState.isEditing = true

        // Rebuild with blue color
        for child in wallEntity.children {
            child.removeFromParent()
        }
        let newWall = createFireWall(
            width: wallState.width,
            height: wallState.height,
            colorState: .blue
        )
        for child in newWall.children {
            wallEntity.addChild(child.clone(recursive: true))
        }

        confirmedFireWalls[wallID] = wallState

        editingWallState = FireWallEditingState(
            isActive: true,
            currentWall: wallID,
            isCreatingNew: false,
            initialWallWidth: wallState.width,
            initialWallRotation: wallState.rotation
        )

        gazeSelectedWallID = nil
        gazeSelectionStartTime = nil
    }

    /// Despawn a fire wall with smoke animation
    private func despawnFireWall(wallID: UUID) async {
        guard let wallState = confirmedFireWalls[wallID],
              let wallEntity = wallState.entity else {
            return
        }

        print("Despawning fire wall: \(wallID)")

        // Fade out audio
        wallState.audioController?.fade(to: -80, duration: 0.5)

        // Create smoke effect
        let smoke = createFireWallDespawnSmoke(width: wallState.width, height: wallState.height)
        smoke.position = wallEntity.position
        smoke.orientation = wallEntity.orientation
        rootEntity.addChild(smoke)

        // Animate wall shrinking
        var transform = wallEntity.transform
        transform.scale = [0.1, 0.1, 0.1]
        wallEntity.move(to: transform, relativeTo: wallEntity.parent, duration: 0.4, timingFunction: .easeIn)

        try? await Task.sleep(for: .milliseconds(450))

        // Remove wall
        wallEntity.removeFromParent()
        wallState.audioController?.stop()
        confirmedFireWalls.removeValue(forKey: wallID)

        // Clean up smoke after particles fade
        Task {
            try? await Task.sleep(for: .milliseconds(2000))
            smoke.removeFromParent()
        }

        editingWallState = FireWallEditingState()

        print("Fire wall despawned. Remaining walls: \(confirmedFireWalls.count)")
    }

    /// Cancel fire wall editing (removes uncommitted new walls, reverts edits)
    private func cancelFireWallEditing() async {
        guard editingWallState.isActive,
              let wallID = editingWallState.currentWall else {
            editingWallState = FireWallEditingState()
            return
        }

        if editingWallState.isCreatingNew {
            // Cancel new wall - remove it
            if let wallState = confirmedFireWalls[wallID],
               let wallEntity = wallState.entity {
                wallState.audioController?.fade(to: -80, duration: 0.3)
                wallEntity.removeFromParent()
                wallState.audioController?.stop()
            }
            confirmedFireWalls.removeValue(forKey: wallID)
            print("Cancelled fire wall creation")
        } else {
            // Editing existing - revert to confirmed state
            if var wallState = confirmedFireWalls[wallID],
               let wallEntity = wallState.entity {
                wallState.colorState = .redOrange
                wallState.isEditing = false

                // Rebuild with red/orange
                for child in wallEntity.children {
                    child.removeFromParent()
                }
                let newWall = createFireWall(
                    width: wallState.width,
                    height: wallState.height,
                    colorState: .redOrange
                )
                for child in newWall.children {
                    wallEntity.addChild(child.clone(recursive: true))
                }

                confirmedFireWalls[wallID] = wallState
            }
            print("Cancelled fire wall editing")
        }

        editingWallState = FireWallEditingState()
    }

    /// Calculate floor position from gaze direction using actual scanned mesh
    /// Raycasts against the persistent mesh cache to find the real floor surface
    private func calculateGazeFloorPosition(deviceTransform: simd_float4x4?) -> SIMD3<Float> {
        guard let deviceTransform = deviceTransform else {
            return SIMD3<Float>(0, 0, -GestureConstants.fireWallSpawnDistance)
        }

        let headPos = GestureDetection.extractPosition(from: deviceTransform)
        let gazeDir = SIMD3<Float>(
            -deviceTransform.columns.2.x,
            -deviceTransform.columns.2.y,
            -deviceTransform.columns.2.z
        )

        // First, try raycasting against the actual scanned mesh
        if let meshHit = CollisionSystem.raycastBeam(
            origin: headPos,
            direction: gazeDir,
            maxDistance: 15.0,  // Max distance to look for floor
            meshCache: persistentMeshCache
        ) {
            // Check if the hit surface is roughly horizontal (floor-like)
            // A floor should have a normal pointing mostly upward (y > 0.7)
            if meshHit.normal.y > 0.5 {
                print("Fire wall spawn: using mesh floor at \(meshHit.position)")
                return meshHit.position
            }
        }

        // If gaze doesn't hit the mesh directly, try raycasting downward from gaze point
        // This handles cases where user is looking at a wall but wants wall on the floor below
        let horizontalGaze = simd_normalize(SIMD3<Float>(gazeDir.x, 0, gazeDir.z))
        let gazePointAhead = headPos + horizontalGaze * GestureConstants.fireWallSpawnDistance

        // Raycast straight down from that point to find the floor
        if let floorHit = CollisionSystem.raycastBeam(
            origin: gazePointAhead + SIMD3<Float>(0, 2, 0),  // Start above to ensure we hit floor below
            direction: SIMD3<Float>(0, -1, 0),  // Straight down
            maxDistance: 5.0,
            meshCache: persistentMeshCache
        ) {
            if floorHit.normal.y > 0.5 {
                print("Fire wall spawn: using downward raycast floor at \(floorHit.position)")
                return floorHit.position
            }
        }

        // Fallback: estimate floor level if no mesh is available yet
        // This happens when the room hasn't been fully scanned
        let estimatedFloorY = headPos.y - 1.5
        print("Fire wall spawn: no mesh found, using estimated floor at y=\(estimatedFloorY)")

        if gazeDir.y < -0.01 {  // Looking somewhat downward
            let t = (estimatedFloorY - headPos.y) / gazeDir.y
            if t > 0 && t < 20 {
                var hitPoint = headPos + gazeDir * t
                hitPoint.y = estimatedFloorY
                return hitPoint
            }
        }

        // Default: spawn at fixed distance in front on the estimated floor
        var spawnPos = headPos + horizontalGaze * GestureConstants.fireWallSpawnDistance
        spawnPos.y = estimatedFloorY
        return spawnPos
    }
}
