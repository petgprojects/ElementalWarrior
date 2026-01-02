//
//  HandTrackingManager.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI
import RealityKit
import ARKit
import QuartzCore

// MARK: - Projectile State

struct ProjectileState {
    let entity: Entity
    let direction: SIMD3<Float>
    let startPosition: SIMD3<Float>
    let startTime: TimeInterval
    let speed: Float
    var trailEntity: Entity?
}

// MARK: - Hand Tracking Manager

@MainActor
final class HandTrackingManager {
    let rootEntity = Entity()

    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    private let worldTracking = WorldTrackingProvider()
    private var sceneReconstruction: SceneReconstructionProvider?

    // Preloaded templates
    private var fireballTemplate: Entity?
    private var explosionTemplate: Entity?

    // Active projectiles in flight
    private var activeProjectiles: [UUID: ProjectileState] = [:]

    // MARK: - Timing Constants

    private let despawnDelayDuration: TimeInterval = 1.5       // Time before despawn after gesture ends
    private let punchVelocityThreshold: Float = 1.5            // m/s minimum for punch detection
    private let punchProximityThreshold: Float = 0.15          // meters - max distance from fireball center
    private let fistExtensionThreshold: Float = 0.035          // meters - finger extension for closed fist
    private let velocityHistoryDuration: TimeInterval = 0.1    // seconds of position history to keep
    private let projectileSpeed: Float = 12.0                  // m/s flight speed
    private let maxProjectileRange: Float = 20.0               // meters before auto-explode
    private let trackingLostGraceDuration: TimeInterval = 2.0  // seconds grace period for tracking loss

    // State tracking
    private struct HandState {
        var fireball: Entity?
        var isShowingFireball: Bool = false
        var isAnimating: Bool = false
        // Fields for throwing system
        var despawnTask: Task<Void, Never>?
        var lastPositions: [(position: SIMD3<Float>, timestamp: TimeInterval)] = []
        var isPendingDespawn: Bool = false
        var lastKnownPosition: SIMD3<Float>?
        var isTrackingLost: Bool = false  // Only true when ARKit tracking is actually lost
    }

    private var leftHandState = HandState()
    private var rightHandState = HandState()

    // MARK: - Initialization

