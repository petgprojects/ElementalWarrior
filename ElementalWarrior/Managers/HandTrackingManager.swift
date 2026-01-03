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
import UIKit

// MARK: - Debug Hand State

enum HandGestureState: String {
    case none = "NONE"
    case fist = "FIST"
    case summon = "SUMMON"
    case holdingFireball = "HOLDING"
    case collision = "COLLISION"
}

// MARK: - Projectile State

struct ProjectileState {
    let entity: Entity
    let direction: SIMD3<Float>
    let startPosition: SIMD3<Float>
    let startTime: TimeInterval
    let speed: Float
    var trailEntity: Entity?
    var previousPosition: SIMD3<Float>  // Track previous position for raycast collision
}

// MARK: - Cached Mesh Geometry

/// Stores extracted mesh geometry that persists even when ARKit removes the anchor
struct CachedMeshGeometry {
    let id: UUID
    let transform: simd_float4x4
    let vertices: [SIMD3<Float>]
    let triangleIndices: [(UInt32, UInt32, UInt32)]  // Pre-extracted triangle indices
    var lastUpdated: Date
    
    /// Create cached geometry from a MeshAnchor
    init(from anchor: MeshAnchor) {
        self.id = anchor.id
        self.transform = anchor.originFromAnchorTransform
        self.lastUpdated = Date()
        
        let geometry = anchor.geometry
        let vertexBuffer = geometry.vertices
        let faceBuffer = geometry.faces
        
        // Extract vertices
        var extractedVertices: [SIMD3<Float>] = []
        let vertexPointer = vertexBuffer.buffer.contents()
        let vertexStride = vertexBuffer.stride
        
        for i in 0..<vertexBuffer.count {
            let vertexPtr = vertexPointer.advanced(by: i * vertexStride)
                .bindMemory(to: SIMD3<Float>.self, capacity: 1)
            extractedVertices.append(vertexPtr.pointee)
        }
        self.vertices = extractedVertices
        
        // Extract triangle indices
        var extractedTriangles: [(UInt32, UInt32, UInt32)] = []
        let indexPointer = faceBuffer.buffer.contents()
        let bytesPerIndex = faceBuffer.bytesPerIndex
        let faceCount = faceBuffer.count
        
        for faceIndex in 0..<faceCount {
            let i0: UInt32
            let i1: UInt32
            let i2: UInt32
            
            if bytesPerIndex == 2 {
                let indexPtr = indexPointer.advanced(by: faceIndex * 3 * bytesPerIndex)
                    .bindMemory(to: UInt16.self, capacity: 3)
                i0 = UInt32(indexPtr[0])
                i1 = UInt32(indexPtr[1])
                i2 = UInt32(indexPtr[2])
            } else {
                let indexPtr = indexPointer.advanced(by: faceIndex * 3 * bytesPerIndex)
                    .bindMemory(to: UInt32.self, capacity: 3)
                i0 = indexPtr[0]
                i1 = indexPtr[1]
                i2 = indexPtr[2]
            }
            extractedTriangles.append((i0, i1, i2))
        }
        self.triangleIndices = extractedTriangles
    }
}

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

    // MARK: - Timing Constants

    private let despawnDelayDuration: TimeInterval = 1.5       // Time before despawn after gesture ends
    private let punchVelocityThreshold: Float = 0.3            // m/s minimum for punch detection (lowered for easier triggering)
    private let punchProximityThreshold: Float = 0.20          // meters - max distance from fireball center (20cm for balanced hit detection)
    private let fistExtensionThreshold: Float = 0.045          // meters - finger extension for closed fist (relaxed)
    private let velocityHistoryDuration: TimeInterval = 0.15   // seconds of position history to keep
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
        
        // Audio controller for looping sounds
        var crackleController: AudioPlaybackController?
    }

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
        await loadAudioResources()

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

    private func loadAudioResources() async {
        // Load audio resources
        // We try to load from bundle first, then fallback to data assets
        
        // Crackle - loops
        crackleSound = await loadAudio(named: "fire_crackle", ext: "wav", shouldLoop: true)
        
        // Woosh - one shot
        wooshSound = await loadAudio(named: "fire_woosh_clipped", ext: "wav", shouldLoop: false)
        
        // Explosion - one shot
        explosionSound = await loadAudio(named: "explosion_clipped", ext: "wav", shouldLoop: false)
    }
    
    private func loadAudio(named name: String, ext: String, shouldLoop: Bool) async -> AudioFileResource? {
        do {
            // 1. Try loading directly from bundle (if file exists)
            let config = AudioFileResource.Configuration(shouldLoop: shouldLoop)
            if let resource = try? await AudioFileResource.load(named: "\(name).\(ext)", configuration: config) {
                return resource
            }
            
            // 2. Fallback: Try loading from Asset Catalog (NSDataAsset)
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

            // Check if hand is a fist (for punch detection) - returns debug info about WHY
            let (isFist, fistDebugInfo) = checkHandIsFist(skeleton: skeleton, isLeft: isLeft)
            
            // Get fist position early for collision checking
            let earlyFistPosition = getFistPosition(anchor: anchor, skeleton: skeleton)
            
            // Calculate distances to fireballs for collision state detection
            let distToLeftFireball: Float? = leftHandState.fireball.map { simd_distance(earlyFistPosition, $0.position) }
            let distToRightFireball: Float? = rightHandState.fireball.map { simd_distance(earlyFistPosition, $0.position) }
            
            // Check if this hand's fist is colliding with any fireball
            let isCollidingWithFireball = isFist && (
                (distToLeftFireball != nil && distToLeftFireball! < punchProximityThreshold) ||
                (distToRightFireball != nil && distToRightFireball! < punchProximityThreshold)
            )
            
            // Build combined debug info: distance + fist detection details
            let distInfo = distToLeftFireball.map { "toL:\(String(format: "%.2f", $0))m" } ?? ""
            let distInfo2 = distToRightFireball.map { "toR:\(String(format: "%.2f", $0))m" } ?? ""
            let distString = [distInfo, distInfo2].filter { !$0.isEmpty }.joined(separator: " ")
            let hasSkeleton = skeleton != nil
            
            // Update debug gesture state for UI
            if isLeft {
                if isCollidingWithFireball {
                    leftHandGestureState = .collision
                } else if isFist {
                    leftHandGestureState = .fist
                } else if shouldShowFireball {
                    leftHandGestureState = leftHandState.isShowingFireball ? .holdingFireball : .summon
                } else {
                    leftHandGestureState = .none
                }
                // Combined debug info: skeleton status + distance + fist info
                leftDebugInfo = "skel:\(hasSkeleton ? "✓" : "✗") \(distString)\n\(fistDebugInfo)"
            } else {
                if isCollidingWithFireball {
                    rightHandGestureState = .collision
                } else if isFist {
                    rightHandGestureState = .fist
                } else if shouldShowFireball {
                    rightHandGestureState = rightHandState.isShowingFireball ? .holdingFireball : .summon
                } else {
                    rightHandGestureState = .none
                }
                // Combined debug info: skeleton status + distance + fist info
                rightDebugInfo = "skel:\(hasSkeleton ? "✓" : "✗") \(distString)\n\(fistDebugInfo)"
            }
            
            // Debug: Log when we have a fireball and are checking for punches
            let hasLeftFireball = leftHandState.fireball != nil
            let hasRightFireball = rightHandState.fireball != nil
            if (hasLeftFireball || hasRightFireball) && Int.random(in: 0..<60) == 0 {
                print("[HAND UPDATE] \(isLeft ? "LEFT" : "RIGHT") - isFist=\(isFist), hasLeftFB=\(hasLeftFireball), hasRightFB=\(hasRightFireball), leftPending=\(leftHandState.isPendingDespawn), rightPending=\(rightHandState.isPendingDespawn)")
            }

            // Get palm position (for fireball placement) and fist position (for punch detection)
            let palmPosition = getPalmPosition(anchor: anchor, skeleton: skeleton)
            let fistPosition = getFistPosition(anchor: anchor, skeleton: skeleton)

            if isLeft {
                // Handle tracking recovery if we had a grace period active
                await handleTrackingRecovered(isLeft: true, position: palmPosition)
                await updateLeftHand(shouldShow: shouldShowFireball, position: palmPosition, fistPosition: fistPosition, isFist: isFist, anchor: anchor)
            } else {
                await handleTrackingRecovered(isLeft: false, position: palmPosition)
                await updateRightHand(shouldShow: shouldShowFireball, position: palmPosition, fistPosition: fistPosition, isFist: isFist, anchor: anchor)
            }
        }
    }

    // MARK: - Left Hand Update

    private func updateLeftHand(shouldShow: Bool, position: SIMD3<Float>, fistPosition: SIMD3<Float>, isFist: Bool, anchor: HandAnchor) async {
        // Track position history for velocity calculation (use fist position for more accurate punch velocity)
        updatePositionHistory(for: &leftHandState, position: fistPosition)

        // PRIORITY: Check for punch gesture FIRST - this should happen before any state transitions
        // Same-hand punch: Check if this left fist can punch the left hand's own fireball
        if isFist, let fireball = leftHandState.fireball,
           (leftHandState.isShowingFireball || leftHandState.isPendingDespawn) && !leftHandState.isAnimating {
            let velocity = calculateVelocity(from: leftHandState.lastPositions)
            let speed = simd_length(velocity)
            let distance = simd_distance(fistPosition, fireball.position)
            
            print("[LEFT SAME-HAND] isFist=\(isFist), speed=\(speed), distance=\(distance), threshold=\(punchProximityThreshold)")
            
            if speed > punchVelocityThreshold && distance < punchProximityThreshold {
                print("[LEFT SAME-HAND] LAUNCHING FIREBALL!")
                await launchFireball(from: .left)
                return
            }
        }
        
        // Cross-hand punch: Check if this left fist can punch the RIGHT hand's fireball
        if isFist, let rightFireball = rightHandState.fireball,
           (rightHandState.isShowingFireball || rightHandState.isPendingDespawn) && !rightHandState.isAnimating {
            let velocity = calculateVelocity(from: leftHandState.lastPositions)
            let speed = simd_length(velocity)
            let distance = simd_distance(fistPosition, rightFireball.position)
            
            print("[LEFT CROSS-HAND] isFist=\(isFist), speed=\(speed), distance=\(distance), threshold=\(punchProximityThreshold)")
            
            if speed > punchVelocityThreshold && distance < punchProximityThreshold {
                print("[LEFT CROSS-HAND] LAUNCHING RIGHT FIREBALL!")
                await launchFireball(from: .right)
                return
            }
        }

        // State transitions for spawning/despawning
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
            
            // Play crackle sound
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
            // Update fireball position only if gesture is active (not pending despawn)
            if shouldShow {
                fireball.position = position
            }
            // If pending despawn, fireball stays at last position (floats in place)
        }
    }

    // MARK: - Right Hand Update

    private func updateRightHand(shouldShow: Bool, position: SIMD3<Float>, fistPosition: SIMD3<Float>, isFist: Bool, anchor: HandAnchor) async {
        // Track position history for velocity calculation (use fist position for more accurate punch velocity)
        updatePositionHistory(for: &rightHandState, position: fistPosition)

        // PRIORITY: Check for punch gesture FIRST - this should happen before any state transitions
        // Same-hand punch: Check if this right fist can punch the right hand's own fireball
        if isFist, let fireball = rightHandState.fireball,
           (rightHandState.isShowingFireball || rightHandState.isPendingDespawn) && !rightHandState.isAnimating {
            let velocity = calculateVelocity(from: rightHandState.lastPositions)
            let speed = simd_length(velocity)
            let distance = simd_distance(fistPosition, fireball.position)
            
            print("[RIGHT SAME-HAND] isFist=\(isFist), speed=\(speed), distance=\(distance), threshold=\(punchProximityThreshold)")
            
            if speed > punchVelocityThreshold && distance < punchProximityThreshold {
                print("[RIGHT SAME-HAND] LAUNCHING FIREBALL!")
                await launchFireball(from: .right)
                return
            }
        }
        
        // Cross-hand punch: Check if this right fist can punch the LEFT hand's fireball
        if isFist, let leftFireball = leftHandState.fireball,
           (leftHandState.isShowingFireball || leftHandState.isPendingDespawn) && !leftHandState.isAnimating {
            let velocity = calculateVelocity(from: rightHandState.lastPositions)
            let speed = simd_length(velocity)
            let distance = simd_distance(fistPosition, leftFireball.position)
            
            print("[RIGHT CROSS-HAND] isFist=\(isFist), speed=\(speed), distance=\(distance), threshold=\(punchProximityThreshold)")
            
            if speed > punchVelocityThreshold && distance < punchProximityThreshold {
                print("[RIGHT CROSS-HAND] LAUNCHING LEFT FIREBALL!")
                await launchFireball(from: .left)
                return
            }
        }

        // State transitions for spawning/despawning
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
            
            // Play crackle sound
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
            // Update fireball position only if gesture is active (not pending despawn)
            if shouldShow {
                fireball.position = position
            }
            // If pending despawn, fireball stays at last position (floats in place)
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
        
        // Fade out crackle
        leftHandState.crackleController?.fade(to: -80, duration: 0.25)

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
        
        // Ensure audio is stopped
        leftHandState.crackleController?.stop()
        leftHandState.crackleController = nil

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
        
        // Fade out crackle
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
        
        // Ensure audio is stopped
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

    /// Multi-method fist detection that works even when ARKit estimates occluded joints
    /// Uses multiple signals since ARKit predicts joint positions even when occluded
    private func checkHandIsFist(skeleton: HandSkeleton?, isLeft: Bool) -> (isFist: Bool, debugInfo: String) {
        guard let skeleton = skeleton else { 
            return (false, "no skeleton")
        }

        var debugParts: [String] = []
        var fistSignals = 0
        let requiredSignals = 3  // Need at least 3 signals to consider it a fist
        
        // METHOD 1: Finger alignment (relaxed threshold)
        // When ARKit estimates positions, alignment stays high (~0.7-0.9)
        // But a real curl might get down to 0.5-0.7
        let alignmentResult = checkFingerAlignment(skeleton: skeleton)
        if alignmentResult.alignment < 0.75 {  // VERY relaxed from 0.3
            fistSignals += 1
            debugParts.append("align:\(String(format: "%.2f", alignmentResult.alignment))✓")
        } else {
            debugParts.append("align:\(String(format: "%.2f", alignmentResult.alignment))")
        }
        
        // METHOD 2: Thumb position - in a fist, thumb crosses in front of fingers
        // Check if thumb tip is close to index finger side
        let thumbResult = checkThumbCurl(skeleton: skeleton)
        if thumbResult.isCurled {
            fistSignals += 1
            debugParts.append("thumb:curled✓")
        } else {
            debugParts.append("thumb:\(String(format: "%.2f", thumbResult.distance))")
        }
        
        // METHOD 3: Hand compactness - fist is more compact than open hand
        // Measure distance from wrist to fingertips vs wrist to knuckles
        let compactResult = checkHandCompactness(skeleton: skeleton)
        if compactResult.isCompact {
            fistSignals += 1
            debugParts.append("compact:\(String(format: "%.2f", compactResult.ratio))✓")
        } else {
            debugParts.append("compact:\(String(format: "%.2f", compactResult.ratio))")
        }
        
        // METHOD 4: Fingertip clustering - in a fist, all fingertips are close together
        let clusterResult = checkFingertipClustering(skeleton: skeleton)
        if clusterResult.isClustered {
            fistSignals += 1
            debugParts.append("cluster:\(String(format: "%.2f", clusterResult.spread))✓")
        } else {
            debugParts.append("cluster:\(String(format: "%.2f", clusterResult.spread))")
        }
        
        let isFist = fistSignals >= requiredSignals
        let debugInfo = "\(fistSignals)/4: " + debugParts.joined(separator: " | ")
        
        let shouldLog = Int.random(in: 0..<30) == 0
        if shouldLog || isFist {
            print("[FIST \(isLeft ? "L" : "R")] signals=\(fistSignals)/\(requiredSignals) -> \(isFist ? "FIST" : "open") | \(debugInfo)")
        }
        
        return (isFist, debugInfo)
    }
    
    /// Check finger alignment using the standard approach
    /// Note: Don't check isTracked - ARKit provides estimated positions even for occluded joints
    private func checkFingerAlignment(skeleton: HandSkeleton) -> (alignment: Float, detected: Bool) {
        let middleMetacarpal = skeleton.joint(.middleFingerMetacarpal)
        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        let middleIntermediateBase = skeleton.joint(.middleFingerIntermediateBase)
        
        let metacarpalPos = extractPosition(from: middleMetacarpal.anchorFromJointTransform)
        let knucklePos = extractPosition(from: middleKnuckle.anchorFromJointTransform)
        let intermediateBasePos = extractPosition(from: middleIntermediateBase.anchorFromJointTransform)
        
        let palmDirection = simd_normalize(knucklePos - metacarpalPos)
        let fingerDirection = simd_normalize(intermediateBasePos - knucklePos)
        let alignment = simd_dot(palmDirection, fingerDirection)
        
        return (alignment, alignment < 0.75)
    }
    
    /// Check if thumb is curled toward palm (for fist detection)
    /// In a regular fist, thumb wraps across fingers toward palm center
    /// Note: Don't check isTracked - ARKit provides estimated positions even for occluded joints
    private func checkThumbCurl(skeleton: HandSkeleton) -> (isCurled: Bool, distance: Float) {
        let thumbTip = skeleton.joint(.thumbTip)
        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        let middleIntermediateBase = skeleton.joint(.middleFingerIntermediateBase)
        let wrist = skeleton.joint(.wrist)
        
        let thumbTipPos = extractPosition(from: thumbTip.anchorFromJointTransform)
        let middleKnucklePos = extractPosition(from: middleKnuckle.anchorFromJointTransform)
        let middleIntermediatePos = extractPosition(from: middleIntermediateBase.anchorFromJointTransform)
        let wristPos = extractPosition(from: wrist.anchorFromJointTransform)
        
        // Method: Check if thumb tip is close to the curled finger area (middle finger intermediate)
        // In a fist, thumb wraps over curled fingers, bringing tip close to middle of hand
        let distToMiddleIntermediate = simd_distance(thumbTipPos, middleIntermediatePos)
        
        // Also check thumb curl by comparing thumb tip distance to wrist vs thumb knuckle to wrist
        // When thumb is curled, the tip gets closer to wrist relative to the knuckle
        let thumbTipToWrist = simd_distance(thumbTipPos, wristPos)
        let middleKnuckleToWrist = simd_distance(middleKnucklePos, wristPos)
        
        // Thumb is curled if:
        // 1. Thumb tip is close to middle finger area (within 7cm), OR
        // 2. Thumb tip is closer to wrist than the middle knuckle (thumb folded in)
        let isCloseToFingers = distToMiddleIntermediate < 0.07
        let isFoldedIn = thumbTipToWrist < middleKnuckleToWrist
        let isCurled = isCloseToFingers || isFoldedIn
        
        // Return the distance to middle finger area for debug display
        return (isCurled, distToMiddleIntermediate)
    }
    
    /// Check if hand is compact (fingertips close to wrist compared to open hand)
    /// Note: Don't check isTracked - ARKit provides estimated positions even for occluded joints
    private func checkHandCompactness(skeleton: HandSkeleton) -> (isCompact: Bool, ratio: Float) {
        let wrist = skeleton.joint(.wrist)
        let middleTip = skeleton.joint(.middleFingerTip)
        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        
        let wristPos = extractPosition(from: wrist.anchorFromJointTransform)
        let tipPos = extractPosition(from: middleTip.anchorFromJointTransform)
        let knucklePos = extractPosition(from: middleKnuckle.anchorFromJointTransform)
        
        let tipToWrist = simd_distance(tipPos, wristPos)
        let knuckleToWrist = simd_distance(knucklePos, wristPos)
        
        // Prevent division by zero
        guard knuckleToWrist > 0.001 else { return (false, 999) }
        
        // In an open hand, tip is much further from wrist than knuckle
        // In a fist, tip is closer to wrist (curled back)
        // Ratio: tipDist / knuckleDist - lower means more curled
        let ratio = tipToWrist / knuckleToWrist
        
        // Open hand: ratio ~1.5-2.0 (tip is further)
        // Fist: ratio ~0.8-1.2 (tip is close to or behind knuckle)
        return (ratio < 1.4, ratio)
    }
    
    /// Check if fingertips are clustered together (fist) vs spread out (open)
    /// Note: Don't check isTracked - ARKit provides estimated positions even for occluded joints
    private func checkFingertipClustering(skeleton: HandSkeleton) -> (isClustered: Bool, spread: Float) {
        let indexTip = skeleton.joint(.indexFingerTip)
        let middleTip = skeleton.joint(.middleFingerTip)
        let ringTip = skeleton.joint(.ringFingerTip)
        let littleTip = skeleton.joint(.littleFingerTip)
        
        let indexPos = extractPosition(from: indexTip.anchorFromJointTransform)
        let middlePos = extractPosition(from: middleTip.anchorFromJointTransform)
        let ringPos = extractPosition(from: ringTip.anchorFromJointTransform)
        let littlePos = extractPosition(from: littleTip.anchorFromJointTransform)
        
        // Calculate spread - max distance between any two fingertips
        let d1 = simd_distance(indexPos, littlePos)
        let d2 = simd_distance(indexPos, ringPos)
        let d3 = simd_distance(middlePos, littlePos)
        let maxSpread = max(d1, max(d2, d3))
        
        // Open hand: spread ~10-15cm
        // Fist: spread ~3-6cm (fingers clustered)
        return (maxSpread < 0.08, maxSpread)
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

    // Get fist position for punch detection (without palm offset)
    private func getFistPosition(anchor: HandAnchor, skeleton: HandSkeleton?) -> SIMD3<Float> {
        guard let skeleton = skeleton else {
            return extractPosition(from: anchor.originFromAnchorTransform)
        }

        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        guard middleKnuckle.isTracked else {
            return extractPosition(from: anchor.originFromAnchorTransform)
        }

        let jointTransform = anchor.originFromAnchorTransform * middleKnuckle.anchorFromJointTransform
        return extractPosition(from: jointTransform)
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
            // Fade out crackle quickly
            leftHandState.crackleController?.fade(to: -80, duration: 0.1)
            leftHandState.crackleController = nil
            
            leftHandState.fireball = nil
            leftHandState.isShowingFireball = false
            leftHandState.despawnTask?.cancel()
            leftHandState.despawnTask = nil
            leftHandState.isPendingDespawn = false
            leftHandState.lastPositions = []
        } else {
            // Fade out crackle quickly
            rightHandState.crackleController?.fade(to: -80, duration: 0.1)
            rightHandState.crackleController = nil
            
            rightHandState.fireball = nil
            rightHandState.isShowingFireball = false
            rightHandState.despawnTask?.cancel()
            rightHandState.despawnTask = nil
            rightHandState.isPendingDespawn = false
            rightHandState.lastPositions = []
        }
        
        // Play woosh sound
        if let woosh = wooshSound {
            fireball.playAudio(woosh)
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
            trailEntity: trail,
            previousPosition: startPos  // Initialize previous position for collision detection
        )

        print("Launched fireball from \(hand) in direction \(direction)")
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

                if travelDistance > maxProjectileRange {
                    await triggerExplosion(at: projectile.entity.position, projectileID: id)
                    projectilesToRemove.append(id)
                    continue
                }

                let newPosition = projectile.startPosition + projectile.direction * travelDistance
                
                // Check for collision with real-world surfaces using raycast
                if let hit = checkProjectileCollision(
                    projectilePosition: newPosition,
                    direction: projectile.direction,
                    previousPosition: projectile.previousPosition
                ) {
                    // Explode at the exact hit point
                    await triggerExplosion(at: hit.position, normal: hit.normal, projectileID: id)
                    projectilesToRemove.append(id)
                    print("Fireball hit real-world surface at \(hit.position)")
                    continue
                }
                
                // Update entity position and track for next frame
                projectile.entity.position = newPosition
                projectilesToUpdate.append((id, newPosition))
            }

            // Update previous positions for next frame's collision checks
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
                // Store the mesh anchor for collision detection (live)
                sceneMeshAnchors[anchor.id] = anchor
                
                // IMPORTANT: Cache the geometry PERSISTENTLY
                // This data survives even when ARKit removes the anchor
                let cachedGeometry = CachedMeshGeometry(from: anchor)
                persistentMeshCache[anchor.id] = cachedGeometry
                
                // Update scan statistics
                updateScanStatistics()
                
                // Create collision entity for RealityKit (optional, we use our own raycast)
                let collisionEntity = await createCollisionMesh(from: anchor)
                if let existing = rootEntity.findEntity(named: "SceneMesh_\(anchor.id)") {
                    existing.removeFromParent()
                }
                collisionEntity.name = "SceneMesh_\(anchor.id)"
                rootEntity.addChild(collisionEntity)
                
                // Update visualization if enabled
                if isScanVisualizationEnabled {
                    await createOrUpdateVisualization(for: anchor)
                }

            case .removed:
                // Remove from live anchors, but KEEP in persistent cache!
                sceneMeshAnchors.removeValue(forKey: anchor.id)
                
                // Remove RealityKit collision entity
                if let existing = rootEntity.findEntity(named: "SceneMesh_\(anchor.id)") {
                    existing.removeFromParent()
                }
                
                // Note: We intentionally do NOT remove from persistentMeshCache
                // This allows collision detection with surfaces that are no longer in LiDAR range
                print("Mesh \\(anchor.id) removed from ARKit but kept in persistent cache")

            @unknown default:
                break
            }
        }
    }
    
    // MARK: - Scan Statistics
    
    private func updateScanStatistics() {
        scannedMeshCount = persistentMeshCache.count
        scannedTriangleCount = persistentMeshCache.values.reduce(0) { $0 + $1.triangleIndices.count }
        
        // Estimate scanned area (rough approximation based on triangle count)
        // Average triangle might be ~0.01 sq meters
        let estimatedArea = Float(scannedTriangleCount) * 0.01
        if estimatedArea < 1 {
            scannedAreaDescription = String(format: "%.0f triangles scanned", Float(scannedTriangleCount))
        } else {
            scannedAreaDescription = String(format: "~%.1f m² scanned (%d meshes)", estimatedArea, scannedMeshCount)
        }
    }
    
    // MARK: - Scan Visualization
    
    /// Toggle scan visualization on/off
    func toggleScanVisualization() {
        isScanVisualizationEnabled.toggle()
    }
    
    /// Clear all persistent mesh data (useful for rescanning)
    func clearScannedData() {
        persistentMeshCache.removeAll()
        
        // Remove all visualization entities
        for (_, entity) in scanVisualizationEntities {
            entity.removeFromParent()
        }
        scanVisualizationEntities.removeAll()
        
        updateScanStatistics()
        print("Cleared all persistent mesh data")
    }
    
    private func updateScanVisualization() async {
        if isScanVisualizationEnabled {
            // Create visualizations for all cached meshes
            for (id, cached) in persistentMeshCache {
                await createVisualizationFromCache(id: id, cached: cached)
            }
        } else {
            // Remove all visualization entities
            for (_, entity) in scanVisualizationEntities {
                entity.removeFromParent()
            }
            scanVisualizationEntities.removeAll()
        }
    }
    
    private func createOrUpdateVisualization(for anchor: MeshAnchor) async {
        guard isScanVisualizationEnabled else { return }
        
        // Remove existing visualization for this anchor
        if let existing = scanVisualizationEntities[anchor.id] {
            existing.removeFromParent()
        }
        
        // Create wireframe mesh visualization
        let vizEntity = await createWireframeMesh(from: anchor)
        vizEntity.name = "ScanViz_\\(anchor.id)"
        rootEntity.addChild(vizEntity)
        scanVisualizationEntities[anchor.id] = vizEntity
    }
    
    private func createVisualizationFromCache(id: UUID, cached: CachedMeshGeometry) async {
        // Remove existing visualization
        if let existing = scanVisualizationEntities[id] {
            existing.removeFromParent()
        }
        
        // Create visualization entity from cached data
        let vizEntity = Entity()
        vizEntity.transform = Transform(matrix: cached.transform)
        vizEntity.name = "ScanViz_\\(id)"
        
        // Create a simple point cloud or wireframe representation
        // Using a grid material for the mesh
        do {
            var descr = MeshDescriptor(name: "cachedMesh")
            descr.positions = MeshBuffer(cached.vertices)
            
            // Create triangle indices
            var indices: [UInt32] = []
            for tri in cached.triangleIndices {
                indices.append(tri.0)
                indices.append(tri.1)
                indices.append(tri.2)
            }
            descr.primitives = .triangles(indices)
            
            let mesh = try MeshResource.generate(from: [descr])
            
            // Semi-transparent cyan material for scanned areas
            var material = UnlitMaterial()
            material.color = .init(tint: .init(red: 0, green: 0.8, blue: 1, alpha: 0.15))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.15))
            
            let modelComponent = ModelComponent(mesh: mesh, materials: [material])
            vizEntity.components.set(modelComponent)
        } catch {
            print("Failed to create visualization mesh: \\(error)")
        }
        
        rootEntity.addChild(vizEntity)
        scanVisualizationEntities[id] = vizEntity
    }
    
    private func createWireframeMesh(from anchor: MeshAnchor) async -> Entity {
        let entity = Entity()
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        
        do {
            let geometry = anchor.geometry
            
            // Extract vertices
            var vertices: [SIMD3<Float>] = []
            let vertexBuffer = geometry.vertices
            let vertexPointer = vertexBuffer.buffer.contents()
            let vertexStride = vertexBuffer.stride
            
            for i in 0..<vertexBuffer.count {
                let vertexPtr = vertexPointer.advanced(by: i * vertexStride)
                    .bindMemory(to: SIMD3<Float>.self, capacity: 1)
                vertices.append(vertexPtr.pointee)
            }
            
            // Extract indices
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
            
            // Create mesh
            var descr = MeshDescriptor(name: "scanMesh")
            descr.positions = MeshBuffer(vertices)
            descr.primitives = .triangles(indices)
            
            let mesh = try MeshResource.generate(from: [descr])
            
            // Semi-transparent cyan material
            var material = UnlitMaterial()
            material.color = .init(tint: .init(red: 0, green: 0.8, blue: 1, alpha: 0.15))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.15))
            
            let modelComponent = ModelComponent(mesh: mesh, materials: [material])
            entity.components.set(modelComponent)
        } catch {
            print("Failed to create wireframe mesh: \\(error)")
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

    // MARK: - Collision Handling

    private func setupCollisionHandling() async {
        // Collision is handled in updateProjectiles via raycast checks against persistent mesh cache
    }

    /// Check collision using ray-triangle intersection against PERSISTENT mesh cache
    /// This allows collision with surfaces even when they're no longer in LiDAR range
    private func checkProjectileCollision(projectilePosition: SIMD3<Float>, direction: SIMD3<Float>, previousPosition: SIMD3<Float>) -> (position: SIMD3<Float>, normal: SIMD3<Float>)? {
        // Calculate ray from previous position to current position
        let rayOrigin = previousPosition
        let rayDirection = projectilePosition - previousPosition
        let rayLength = simd_length(rayDirection)
        
        // Skip if no movement
        guard rayLength > 0.001 else { return nil }
        
        let normalizedDirection = rayDirection / rayLength
        var closestHit: (position: SIMD3<Float>, normal: SIMD3<Float>)? = nil
        var closestDistance: Float = rayLength
        
        // Check against PERSISTENT mesh cache (not just live anchors)
        // This allows collision with walls that were scanned earlier but are now out of range
        for (_, cachedMesh) in persistentMeshCache {
            if let hit = raycastAgainstCachedMesh(
                rayOrigin: rayOrigin,
                rayDirection: normalizedDirection,
                maxDistance: closestDistance,
                cached: cachedMesh
            ) {
                let hitDistance = simd_distance(rayOrigin, hit.position)
                if hitDistance < closestDistance {
                    closestDistance = hitDistance
                    closestHit = hit
                }
            }
        }
        
        return closestHit
    }
    
    /// Perform raycast against cached mesh geometry (works even when ARKit anchor is gone)
    private func raycastAgainstCachedMesh(
        rayOrigin: SIMD3<Float>,
        rayDirection: SIMD3<Float>,
        maxDistance: Float,
        cached: CachedMeshGeometry
    ) -> (position: SIMD3<Float>, normal: SIMD3<Float>)? {
        let transform = cached.transform
        
        var closestHit: (position: SIMD3<Float>, normal: SIMD3<Float>)? = nil
        var closestT: Float = maxDistance
        
        // Iterate through all triangles in the cached mesh
        for (i0, i1, i2) in cached.triangleIndices {
            // Get vertex positions (in local space)
            guard Int(i0) < cached.vertices.count,
                  Int(i1) < cached.vertices.count,
                  Int(i2) < cached.vertices.count else { continue }
            
            let v0Local = cached.vertices[Int(i0)]
            let v1Local = cached.vertices[Int(i1)]
            let v2Local = cached.vertices[Int(i2)]
            
            // Transform to world space
            let v0 = transformPoint(v0Local, by: transform)
            let v1 = transformPoint(v1Local, by: transform)
            let v2 = transformPoint(v2Local, by: transform)
            
            // Ray-triangle intersection (Möller–Trumbore algorithm)
            if let t = rayTriangleIntersection(
                rayOrigin: rayOrigin,
                rayDirection: rayDirection,
                v0: v0, v1: v1, v2: v2
            ) {
                if t > 0.001 && t < closestT {
                    closestT = t
                    let hitPos = rayOrigin + rayDirection * t
                    
                    // Calculate normal and flip to face the incoming ray
                    let edge1 = v1 - v0
                    let edge2 = v2 - v0
                    var normal = normalize(simd_cross(edge1, edge2))
                    if simd_dot(normal, rayDirection) > 0 {
                        normal = -normal
                    }
                    
                    closestHit = (hitPos, normal)
                }
            }
        }
        
        return closestHit
    }
    
    /// Perform raycast against a live mesh anchor's geometry (for reference, now using cached version primarily)
    private func raycastAgainstMesh(
        rayOrigin: SIMD3<Float>,
        rayDirection: SIMD3<Float>,
        maxDistance: Float,
        meshAnchor: MeshAnchor
    ) -> SIMD3<Float>? {
        let geometry = meshAnchor.geometry
        let transform = meshAnchor.originFromAnchorTransform
        
        // Get vertices from mesh
        let vertexBuffer = geometry.vertices
        let vertexCount = vertexBuffer.count
        
        // Get indices/faces
        let faceBuffer = geometry.faces
        let faceCount = faceBuffer.count
        let indicesPerFace = faceBuffer.primitive.indexCount
        
        // Only support triangles (3 vertices per face)
        guard indicesPerFace == 3 else { return nil }
        
        var closestHit: SIMD3<Float>? = nil
        var closestT: Float = maxDistance
        
        // Access vertex data
        let vertexPointer = vertexBuffer.buffer.contents()
        let vertexStride = vertexBuffer.stride
        
        // Access index data
        let indexPointer = faceBuffer.buffer.contents()
        let bytesPerIndex = faceBuffer.bytesPerIndex
        
        // Iterate through all triangles
        for faceIndex in 0..<faceCount {
            // Get triangle indices
            let i0: UInt32
            let i1: UInt32
            let i2: UInt32
            
            if bytesPerIndex == 2 {
                // UInt16 indices
                let indexPtr = indexPointer.advanced(by: faceIndex * 3 * bytesPerIndex)
                    .bindMemory(to: UInt16.self, capacity: 3)
                i0 = UInt32(indexPtr[0])
                i1 = UInt32(indexPtr[1])
                i2 = UInt32(indexPtr[2])
            } else {
                // UInt32 indices
                let indexPtr = indexPointer.advanced(by: faceIndex * 3 * bytesPerIndex)
                    .bindMemory(to: UInt32.self, capacity: 3)
                i0 = indexPtr[0]
                i1 = indexPtr[1]
                i2 = indexPtr[2]
            }
            
            // Get vertex positions (in local space)
            let v0Local = getVertex(at: Int(i0), pointer: vertexPointer, stride: vertexStride)
            let v1Local = getVertex(at: Int(i1), pointer: vertexPointer, stride: vertexStride)
            let v2Local = getVertex(at: Int(i2), pointer: vertexPointer, stride: vertexStride)
            
            // Transform to world space
            let v0 = transformPoint(v0Local, by: transform)
            let v1 = transformPoint(v1Local, by: transform)
            let v2 = transformPoint(v2Local, by: transform)
            
            // Ray-triangle intersection (Möller–Trumbore algorithm)
            if let t = rayTriangleIntersection(
                rayOrigin: rayOrigin,
                rayDirection: rayDirection,
                v0: v0, v1: v1, v2: v2
            ) {
                if t > 0.001 && t < closestT {
                    closestT = t
                    closestHit = rayOrigin + rayDirection * t
                }
            }
        }
        
        return closestHit
    }
    
    /// Extract vertex position from buffer
    private func getVertex(at index: Int, pointer: UnsafeMutableRawPointer, stride: Int) -> SIMD3<Float> {
        let vertexPtr = pointer.advanced(by: index * stride)
            .bindMemory(to: SIMD3<Float>.self, capacity: 1)
        return vertexPtr.pointee
    }
    
    /// Transform a point by a 4x4 matrix
    private func transformPoint(_ point: SIMD3<Float>, by matrix: simd_float4x4) -> SIMD3<Float> {
        let p4 = SIMD4<Float>(point.x, point.y, point.z, 1.0)
        let transformed = matrix * p4
        return SIMD3<Float>(transformed.x, transformed.y, transformed.z)
    }
    
    /// Möller–Trumbore ray-triangle intersection algorithm
    /// Returns the parametric t value if intersection occurs, nil otherwise
    private func rayTriangleIntersection(
        rayOrigin: SIMD3<Float>,
        rayDirection: SIMD3<Float>,
        v0: SIMD3<Float>,
        v1: SIMD3<Float>,
        v2: SIMD3<Float>
    ) -> Float? {
        let epsilon: Float = 0.0000001
        
        let edge1 = v1 - v0
        let edge2 = v2 - v0
        
        let h = simd_cross(rayDirection, edge2)
        let a = simd_dot(edge1, h)
        
        // Ray is parallel to triangle
        if a > -epsilon && a < epsilon {
            return nil
        }
        
        let f = 1.0 / a
        let s = rayOrigin - v0
        let u = f * simd_dot(s, h)
        
        if u < 0.0 || u > 1.0 {
            return nil
        }
        
        let q = simd_cross(s, edge1)
        let v = f * simd_dot(rayDirection, q)
        
        if v < 0.0 || u + v > 1.0 {
            return nil
        }
        
        // Compute t to find intersection point
        let t = f * simd_dot(edge2, q)
        
        if t > epsilon {
            return t
        }
        
        return nil
    }

    // MARK: - Explosion System

    private func triggerExplosion(at position: SIMD3<Float>, normal: SIMD3<Float>? = nil, projectileID: UUID) async {
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
        
        // Play explosion sound
        var audioController: AudioPlaybackController?
        if let explosionSound = explosionSound {
            audioController = explosion.playAudio(explosionSound)
        }
        
        rootEntity.addChild(explosion)

        // Add scorch mark if we have a normal - spawns immediately with explosion
        if let normal = normal {
            Task {
                let scorch = createScorchMark()
                // Position slightly off the wall to avoid z-fighting
                let scorchPosition = position + normal * 0.01
                scorch.position = scorchPosition

                // Orient so the scorch's +Z faces the wall normal
                // look(at:from:) aligns -Z to the target direction
                scorch.look(at: scorchPosition - normal, from: scorchPosition, relativeTo: nil)

                // Natural fade-in: start slightly smaller and grow
                // This makes it feel like the soot is being deposited/settling
                scorch.scale = [0.7, 0.7, 0.7]

                rootEntity.addChild(scorch)

                // Subtle grow animation for natural appearance
                var transform = scorch.transform
                transform.scale = [1.0, 1.0, 1.0]
                scorch.move(to: transform, relativeTo: scorch.parent, duration: 0.5, timingFunction: .easeOut)

                // Remove scorch mark after a delay
                Task {
                    try? await Task.sleep(for: .seconds(16))
                    await fadeOutScorch(scorch, duration: 1.0)
                    scorch.removeFromParent()
                }
            }
        }

        print("Explosion at \(position)")

        Task {
            if let lightEntity = explosion.children.first(where: {
                $0.components[PointLightComponent.self] != nil
            }) {
                // Animate light intensity down
                let steps = 20
                for i in 0..<steps {
                    try? await Task.sleep(for: .milliseconds(50))
                    if var light = lightEntity.components[PointLightComponent.self] {
                        light.intensity = 5000 * Float(steps - i) / Float(steps)
                        lightEntity.components.set(light)
                    }
                }
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            
            // Fade out audio
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
