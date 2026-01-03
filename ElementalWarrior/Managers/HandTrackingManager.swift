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

    // Audio Resources
    private var crackleSound: AudioFileResource?
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
    }

    private func loadAudioResources() async {
        crackleSound = await loadAudio(named: "fire_crackle", ext: "wav", shouldLoop: true)
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

            if state.flamethrowerAudio == nil, let crackle = crackleSound {
                let controller = stream.playAudio(crackle)
                controller.gain = -6
                controller.fade(to: -2, duration: 0.2)
                state.flamethrowerAudio = controller
            }

            state.flamethrower = stream
        }

        guard let flamethrower = state.flamethrower else { return }

        // Slight upward bias to keep the jet aligned with palm instead of dipping
        let direction = simd_normalize(palmNormal + SIMD3<Float>(0, 0.08, 0))
        let origin = position + direction * 0.02  // bring emission closer to palm

        let maxRange = GestureConstants.flamethrowerRange
        let hit = CollisionSystem.raycastBeam(
            origin: origin,
            direction: direction,
            maxDistance: maxRange,
            meshCache: persistentMeshCache
        )

        var lengthFactor: Float = 1.0

        if let hit = hit {
            let distance = min(simd_distance(origin, hit.position), maxRange)
            lengthFactor = max(0.25, distance / maxRange)

            let now = CACurrentMediaTime()
            if now - state.lastFlamethrowerScorchTime > GestureConstants.flamethrowerScorchCooldown {
                state.lastFlamethrowerScorchTime = now
                await spawnFlamethrowerScorch(at: hit.position, normal: hit.normal)
            }
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

        if let audio = state.flamethrowerAudio {
            audio.fade(to: -80, duration: 0.2)
            Task {
                try? await Task.sleep(for: .milliseconds(240))
                audio.stop()
            }
        }

        state.flamethrower?.removeFromParent()
        state.flamethrower = nil
        state.flamethrowerAudio = nil
        state.isUsingFlamethrower = false
        state.lastFlamethrowerScorchTime = 0

        if hand == .left {
            leftHandState = state
        } else {
            rightHandState = state
        }
    }

    @MainActor
    private func spawnFlamethrowerScorch(at position: SIMD3<Float>, normal: SIMD3<Float>) async {
        let scorchScale = GestureConstants.flamethrowerScorchScale * Float.random(in: 0.9...1.05)
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
            if leftHandState.isUsingFlamethrower {
                await stopFlamethrower(for: .left)
            }
            guard leftHandState.fireball != nil else { return }
            leftHandState.isTrackingLost = true
            leftHandState.lastKnownPosition = leftHandState.fireball?.position
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(for: .milliseconds(Int(GestureConstants.trackingLostGraceDuration * 1000)))
                guard !Task.isCancelled else { return }
                await self.forceExtinguishLeft()
            }
        } else {
            if rightHandState.isUsingFlamethrower {
                await stopFlamethrower(for: .right)
            }
            guard rightHandState.fireball != nil else { return }
            rightHandState.isTrackingLost = true
            rightHandState.lastKnownPosition = rightHandState.fireball?.position
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(for: .milliseconds(Int(GestureConstants.trackingLostGraceDuration * 1000)))
                guard !Task.isCancelled else { return }
                await self.forceExtinguishRight()
            }
        }
    }

    private func handleTrackingRecovered(isLeft: Bool, position: SIMD3<Float>) async {
        if isLeft {
            guard leftHandState.isTrackingLost else { return }
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = nil
            leftHandState.isTrackingLost = false
            if let fireball = leftHandState.fireball {
                var transform = fireball.transform
                transform.translation = position
                fireball.move(to: transform, relativeTo: fireball.parent, duration: 0.2, timingFunction: .easeOut)
            }
            leftHandState.lastKnownPosition = nil
        } else {
            guard rightHandState.isTrackingLost else { return }
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = nil
            rightHandState.isTrackingLost = false
            if let fireball = rightHandState.fireball {
                var transform = fireball.transform
                transform.translation = position
                fireball.move(to: transform, relativeTo: fireball.parent, duration: 0.2, timingFunction: .easeOut)
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
}