    func startHandTracking() async {
        await loadFireballTemplate()
        await loadExplosionTemplate()

        do {
            var providers: [any DataProvider] = []

            // Hand tracking (required)
            if HandTrackingProvider.isSupported {
                providers.append(handTracking)
            }

            // World tracking for gaze direction
            if WorldTrackingProvider.isSupported {
                providers.append(worldTracking)
            }

            // Scene reconstruction for collision with real-world surfaces
            if SceneReconstructionProvider.isSupported {
                sceneReconstruction = SceneReconstructionProvider()
                providers.append(sceneReconstruction!)
            }

            if !providers.isEmpty {
                try await session.run(providers)

                // Setup collision detection
                await setupCollisionHandling()

                // Start parallel update loops
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

    // MARK: - Hand Update Loop

    private func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            let anchor = update.anchor
            let isLeft = anchor.chirality == .left

            guard anchor.isTracked else {
                // Hand lost tracking - start grace period instead of immediate extinguish
                if isLeft {
                    await handleTrackingLost(isLeft: true)
                } else {
                    await handleTrackingLost(isLeft: false)
                }
                continue
            }

            let skeleton = anchor.handSkeleton

            // Check if hand is open with palm facing up
            let shouldShowFireball = checkShouldShowFireball(anchor: anchor, skeleton: skeleton)

            // Check if hand is a fist (for punch detection)
            let isFist = checkHandIsFist(skeleton: skeleton)

            // Get palm position
            let palmPosition = getPalmPosition(anchor: anchor, skeleton: skeleton)

            if isLeft {
                // Handle tracking recovery if we had a grace period active
                await handleTrackingRecovered(isLeft: true, position: palmPosition)
                await updateLeftHand(shouldShow: shouldShowFireball, position: palmPosition, isFist: isFist, anchor: anchor)
            } else {
                await handleTrackingRecovered(isLeft: false, position: palmPosition)
                await updateRightHand(shouldShow: shouldShowFireball, position: palmPosition, isFist: isFist, anchor: anchor)
            }
        }
    }

    // MARK: - Left Hand Update

    private func updateLeftHand(shouldShow: Bool, position: SIMD3<Float>, isFist: Bool, anchor: HandAnchor) async {
        // Track position history for velocity calculation
        updatePositionHistory(for: &leftHandState, position: position)

        if shouldShow && !leftHandState.isShowingFireball && !leftHandState.isAnimating {
            // Cancel any pending despawn
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = nil
            leftHandState.isPendingDespawn = false

            // Spawn fireball
            leftHandState.isShowingFireball = true
            leftHandState.isAnimating = true

            let fireball = await createHandFireball()
            fireball.position = position
            fireball.scale = [0.01, 0.01, 0.01]
            rootEntity.addChild(fireball)
            leftHandState.fireball = fireball

            await animateSpawnLeft(entity: fireball)

        } else if shouldShow && leftHandState.isPendingDespawn {
            // Gesture resumed - cancel despawn
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = nil
            leftHandState.isPendingDespawn = false

        } else if !shouldShow && leftHandState.isShowingFireball && !leftHandState.isAnimating && !leftHandState.isPendingDespawn {
            // Start delayed despawn (fireball floats in place)
            leftHandState.isPendingDespawn = true
            leftHandState.despawnTask = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(for: .milliseconds(Int(self.despawnDelayDuration * 1000)))
                guard !Task.isCancelled else { return }
                if self.leftHandState.isPendingDespawn {
                    await self.extinguishLeft()
                }
            }

        } else if leftHandState.isShowingFireball, let fireball = leftHandState.fireball, !leftHandState.isAnimating {
            // Check for punch gesture while fireball exists (same hand or cross-hand)
            if isFist {
                let velocity = calculateVelocity(from: leftHandState.lastPositions)
                if simd_length(velocity) > punchVelocityThreshold {
                    let fireballPosition = fireball.position
                    let distance = simd_distance(position, fireballPosition)

                    if distance < punchProximityThreshold {
                        await launchFireball(from: .left)
                        return
                    }
                }
            }

            // Update fireball position only if gesture is active (not pending despawn)
            if shouldShow {
                fireball.position = position
            }
            // If pending despawn, fireball stays at last position (floats in place)
        }

        // Cross-hand punch: Check if this hand (left) can punch the RIGHT hand's fireball
        if isFist, let rightFireball = rightHandState.fireball,
           (rightHandState.isShowingFireball || rightHandState.isPendingDespawn) && !rightHandState.isAnimating {
            let velocity = calculateVelocity(from: leftHandState.lastPositions)
            if simd_length(velocity) > punchVelocityThreshold {
                let distance = simd_distance(position, rightFireball.position)
                if distance < punchProximityThreshold {
                    await launchFireball(from: .right)
                    return
                }
            }
        }
    }

    // MARK: - Right Hand Update

    private func updateRightHand(shouldShow: Bool, position: SIMD3<Float>, isFist: Bool, anchor: HandAnchor) async {
        // Track position history for velocity calculation
        updatePositionHistory(for: &rightHandState, position: position)

        if shouldShow && !rightHandState.isShowingFireball && !rightHandState.isAnimating {
            // Cancel any pending despawn
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = nil
            rightHandState.isPendingDespawn = false

            // Spawn fireball
            rightHandState.isShowingFireball = true
            rightHandState.isAnimating = true

            let fireball = await createHandFireball()
            fireball.position = position
            fireball.scale = [0.01, 0.01, 0.01]
            rootEntity.addChild(fireball)
            rightHandState.fireball = fireball

            await animateSpawnRight(entity: fireball)

        } else if shouldShow && rightHandState.isPendingDespawn {
            // Gesture resumed - cancel despawn
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = nil
            rightHandState.isPendingDespawn = false

        } else if !shouldShow && rightHandState.isShowingFireball && !rightHandState.isAnimating && !rightHandState.isPendingDespawn {
            // Start delayed despawn (fireball floats in place)
            rightHandState.isPendingDespawn = true
            rightHandState.despawnTask = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(for: .milliseconds(Int(self.despawnDelayDuration * 1000)))
                guard !Task.isCancelled else { return }
                if self.rightHandState.isPendingDespawn {
                    await self.extinguishRight()
                }
            }

        } else if rightHandState.isShowingFireball, let fireball = rightHandState.fireball, !rightHandState.isAnimating {
            // Check for punch gesture while fireball exists (same hand)
            if isFist {
                let velocity = calculateVelocity(from: rightHandState.lastPositions)
                if simd_length(velocity) > punchVelocityThreshold {
                    let fireballPosition = fireball.position
                    let distance = simd_distance(position, fireballPosition)

                    if distance < punchProximityThreshold {
                        await launchFireball(from: .right)
                        return
                    }
                }
            }

            // Update fireball position only if gesture is active (not pending despawn)
            if shouldShow {
                fireball.position = position
            }
            // If pending despawn, fireball stays at last position (floats in place)
        }

        // Cross-hand punch: Check if this hand (right) can punch the LEFT hand's fireball
        if isFist, let leftFireball = leftHandState.fireball,
           (leftHandState.isShowingFireball || leftHandState.isPendingDespawn) && !leftHandState.isAnimating {
            let velocity = calculateVelocity(from: rightHandState.lastPositions)
            if simd_length(velocity) > punchVelocityThreshold {
                let distance = simd_distance(position, leftFireball.position)
                if distance < punchProximityThreshold {
                    await launchFireball(from: .left)
                    return
                }
            }
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

        leftHandState.isAnimating = true
        let position = fireball.position

        // Spawn smoke puff at the same location
        let smokePuff = createSmokePuff()
        smokePuff.position = position
        smokePuff.scale = [0.01, 0.01, 0.01]
        rootEntity.addChild(smokePuff)

        // Animate transition: Fireball shrinks, Smoke grows
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

        // Stop emitter after short burst, let particles fade naturally
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
        if let fireball = leftHandState.fireball {
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
        if let fireball = rightHandState.fireball {
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
            guard leftHandState.fireball != nil else { return }
            leftHandState.isTrackingLost = true
            leftHandState.lastKnownPosition = leftHandState.fireball?.position
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(for: .milliseconds(Int(self.trackingLostGraceDuration * 1000)))
                guard !Task.isCancelled else { return }
                await self.forceExtinguishLeft()
            }
        } else {
            guard rightHandState.fireball != nil else { return }
            rightHandState.isTrackingLost = true
            rightHandState.lastKnownPosition = rightHandState.fireball?.position
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(for: .milliseconds(Int(self.trackingLostGraceDuration * 1000)))
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

    // MARK: - Velocity Tracking

    private func updatePositionHistory(for state: inout HandState, position: SIMD3<Float>) {
        let now = CACurrentMediaTime()
        state.lastPositions.append((position: position, timestamp: now))
        state.lastPositions.removeAll { now - $0.timestamp > velocityHistoryDuration }
    }

    private func calculateVelocity(from history: [(position: SIMD3<Float>, timestamp: TimeInterval)]) -> SIMD3<Float> {
        guard history.count >= 2 else { return .zero }
        let oldest = history.first!
        let newest = history.last!
        let timeDelta = Float(newest.timestamp - oldest.timestamp)
        guard timeDelta > 0.001 else { return .zero }
        return (newest.position - oldest.position) / timeDelta
    }

    // MARK: - Gesture Detection

    private func checkHandIsFist(skeleton: HandSkeleton?) -> Bool {
        guard let skeleton = skeleton else { return false }

        let middleTip = skeleton.joint(.middleFingerTip)
        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        let indexTip = skeleton.joint(.indexFingerTip)
        let indexKnuckle = skeleton.joint(.indexFingerKnuckle)
        let ringTip = skeleton.joint(.ringFingerTip)
        let ringKnuckle = skeleton.joint(.ringFingerKnuckle)

        guard middleTip.isTracked && middleKnuckle.isTracked &&
              indexTip.isTracked && indexKnuckle.isTracked &&
              ringTip.isTracked && ringKnuckle.isTracked else {
            return false
        }

        let middleExtension = simd_distance(
            extractPosition(from: middleTip.anchorFromJointTransform),
            extractPosition(from: middleKnuckle.anchorFromJointTransform)
        )
        let indexExtension = simd_distance(
            extractPosition(from: indexTip.anchorFromJointTransform),
            extractPosition(from: indexKnuckle.anchorFromJointTransform)
        )
        let ringExtension = simd_distance(
            extractPosition(from: ringTip.anchorFromJointTransform),
            extractPosition(from: ringKnuckle.anchorFromJointTransform)
        )

        return middleExtension < fistExtensionThreshold &&
               indexExtension < fistExtensionThreshold &&
               ringExtension < fistExtensionThreshold
    }

    private func checkShouldShowFireball(anchor: HandAnchor, skeleton: HandSkeleton?) -> Bool {
        guard let skeleton = skeleton else { return false }
        let isPalmUp = checkPalmFacingUp(anchor: anchor, skeleton: skeleton)
        let isHandOpen = checkHandIsOpen(skeleton: skeleton)
        return isPalmUp && isHandOpen
    }

    private func checkPalmFacingUp(anchor: HandAnchor, skeleton: HandSkeleton) -> Bool {
        let wrist = skeleton.joint(.wrist)
        guard wrist.isTracked else { return false }

        let worldWristTransform = anchor.originFromAnchorTransform * wrist.anchorFromJointTransform
        let isLeftHand = anchor.chirality == .left
        let yAxisMultiplier: Float = isLeftHand ? 1.0 : -1.0

        let palmNormal = SIMD3<Float>(
            yAxisMultiplier * worldWristTransform.columns.1.x,
            yAxisMultiplier * worldWristTransform.columns.1.y,
            yAxisMultiplier * worldWristTransform.columns.1.z
        )

        let worldUp = SIMD3<Float>(0, 1, 0)
        let dotProduct = simd_dot(simd_normalize(palmNormal), worldUp)
        return dotProduct > 0.4
    }

    private func checkHandIsOpen(skeleton: HandSkeleton) -> Bool {
        let middleTip = skeleton.joint(.middleFingerTip)
        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        let indexTip = skeleton.joint(.indexFingerTip)
        let indexKnuckle = skeleton.joint(.indexFingerKnuckle)

        guard middleTip.isTracked && middleKnuckle.isTracked &&
              indexTip.isTracked && indexKnuckle.isTracked else {
            return false
        }

        let middleTipPos = extractPosition(from: middleTip.anchorFromJointTransform)
        let middleKnucklePos = extractPosition(from: middleKnuckle.anchorFromJointTransform)
        let indexTipPos = extractPosition(from: indexTip.anchorFromJointTransform)
        let indexKnucklePos = extractPosition(from: indexKnuckle.anchorFromJointTransform)

        let middleExtension = simd_distance(middleTipPos, middleKnucklePos)
        let indexExtension = simd_distance(indexTipPos, indexKnucklePos)

        let extensionThreshold: Float = 0.05
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
            let velocity = calculateVelocity(from: state.lastPositions)
            if simd_length(velocity) > 0.1 {
                launchDirection = simd_normalize(velocity)
            } else {
                launchDirection = SIMD3<Float>(0, 0, -1)
            }
        }

        await launchWithDirection(fireball: fireball, direction: launchDirection, hand: chirality)
    }

    private func launchWithDirection(fireball: Entity, direction: SIMD3<Float>, hand: HandAnchor.Chirality) async {
        if hand == .left {
            leftHandState.fireball = nil
            leftHandState.isShowingFireball = false
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = nil
            leftHandState.isPendingDespawn = false
            leftHandState.lastPositions = []
        } else {
            rightHandState.fireball = nil
            rightHandState.isShowingFireball = false
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = nil
            rightHandState.isPendingDespawn = false
            rightHandState.lastPositions = []
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
            speed: projectileSpeed,
            trailEntity: trail
        )

        print("Launched fireball from \(hand) in direction \(direction)")
    }

    // MARK: - Projectile Update Loop

    private func updateProjectiles() async {
        while true {
            try? await Task.sleep(for: .milliseconds(16))

            let currentTime = CACurrentMediaTime()
            var projectilesToRemove: [UUID] = []

            for (id, projectile) in activeProjectiles {
                let elapsed = Float(currentTime - projectile.startTime)
                let travelDistance = elapsed * projectile.speed

                if travelDistance > maxProjectileRange {
                    await triggerExplosion(at: projectile.entity.position, projectileID: id)
                    projectilesToRemove.append(id)
                    continue
                }

                let newPosition = projectile.startPosition + projectile.direction * travelDistance
                projectile.entity.position = newPosition

                if checkProjectileCollision(projectilePosition: newPosition) {
                    await triggerExplosion(at: newPosition, projectileID: id)
                    projectilesToRemove.append(id)
                    continue
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
                let collisionEntity = await createCollisionMesh(from: anchor)
                if let existing = rootEntity.findEntity(named: "SceneMesh_\(anchor.id)") {
                    existing.removeFromParent()
                }
                collisionEntity.name = "SceneMesh_\(anchor.id)"
                rootEntity.addChild(collisionEntity)

            case .removed:
                if let existing = rootEntity.findEntity(named: "SceneMesh_\(anchor.id)") {
                    existing.removeFromParent()
                }

            @unknown default:
                break
            }
        }
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

    // MARK: - Collision Handling

    private func setupCollisionHandling() async {
        // Collision is handled in updateProjectiles via distance checks
    }

    private func checkProjectileCollision(projectilePosition: SIMD3<Float>) -> Bool {
        for child in rootEntity.children {
            guard child.name.hasPrefix("SceneMesh_") else { continue }

            if child.components[CollisionComponent.self] != nil {
                let meshPosition = child.position(relativeTo: nil)
                let distance = simd_distance(projectilePosition, meshPosition)
                if distance < 0.5 {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Explosion System

    private func triggerExplosion(at position: SIMD3<Float>, projectileID: UUID) async {
        if let projectile = activeProjectiles[projectileID] {
            projectile.entity.removeFromParent()
            activeProjectiles.removeValue(forKey: projectileID)
        }

        let explosion: Entity
        if let template = explosionTemplate {
            explosion = template.clone(recursive: true)
        } else {
            explosion = createExplosionEffect()
        }

        explosion.position = position
        rootEntity.addChild(explosion)

        print("Explosion at \(position)")

        Task {
            if let lightEntity = explosion.children.first(where: {
                $0.components[PointLightComponent.self] != nil
            }) {
                for i in 0..<10 {
                    try? await Task.sleep(for: .milliseconds(50))
                    if var light = lightEntity.components[PointLightComponent.self] {
                        light.intensity = 10000 * Float(10 - i) / 10
                        lightEntity.components.set(light)
                    }
                }
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(1700))
            explosion.removeFromParent()
        }
    }

    // MARK: - Smoke Puff

    private func createSmokePuff() -> Entity {
        let puff = Entity()
        puff.name = "SmokePuff"
        puff.components.set(createSmokePuffEmitter())
        return puff
    }

    private func createSmokePuffEmitter() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [0.025, 0.025, 0.025]

        emitter.mainEmitter.birthRate = 2000
        emitter.mainEmitter.lifeSpan = 2.0
        emitter.mainEmitter.lifeSpanVariation = 0.5

        emitter.speed = 0.05
        emitter.speedVariation = 0.04
        emitter.mainEmitter.acceleration = [0, 0.05, 0]

        emitter.mainEmitter.noiseStrength = 0.1
        emitter.mainEmitter.noiseAnimationSpeed = 0.5
        emitter.mainEmitter.noiseScale = 1.0

        emitter.mainEmitter.size = 0.01
        emitter.mainEmitter.sizeVariation = 0.005
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 2.0

        emitter.mainEmitter.color = .evolving(
            start: .single(.init(red: 0.4, green: 0.35, blue: 0.3, alpha: 0.5)),
            end: .single(.init(red: 0.25, green: 0.22, blue: 0.18, alpha: 0.0))
        )
        emitter.mainEmitter.blendMode = .alpha

        return emitter
    }

    // MARK: - Fireball Creation

    private func createHandFireball() async -> Entity {
        if let template = fireballTemplate {
            return template.clone(recursive: true)
        }
        return Entity()
    }
}
