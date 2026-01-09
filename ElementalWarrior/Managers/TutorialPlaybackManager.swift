//
//  TutorialPlaybackManager.swift
//  ElementalWarrior
//
//  Manages tutorial hand animation playback and companion VFX previews.
//

import SwiftUI
import RealityKit
//import RealityFoundation
import QuartzCore

enum TutorialCategory: String, CaseIterable, Hashable {
    case fireball
    case flamethrower
    case wall

    var title: String {
        switch self {
        case .fireball:
            return "Fireball"
        case .flamethrower:
            return "Flamethrower"
        case .wall:
            return "Wall of Fire"
        }
    }

    var systemImage: String {
        switch self {
        case .fireball:
            return "flame"
        case .flamethrower:
            return "flame.fill"
        case .wall:
            return "rectangle.split.3x1"
        }
    }

    var resourceFolder: String {
        rawValue
    }
}

enum HandTutorialKind: String, CaseIterable, Hashable {
    case fireballSummonRight = "fireball_summon_right"
    case fireballMaintainRight = "fireball_maintain_right"
    case fireballFollowRight = "fireball_follow_right"
    case fireballPunchRight = "fireball_punch_right"
    case fireballCrossPunchBoth = "fireball_crossPunch_both"
    case fireballCombineBoth = "fireball_combine_both"
    case flamethrowerSummonRight = "flamethrower_summon_right"
    case flamethrowerCombineBoth = "flamethrower_combine_both"
    case wallSummonBoth = "wall_summon_both"
    case wallHeightBoth = "wall_height_both"
    case wallLocationBoth = "wall_location_both"
    case wallWidthBoth = "wall_width_both"
    case wallRotationBoth = "wall_rotation_both"
    case wallConfirmBoth = "wall_confirm_both"

    var category: TutorialCategory {
        switch self {
        case .fireballSummonRight,
             .fireballMaintainRight,
             .fireballFollowRight,
             .fireballPunchRight,
             .fireballCrossPunchBoth,
             .fireballCombineBoth:
            return .fireball
        case .flamethrowerSummonRight,
             .flamethrowerCombineBoth:
            return .flamethrower
        case .wallSummonBoth,
             .wallHeightBoth,
             .wallLocationBoth,
             .wallWidthBoth,
             .wallRotationBoth,
             .wallConfirmBoth:
            return .wall
        }
    }

    var title: String {
        switch self {
        case .fireballSummonRight:
            return "Summon (Right Hand)"
        case .fireballMaintainRight:
            return "Maintain (Right Hand)"
        case .fireballFollowRight:
            return "Follow (Right Hand)"
        case .fireballPunchRight:
            return "Punch (Right Hand)"
        case .fireballCrossPunchBoth:
            return "Cross Punch (Both Hands)"
        case .fireballCombineBoth:
            return "Combine (Both Hands)"
        case .flamethrowerSummonRight:
            return "Summon (Right Hand)"
        case .flamethrowerCombineBoth:
            return "Combine (Both Hands)"
        case .wallSummonBoth:
            return "Summon (Both Hands)"
        case .wallHeightBoth:
            return "Height (Both Hands)"
        case .wallLocationBoth:
            return "Location (Both Hands)"
        case .wallWidthBoth:
            return "Width (Both Hands)"
        case .wallRotationBoth:
            return "Rotation (Both Hands)"
        case .wallConfirmBoth:
            return "Confirm (Both Hands)"
        }
    }

    var description: String {
        switch self {
        case .fireballSummonRight:
            return "Raise your palm to the sky with your hand open to summon a fireball."
        case .fireballMaintainRight:
            return "Summon a fireball with an open, palm-up hand, then flip your palm down to show it holds position."
        case .fireballFollowRight:
            return "Summon a fireball and keep the palm-up hand open while moving it to show the fireball tracks."
        case .fireballPunchRight:
            return "Summon a fireball, hold it in your palm, then punch forward with a closed fist to launch it."
        case .fireballCrossPunchBoth:
            return "Summon a fireball with your right hand, then punch it with your left fist."
        case .fireballCombineBoth:
            return "Summon fireballs in both hands, bring them together to combine, then move the merged fireball."
        case .flamethrowerSummonRight:
            return "Open your right hand and face your palm forward to summon a flamethrower, then move to show tracking."
        case .flamethrowerCombineBoth:
            return "Summon flamethrowers with both hands, bring them together to combine, then separate to split them again."
        case .wallSummonBoth:
            return "Raise both hands with palms down to summon the wall of fire."
        case .wallHeightBoth:
            return "Raise both hands to summon the wall, then lift or lower your hands to change its height."
        case .wallLocationBoth:
            return "Summon the wall, then move both hands together to reposition it left, right, forward, or back."
        case .wallWidthBoth:
            return "Summon the wall, then move your hands apart or together to widen or narrow it."
        case .wallRotationBoth:
            return "Summon the wall, then shift which hand is forward to rotate its angle."
        case .wallConfirmBoth:
            return "Raise the wall past the ember height, then clench and release your fists to confirm."
        }
    }

    var loopDuration: TimeInterval {
        switch self {
        case .fireballSummonRight:
            return 4.0
        case .fireballMaintainRight:
            return 5.0
        case .fireballFollowRight:
            return 7.0
        case .fireballPunchRight:
            return 6.0
        case .fireballCrossPunchBoth:
            return 3.66
        case .fireballCombineBoth:
            return 6.0
        case .flamethrowerSummonRight:
            return 5.0
        case .flamethrowerCombineBoth:
            return 8.0
        case .wallSummonBoth:
            return 4.0
        case .wallHeightBoth:
            return 5.0
        case .wallLocationBoth:
            return 7.0
        case .wallWidthBoth:
            return 7.0
        case .wallRotationBoth:
            return 6.0
        case .wallConfirmBoth:
            return 7.0
        }
    }
}

struct HandTutorial: Identifiable, Hashable {
    let kind: HandTutorialKind

    var id: String { kind.rawValue }
    var category: TutorialCategory { kind.category }
    var title: String { kind.title }
    var description: String { kind.description }
    var loopDuration: TimeInterval { kind.loopDuration }
    var resourceSubdirectory: String { "hand_animations/usdz/\(kind.category.resourceFolder)" }

    func resourceURL(in bundle: Bundle = .main) -> URL? {
        let subdirectories = [
            resourceSubdirectory,
            "Resources/\(resourceSubdirectory)"
        ]

        for subdirectory in subdirectories {
            if let url = bundle.url(forResource: kind.rawValue, withExtension: "usdz", subdirectory: subdirectory) {
                return url
            }
        }

        return bundle.url(forResource: kind.rawValue, withExtension: "usdz")
    }

    static let library: [HandTutorial] = HandTutorialKind.allCases.map { HandTutorial(kind: $0) }

    static func tutorials(in category: TutorialCategory) -> [HandTutorial] {
        library.filter { $0.category == category }
    }
}

@MainActor
@Observable
final class TutorialPlaybackManager {
    let rootEntity = Entity()

    var currentTutorial: HandTutorial?
    var isPlaying: Bool = false
    var lastError: String?
    var previewSize: SIMD3<Float> = [0.4, 0.4, 0.4]
    var isLoading: Bool = false

    // User transform for pinch/drag gestures
    var userScale: Float = 1.0
    var userOffset: SIMD3<Float> = .zero

    private struct HandAnchor {
        var target: Entity?  // Fallback entity (non-skeletal)
        var skeletal: SkeletalAnchor?  // Primary: sampled skeletal animation data
        var side: HandSide?
    }

    private struct SkeletalAnchor {
        let state: SkeletalAnimationState
        let jointIndex: Int
    }

    private enum HandSide {
        case left
        case right
    }

    private struct HandTargets {
        var left: HandAnchor
        var right: HandAnchor
    }

    private struct EffectAttachment {
        var effect: Entity
        var anchor: HandAnchor
        var offset: SIMD3<Float>
        var isTracking: Bool = true
        var frozenTransform: Transform?
        var isFlamethrower: Bool = false  // Flamethrowers need special rotation to align with palm
    }

    private struct ActiveEffect {
        var leftFireball: Entity?
        var rightFireball: Entity?
        var combinedFireball: Entity?
        var leftFlamethrower: Entity?
        var rightFlamethrower: Entity?
        var combinedFlamethrower: Entity?
        var wallVisual: FireWallVisual?
        var wallRoot: Entity?
        var wallEmberVisual: EmberLineVisual?
        var wallBasePosition: SIMD3<Float> = .zero
        var wallTracksHands: Bool = false

        // Projectile launch state
        var launchedProjectile: Entity?
        var projectileTrail: Entity?
        var projectileVelocity: SIMD3<Float> = .zero
        var projectileLaunched: Bool = false
        var explosion: Entity?
        var scorchMark: Entity?

        // Combine effects
        var combineFlash: Entity?
        var combineFlashShown: Bool = false

        // Flamethrower combine effects
        var flamethrowerCombineFlash: Entity?
        var flamethrowerCombineFlashShown: Bool = false
        var flamethrowerSplitFlashShown: Bool = false

        // Fireball despawn smoke tracking
        var leftFireballSmokeShown: Bool = false
        var rightFireballSmokeShown: Bool = false
        var combinedFireballSmokeShown: Bool = false
    }

    private let stageEntity = Entity()
    private let tutorialContainer = Entity()

    private var animationControllers: [AnimationPlaybackController] = []
    private var effectTask: Task<Void, Never>?
    private var tutorialEntity: Entity?
    private var activeEffect = ActiveEffect()
    private var effectAttachments: [EffectAttachment] = []
    private var previewBoundsMin: SIMD3<Float>?
    private var previewBoundsMax: SIMD3<Float>?
    private var handTargets = HandTargets(left: HandAnchor(), right: HandAnchor())
    private var skeletalStates: [SkeletalAnimationState] = []
    private var lastLoopTime: TimeInterval = 0
    private var activeLoopDuration: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0

    private let defaultFireballOffset = SIMD3<Float>(-0.3, 0.12, 0.18)
    // Left hand offset mirrors the X component for proper positioning above left palm
    private var leftFireballOffset: SIMD3<Float> {
        SIMD3<Float>(abs(fireballOffset.x), fireballOffset.y, fireballOffset.z)
    }
    var fireballOffset: SIMD3<Float> {
        didSet {
            updateFireballOffsetAttachments()
        }
    }
    private let flamethrowerOffset = SIMD3<Float>(0, 0, 0.17)
    private let fireballScale: Float = 0.35
    private let combinedFireballScale: Float = 0.52
    private let flamethrowerScale: Float = 0.55
    private let combinedFlamethrowerScale: Float = 0.7
    private let wallBaseWidth: Float = 1.4  // Doubled from 0.7 for wider initial wall
    private let wallBaseHeight: Float = 0.7
    private let wallBaseOffset = SIMD3<Float>(0, 0, -0.5)  // In front of hands at floor level
    private let wallMinHeight: Float = 0.06
    private let wallWidthWideScale: Float = 1.5
    private let wallWidthNarrowScale: Float = 0.6
    private let wallHeightHighScale: Float = 1.35
    private let wallHeightLowScale: Float = 0.7
    private let wallMoveOffsetX: Float = 0.18
    private let wallMoveOffsetZ: Float = 0.15
    private let wallRotationRadians: Float = 0.6
    private let wallEmberHeight: Float = 0.12
    private let wallSpawnDelay: TimeInterval = 1.0
    private let fireballSpawnScale: Float = 0.01
    private let fireballDespawnScale: Float = 0.001
    private let fireballSpawnDuration: TimeInterval = 0.5
    private let fireballDespawnDuration: TimeInterval = 0.25
    private let baseStageScale: Float = 0.12
    private var currentStageScale: Float = 0.12
    private let stageOffset = SIMD3<Float>(0, 0, 0)
    private let previewPadding: Float = 0.08
    private let previewMinSize: SIMD3<Float> = [0.25, 0.25, 0.25]
    private let previewMaxSize: SIMD3<Float> = [1.8, 1.8, 1.8]
    private let windowVolume: Float = 1.2 // Usable volume inside 1.5m window (with margin)

    init() {
        fireballOffset = defaultFireballOffset
        rootEntity.name = "TutorialRoot"
        stageEntity.name = "TutorialStage"
        tutorialContainer.name = "TutorialContainer"

        rootEntity.addChild(stageEntity)
        stageEntity.addChild(tutorialContainer)

        stageEntity.position = stageOffset
        currentStageScale = baseStageScale
        stageEntity.scale = SIMD3<Float>(repeating: currentStageScale)

        addLighting()
    }

    func play(tutorial: HandTutorial) async {
        stop(resetTutorial: false)

        currentTutorial = tutorial
        lastError = nil
        isLoading = true  // Show loading indicator

        defer {
            isLoading = false  // Hide loading indicator when done
        }

        guard let url = tutorial.resourceURL() else {
            lastError = "Missing tutorial asset: \(tutorial.id)"
            isPlaying = false
            return
        }

        // Debug: Print the URL being loaded
        print("[TutorialPlayback] Loading tutorial: \(tutorial.id)")
        print("[TutorialPlayback] URL: \(url)")
        print("[TutorialPlayback] Expected file: \(tutorial.id).usdz")

        do {
            let entity = try await Entity(contentsOf: url)
            entity.name = tutorial.id
            entity.position = .zero
            centerTutorialEntity(entity)
            tutorialContainer.addChild(entity)
            tutorialEntity = entity

            let animations = collectAnimations(from: entity)
            if animations.isEmpty {
                lastError = "No animation found in \(tutorial.id)"
            } else {
                animationControllers = animations.map { animation in
                    let looping = animation.repeat()
                    return entity.playAnimation(looping, transitionDuration: 0.15, startsPaused: false)
                }
            }

            previewBoundsMin = nil
            previewBoundsMax = nil
            previewSize = [0.4, 0.4, 0.4]
            effectAttachments.removeAll()
            skeletalStates = buildSkeletalStates(in: entity, animations: animations)
            handTargets = resolveHandTargets(in: entity)
            activeLoopDuration = resolveLoopDuration(for: tutorial, animations: animations, skeletalStates: skeletalStates)

            activeEffect = configureEffects(for: tutorial, handTargets: handTargets)

            // Calculate appropriate scale to fit animation in window
            calculateAndApplyScale(for: entity, tutorial: tutorial)

            startEffectLoop(for: tutorial)

            isPlaying = true
        } catch {
            lastError = "Failed to load \(tutorial.id): \(error.localizedDescription)"
            isPlaying = false
        }
    }

    private func calculateAndApplyScale(for entity: Entity, tutorial: HandTutorial) {
        // Get the bounds of the loaded animation content (rest pose)
        let bounds = entity.visualBounds(relativeTo: entity)
        let contentSize = bounds.max - bounds.min

        var maxExtent = max(contentSize.x, max(contentSize.y, contentSize.z))

        // IMPORTANT: Animations move beyond rest pose bounds
        // Apply a 2x multiplier to account for animation movement range
        maxExtent *= 2.0

        // Add padding for effects that extend beyond the hand
        switch tutorial.kind.category {
        case .fireball, .flamethrower:
            maxExtent += 0.5 // Extra space for fire effects
        case .wall:
            maxExtent = max(maxExtent, (wallBaseWidth + 0.3) * 2)
            maxExtent = max(maxExtent, (wallBaseHeight + 0.3) * 2)
        }

        // Calculate scale to fit within window volume
        if maxExtent > 0.01 {
            let targetScale = windowVolume / maxExtent
            // Use the smaller of target scale or base scale to ensure fit
            currentStageScale = min(targetScale, baseStageScale)
            currentStageScale = max(currentStageScale, baseStageScale * 0.3) // Min at 0.3x base scale
        } else {
            currentStageScale = baseStageScale
        }

        stageEntity.scale = [currentStageScale, currentStageScale, currentStageScale]
        print("[TutorialPlayback] Rest bounds: \(contentSize), estimated max extent: \(maxExtent), applied scale: \(currentStageScale)")
    }

    private func resolveLoopDuration(for tutorial: HandTutorial,
                                     animations: [AnimationResource],
                                     skeletalStates: [SkeletalAnimationState]) -> TimeInterval {
        var durations = skeletalStates.map { $0.sampledAnimation.duration }.filter { $0 > 0 }

        if durations.isEmpty {
            for animation in animations {
                if let sampled = animation.definition as? SampledAnimation<JointTransforms> {
                    durations.append(sampled.duration)
                } else if let sampled = animation.definition as? SampledAnimation<Transform> {
                    durations.append(sampled.duration)
                }
            }
        }

        if let maxDuration = durations.filter({ $0 > 0 }).max() {
            return maxDuration
        }

        return tutorial.kind.loopDuration
    }

    func stop(resetTutorial: Bool = false) {
        effectTask?.cancel()
        effectTask = nil

        for controller in animationControllers {
            controller.stop()
        }
        animationControllers.removeAll()

        removeActiveEffects()
        tutorialContainer.children.forEach { $0.removeFromParent() }
        tutorialEntity = nil
        activeEffect = ActiveEffect()
        effectAttachments.removeAll()
        previewBoundsMin = nil
        previewBoundsMax = nil
        skeletalStates.removeAll()
        lastLoopTime = 0
        activeLoopDuration = 0
        isPlaying = false

        // Reset stage scale to base
        currentStageScale = baseStageScale
        stageEntity.scale = [baseStageScale, baseStageScale, baseStageScale]

        if resetTutorial {
            currentTutorial = nil
            lastError = nil
        }
    }

    func resetFireballOffset() {
        fireballOffset = defaultFireballOffset
    }

    private func addLighting() {
        let keyLight = Entity()
        keyLight.name = "TutorialKeyLight"
        keyLight.components.set(PointLightComponent(color: .white, intensity: 1100, attenuationRadius: 2.5))
        keyLight.position = [0.25, 0.45, 0.25]
        stageEntity.addChild(keyLight)

        let fillLight = Entity()
        fillLight.name = "TutorialFillLight"
        fillLight.components.set(PointLightComponent(color: .white, intensity: 350, attenuationRadius: 2.0))
        fillLight.position = [-0.25, 0.18, 0.18]
        stageEntity.addChild(fillLight)
    }

    private func resolveHandTargets(in entity: Entity) -> HandTargets {
        var leftAnchor = HandAnchor()
        var rightAnchor = HandAnchor()

        // PRIMARY: Resolve skeletal anchors without relying on joint names.
        // Pick a stable joint per skeletal state and assign sides by X position.
        // Sample at t=1.0s instead of t=0 to get more reliable hand positions
        // (at t=0 hands may be in unusual starting positions)
        let sampleTime: TimeInterval = 1.0
        var skeletalCandidates: [(anchor: SkeletalAnchor, x: Float, side: HandSide?)] = []
        for state in skeletalStates {
            guard let jointIndex = preferredJointIndex(for: state) else { continue }
            let anchor = SkeletalAnchor(state: state, jointIndex: jointIndex)
            let xPosition: Float
            if let transform = currentJointTransform(for: anchor, animationTime: sampleTime) {
                xPosition = transform.translation.x
            } else if let transform = currentJointTransform(for: anchor, animationTime: 0) {
                // Fallback to t=0 if t=1.0 fails
                xPosition = transform.translation.x
            } else {
                xPosition = state.modelEntity.transformMatrix(relativeTo: tutorialContainer).columns.3.x
            }
            skeletalCandidates.append((anchor: anchor, x: xPosition, side: state.sideHint))
        }

        if !skeletalCandidates.isEmpty {
            let leftHints = skeletalCandidates.filter { $0.side == .left }
            let rightHints = skeletalCandidates.filter { $0.side == .right }

            var leftCandidate = leftHints.min(by: { $0.x < $1.x })
            var rightCandidate = rightHints.max(by: { $0.x < $1.x })

            if leftCandidate == nil || rightCandidate == nil {
                let sorted = skeletalCandidates.sorted { $0.x < $1.x }
                if leftCandidate == nil {
                    leftCandidate = sorted.first(where: { candidate in
                        guard let rightCandidate else { return true }
                        return ObjectIdentifier(candidate.anchor.state) != ObjectIdentifier(rightCandidate.anchor.state)
                    })
                }
                if rightCandidate == nil {
                    rightCandidate = sorted.last(where: { candidate in
                        guard let leftCandidate else { return true }
                        return ObjectIdentifier(candidate.anchor.state) != ObjectIdentifier(leftCandidate.anchor.state)
                    })
                }
            }

            if leftCandidate == nil && rightCandidate == nil, let only = skeletalCandidates.first {
                rightCandidate = only
            }

            leftAnchor.skeletal = leftCandidate?.anchor
            rightAnchor.skeletal = rightCandidate?.anchor
            if leftAnchor.skeletal != nil {
                leftAnchor.side = .left
                print("[TutorialPlayback] ✓ Assigned LEFT skeletal anchor (joint \(leftAnchor.skeletal?.jointIndex ?? -1))")
            }
            if rightAnchor.skeletal != nil {
                rightAnchor.side = .right
                print("[TutorialPlayback] ✓ Assigned RIGHT skeletal anchor (joint \(rightAnchor.skeletal?.jointIndex ?? -1))")
            }
        } else {
            print("[TutorialPlayback] ✗ No skeletal anchors found")
        }

        // FALLBACK: Use model entities by position if skeletal anchors are unavailable.
        let modelEntities = collectEntities(from: entity).compactMap { $0 as? ModelEntity }
        if !modelEntities.isEmpty && (leftAnchor.skeletal == nil || rightAnchor.skeletal == nil) {
            let sorted = modelEntities.sorted { entityCenterX($0) < entityCenterX($1) }
            if leftAnchor.skeletal == nil {
                leftAnchor.target = sorted.first
                leftAnchor.side = .left
            }
            if rightAnchor.skeletal == nil {
                rightAnchor.target = sorted.last
                rightAnchor.side = .right
            }
        }

        return HandTargets(left: leftAnchor, right: rightAnchor)
    }

    private func collectEntities(from root: Entity) -> [Entity] {
        var result: [Entity] = [root]
        for child in root.children {
            result.append(contentsOf: collectEntities(from: child))
        }
        return result
    }

    private func sideHint(for entity: Entity) -> HandSide? {
        var current: Entity? = entity
        while let node = current {
            let name = node.name.lowercased()
            if name.contains("left") {
                return .left
            }
            if name.contains("right") {
                return .right
            }
            current = node.parent
        }
        return nil
    }

    private func centerTutorialEntity(_ entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: entity)
        let center = (bounds.min + bounds.max) * 0.5
        if simd_length(center) > 0.001 {
            entity.position -= center
        }
    }

    private func configureEffects(for tutorial: HandTutorial, handTargets: HandTargets) -> ActiveEffect {
        var effect = ActiveEffect()

        switch tutorial.kind {
        case .fireballSummonRight,
             .fireballMaintainRight,
             .fireballFollowRight,
             .fireballPunchRight,
             .fireballCrossPunchBoth:
            let fireball = createRealisticFireball(scale: fireballScale)
            effect.rightFireball = attachEffect(fireball, offset: fireballOffset, anchor: handTargets.right)
            registerAttachment(effect.rightFireball, anchor: handTargets.right, offset: fireballOffset)
            setVisibility(effect.rightFireball, isVisible: false)
        case .fireballCombineBoth:
            let leftFireball = createRealisticFireball(scale: fireballScale)
            let rightFireball = createRealisticFireball(scale: fireballScale)
            // Use enhanced mega fireball for combined effect
            let combined = createMegaFireball(scale: combinedFireballScale)
            // Use mirrored offset for left hand so fireball appears above palm correctly
            effect.leftFireball = attachEffect(leftFireball, offset: leftFireballOffset, anchor: handTargets.left)
            effect.rightFireball = attachEffect(rightFireball, offset: fireballOffset, anchor: handTargets.right)
            effect.combinedFireball = attachEffect(combined, offset: fireballOffset, anchor: handTargets.right)
            registerAttachment(effect.leftFireball, anchor: handTargets.left, offset: leftFireballOffset)
            registerAttachment(effect.rightFireball, anchor: handTargets.right, offset: fireballOffset)
            registerAttachment(effect.combinedFireball, anchor: handTargets.right, offset: fireballOffset)
            setVisibility(effect.leftFireball, isVisible: false)
            setVisibility(effect.rightFireball, isVisible: false)
            setVisibility(effect.combinedFireball, isVisible: false)

            // Pre-create combine flash (will be positioned and shown at combine time)
            let flash = createCombineFlashEffect(scale: 0.8)
            flash.isEnabled = false
            tutorialContainer.addChild(flash)
            effect.combineFlash = flash
        case .flamethrowerSummonRight:
            let stream = createFlamethrowerStream(scale: flamethrowerScale, muzzleScale: 0.5, jetIntensityMultiplier: 1.0)
            effect.rightFlamethrower = attachEffect(stream, offset: flamethrowerOffset, anchor: handTargets.right)
            registerAttachment(effect.rightFlamethrower, anchor: handTargets.right, offset: flamethrowerOffset, isFlamethrower: true)
            setVisibility(effect.rightFlamethrower, isVisible: false)
        case .flamethrowerCombineBoth:
            let leftStream = createFlamethrowerStream(scale: flamethrowerScale, muzzleScale: 0.5, jetIntensityMultiplier: 1.0)
            let rightStream = createFlamethrowerStream(scale: flamethrowerScale, muzzleScale: 0.5, jetIntensityMultiplier: 1.0)
            let combinedStream = createCombinedFlamethrowerStream(scale: combinedFlamethrowerScale)
            effect.leftFlamethrower = attachEffect(leftStream, offset: flamethrowerOffset, anchor: handTargets.left)
            effect.rightFlamethrower = attachEffect(rightStream, offset: flamethrowerOffset, anchor: handTargets.right)
            effect.combinedFlamethrower = attachEffect(combinedStream, offset: flamethrowerOffset, anchor: handTargets.right)
            registerAttachment(effect.leftFlamethrower, anchor: handTargets.left, offset: flamethrowerOffset, isFlamethrower: true)
            registerAttachment(effect.rightFlamethrower, anchor: handTargets.right, offset: flamethrowerOffset, isFlamethrower: true)
            registerAttachment(effect.combinedFlamethrower, anchor: handTargets.right, offset: flamethrowerOffset, isFlamethrower: true)
            setVisibility(effect.leftFlamethrower, isVisible: false)
            setVisibility(effect.rightFlamethrower, isVisible: false)
            setVisibility(effect.combinedFlamethrower, isVisible: false)

            // Pre-create flamethrower combine flash
            let flash = createFlamethrowerCombineFlash(scale: 0.7)
            flash.isEnabled = false
            tutorialContainer.addChild(flash)
            effect.flamethrowerCombineFlash = flash
        case .wallSummonBoth,
             .wallHeightBoth,
             .wallLocationBoth,
             .wallWidthBoth,
             .wallRotationBoth,
             .wallConfirmBoth:
            // Start with ember line height (wallMinHeight) and blue palette
            let visual = createFireWallEffect(width: wallBaseWidth, height: wallMinHeight)
            applyFireWallPalette(visual, palette: highlightFireWallPalette())  // Blue (unconfirmed)
            visual.root.position = wallBaseOffset
            tutorialContainer.addChild(visual.root)
            effect.wallVisual = visual
            effect.wallRoot = visual.root
            let emberVisual = createEmberLineEffect(width: wallBaseWidth)
            emberVisual.root.position = wallBaseOffset
            tutorialContainer.addChild(emberVisual.root)
            effect.wallEmberVisual = emberVisual
            effect.wallBasePosition = wallBaseOffset
            effect.wallTracksHands = true  // Enable wall tracking to hand positions
        }

        return effect
    }

    private func attachEffect(_ effect: Entity, offset: SIMD3<Float>, anchor: HandAnchor? = nil) -> Entity {
        // Always add to tutorialContainer - positioning is handled by updateEffectAnchors each frame
        effect.position = offset
        tutorialContainer.addChild(effect)
        return effect
    }

    private func registerAttachment(_ effect: Entity?, anchor: HandAnchor, offset: SIMD3<Float>, isFlamethrower: Bool = false) {
        guard let effect else { return }
        effectAttachments.append(EffectAttachment(effect: effect, anchor: anchor, offset: offset, isFlamethrower: isFlamethrower))
    }

    private func setTracking(_ effect: Entity?, isTracking: Bool) {
        guard let effect else { return }
        let targetID = ObjectIdentifier(effect)
        for index in effectAttachments.indices {
            if ObjectIdentifier(effectAttachments[index].effect) == targetID {
                if effectAttachments[index].isTracking != isTracking {
                    effectAttachments[index].isTracking = isTracking
                    if isTracking {
                        effectAttachments[index].frozenTransform = nil
                    } else {
                        effectAttachments[index].frozenTransform = Transform(
                            scale: effect.scale,
                            rotation: effect.orientation,
                            translation: effect.position
                        )
                    }
                }
                break
            }
        }
    }

    private func startEffectLoop(for tutorial: HandTutorial) {
        effectTask?.cancel()

        let startTime = CACurrentMediaTime()
        lastLoopTime = 0
        effectTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let elapsed = CACurrentMediaTime() - startTime
                self?.updateEffects(for: tutorial, elapsedTime: elapsed)
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private func updateEffects(for tutorial: HandTutorial, elapsedTime: TimeInterval = 0) {
        // Use our tracked elapsed time instead of controller time (which returns 0)
        let animationTime = elapsedTime
        let duration = max(activeLoopDuration > 0 ? activeLoopDuration : tutorial.kind.loopDuration, 0.001)
        let timeInLoop = elapsedTime.truncatingRemainder(dividingBy: duration)
        if timeInLoop < lastLoopTime {
            resetLoopState()
        }
        lastLoopTime = timeInLoop
        updateEffectAnchors(animationTime: animationTime)
        updatePreviewBounds(animationTime: animationTime)

        switch tutorial.kind {
        case .fireballSummonRight:
            updateFireballLifecycle(
                activeEffect.rightFireball,
                time: timeInLoop,
                showStart: 1.0,
                showEnd: 3.0,
                spawnSmoke: true,
                smokeShown: &activeEffect.rightFireballSmokeShown
            )
            setTracking(activeEffect.rightFireball, isTracking: true)
        case .fireballMaintainRight:
            updateFireballLifecycle(
                activeEffect.rightFireball,
                time: timeInLoop,
                showStart: 1.0,
                showEnd: 5.0,
                spawnSmoke: true,
                smokeShown: &activeEffect.rightFireballSmokeShown
            )
            let shouldTrack = timeInLoop < 1.0
            setTracking(activeEffect.rightFireball, isTracking: shouldTrack)
        case .fireballFollowRight:
            updateFireballLifecycle(
                activeEffect.rightFireball,
                time: timeInLoop,
                showStart: 1.0,
                showEnd: 5.0,
                spawnSmoke: true,
                smokeShown: &activeEffect.rightFireballSmokeShown
            )
            setTracking(activeEffect.rightFireball, isTracking: true)
        case .fireballPunchRight:
            // Calculate delta time for projectile updates
            let deltaTime = Float(animationTime - lastUpdateTime)
            lastUpdateTime = animationTime

            // Fireball visible until punch at 3.66s (unless already launched)
            let punchTime: TimeInterval = 3.66
            if !activeEffect.projectileLaunched {
                updateFireballLifecycle(
                    activeEffect.rightFireball,
                    time: timeInLoop,
                    showStart: 1.0,
                    showEnd: punchTime,
                    despawnAnimation: false,
                    spawnSmoke: false,
                    smokeShown: &activeEffect.rightFireballSmokeShown
                )
            } else {
                setVisibility(activeEffect.rightFireball, isVisible: false)
            }

            // Launch at punch time
            if timeInLoop >= punchTime && !activeEffect.projectileLaunched {
                if let fireball = activeEffect.rightFireball {
                    let launchPosition = fireball.position(relativeTo: tutorialContainer)
                    let launchDirection = launchDirection(from: handTargets.right, animationTime: animationTime)
                    launchProjectile(from: launchPosition, direction: launchDirection, sourceFireball: fireball)
                }
            }

            // Update projectile if launched
            if activeEffect.projectileLaunched {
                _ = updateProjectile(deltaTime: max(0.001, deltaTime))
            }

            let shouldTrack = timeInLoop < 1.0 || timeInLoop >= punchTime
            setTracking(activeEffect.rightFireball, isTracking: shouldTrack)
        case .fireballCrossPunchBoth:
            // Calculate delta time for projectile updates
            let deltaTime = Float(animationTime - lastUpdateTime)
            lastUpdateTime = animationTime

            // Fireball visible until cross-punch at 2.33s (unless already launched)
            let punchTime: TimeInterval = 2.33
            if !activeEffect.projectileLaunched {
                updateFireballLifecycle(
                    activeEffect.rightFireball,
                    time: timeInLoop,
                    showStart: 1.0,
                    showEnd: punchTime,
                    despawnAnimation: false,
                    spawnSmoke: false,
                    smokeShown: &activeEffect.rightFireballSmokeShown
                )
            } else {
                setVisibility(activeEffect.rightFireball, isVisible: false)
            }

            // Launch at punch time
            if timeInLoop >= punchTime && !activeEffect.projectileLaunched {
                if let fireball = activeEffect.rightFireball {
                    let launchPosition = fireball.position(relativeTo: tutorialContainer)
                    let launchDirection = launchDirection(from: handTargets.left, fallback: handTargets.right, animationTime: animationTime)
                    launchProjectile(from: launchPosition, direction: launchDirection, sourceFireball: fireball)
                }
            }

            // Update projectile if launched
            if activeEffect.projectileLaunched {
                _ = updateProjectile(deltaTime: max(0.001, deltaTime))
            }

            setTracking(activeEffect.rightFireball, isTracking: true)
        case .fireballCombineBoth:
            let combineTime: TimeInterval = 1.33
            updateFireballLifecycle(
                activeEffect.leftFireball,
                time: timeInLoop,
                showStart: 1.0,
                showEnd: combineTime,
                spawnSmoke: false,
                smokeShown: &activeEffect.leftFireballSmokeShown
            )
            updateFireballLifecycle(
                activeEffect.rightFireball,
                time: timeInLoop,
                showStart: 1.0,
                showEnd: combineTime,
                spawnSmoke: false,
                smokeShown: &activeEffect.rightFireballSmokeShown
            )
            updateFireballLifecycle(
                activeEffect.combinedFireball,
                time: timeInLoop,
                showStart: combineTime,
                showEnd: 5.33,
                spawnSmoke: false,
                smokeShown: &activeEffect.combinedFireballSmokeShown
            )
            setTracking(activeEffect.leftFireball, isTracking: true)
            setTracking(activeEffect.rightFireball, isTracking: true)
            setTracking(activeEffect.combinedFireball, isTracking: true)

            // Show combine flash at the moment of combination
            if timeInLoop >= combineTime && !activeEffect.combineFlashShown {
                if let flash = activeEffect.combineFlash,
                   let rightFireball = activeEffect.rightFireball {
                    // Position flash at the combined fireball location (right hand)
                    flash.position = rightFireball.position(relativeTo: tutorialContainer)
                    flash.isEnabled = true
                    activeEffect.combineFlashShown = true

                    // Auto-disable flash after effect completes
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.5))
                        flash.isEnabled = false
                    }
                }
            }
        case .flamethrowerSummonRight:
            let show = timeInRange(timeInLoop, start: 1.0, end: 4.0)
            setVisibility(activeEffect.rightFlamethrower, isVisible: show)
        case .flamethrowerCombineBoth:
            let combineTime: TimeInterval = 3.0
            let splitTime: TimeInterval = 5.0
            let separate = timeInRange(timeInLoop, start: 1.0, end: combineTime)
                || timeInRange(timeInLoop, start: splitTime, end: 7.0)
            let combined = timeInRange(timeInLoop, start: combineTime, end: splitTime)
            setVisibility(activeEffect.leftFlamethrower, isVisible: separate)
            setVisibility(activeEffect.rightFlamethrower, isVisible: separate)
            setVisibility(activeEffect.combinedFlamethrower, isVisible: combined)

            // Show combine flash at t=3.0
            if timeInLoop >= combineTime && !activeEffect.flamethrowerCombineFlashShown {
                if let flash = activeEffect.flamethrowerCombineFlash,
                   let rightFlamethrower = activeEffect.rightFlamethrower {
                    flash.position = rightFlamethrower.position(relativeTo: tutorialContainer)
                    flash.isEnabled = true
                    activeEffect.flamethrowerCombineFlashShown = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.5))
                        flash.isEnabled = false
                    }
                }
            }

            // Show split flash at t=5.0
            if timeInLoop >= splitTime && !activeEffect.flamethrowerSplitFlashShown {
                if let flash = activeEffect.flamethrowerCombineFlash,
                   let rightFlamethrower = activeEffect.rightFlamethrower {
                    flash.position = rightFlamethrower.position(relativeTo: tutorialContainer)
                    flash.isEnabled = true
                    activeEffect.flamethrowerSplitFlashShown = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.5))
                        flash.isEnabled = false
                    }
                }
            }
        case .wallSummonBoth:
            guard let wallTime = wallAnimationTime(timeInLoop: timeInLoop, duration: duration) else {
                setWallVisible(false)
                break
            }
            let isVisible = wallTime < 4.0
            setWallVisible(isVisible)
            let height: Float
            if wallTime < 1.0 {
                let t = segmentProgress(time: wallTime, start: 0, end: 1.0)
                height = lerp(from: wallMinHeight, to: wallEmberHeight, t: t)
            } else if wallTime < 2.66 {
                height = wallEmberHeight
            } else {
                let t = segmentProgress(time: wallTime, start: 2.66, end: 4.0)
                height = lerp(from: wallEmberHeight, to: wallMinHeight, t: t)
            }
            updateWall(width: wallBaseWidth, height: height)
            applyWallTransformFromHands(animationTime: animationTime)
        case .wallHeightBoth:
            guard let wallTime = wallAnimationTime(timeInLoop: timeInLoop, duration: duration) else {
                setWallVisible(false)
                break
            }
            let isVisible = wallTime < 5.0
            setWallVisible(isVisible)
            let highHeight = wallBaseHeight * wallHeightHighScale
            let lowHeight = wallBaseHeight * wallHeightLowScale
            let height: Float
            if wallTime < 1.0 {
                let t = segmentProgress(time: wallTime, start: 0, end: 1.0)
                height = lerp(from: wallMinHeight, to: wallBaseHeight, t: t)
            } else if wallTime < 2.0 {
                height = wallBaseHeight
            } else if wallTime < 3.0 {
                let t = segmentProgress(time: wallTime, start: 2.0, end: 3.0)
                height = lerp(from: wallBaseHeight, to: highHeight, t: t)
            } else if wallTime < 4.0 {
                let t = segmentProgress(time: wallTime, start: 3.0, end: 4.0)
                height = lerp(from: highHeight, to: lowHeight, t: t)
            } else {
                let t = segmentProgress(time: wallTime, start: 4.0, end: 5.0)
                height = lerp(from: lowHeight, to: wallMinHeight, t: t)
            }
            updateWall(width: wallBaseWidth, height: height)
            applyWallTransformFromHands(animationTime: animationTime)
        case .wallLocationBoth:
            guard let wallTime = wallAnimationTime(timeInLoop: timeInLoop, duration: duration) else {
                setWallVisible(false)
                break
            }
            let isVisible = wallTime < 6.0
            setWallVisible(isVisible)
            let rightOffset = SIMD3<Float>(wallMoveOffsetX, 0, 0)
            let backOffset = SIMD3<Float>(0, 0, -wallMoveOffsetZ)
            let leftForwardOffset = SIMD3<Float>(-wallMoveOffsetX, 0, wallMoveOffsetZ)
            var offset = SIMD3<Float>.zero
            var height = wallEmberHeight
            if wallTime < 1.0 {
                let t = segmentProgress(time: wallTime, start: 0, end: 1.0)
                height = lerp(from: wallMinHeight, to: wallEmberHeight, t: t)
            } else if wallTime < 2.0 {
                height = wallEmberHeight
            } else if wallTime < 3.0 {
                let t = segmentProgress(time: wallTime, start: 2.0, end: 3.0)
                offset = lerp(from: .zero, to: rightOffset, t: t)
            } else if wallTime < 4.0 {
                let t = segmentProgress(time: wallTime, start: 3.0, end: 4.0)
                offset = lerp(from: rightOffset, to: backOffset, t: t)
            } else if wallTime < 5.0 {
                let t = segmentProgress(time: wallTime, start: 4.0, end: 5.0)
                offset = lerp(from: backOffset, to: leftForwardOffset, t: t)
            } else {
                let t = segmentProgress(time: wallTime, start: 5.0, end: 6.0)
                offset = lerp(from: leftForwardOffset, to: .zero, t: t)
                height = lerp(from: wallEmberHeight, to: wallMinHeight, t: t)
            }
            updateWall(width: wallBaseWidth, height: height)
            applyWallTransformFromHands(animationTime: animationTime, positionOffset: offset)
        case .wallWidthBoth:
            guard let wallTime = wallAnimationTime(timeInLoop: timeInLoop, duration: duration) else {
                setWallVisible(false)
                break
            }
            let isVisible = wallTime < 6.0
            setWallVisible(isVisible)
            let wideWidth = wallBaseWidth * wallWidthWideScale
            let narrowWidth = wallBaseWidth * wallWidthNarrowScale
            var width = wallBaseWidth
            var height = wallEmberHeight
            if wallTime < 1.0 {
                let t = segmentProgress(time: wallTime, start: 0, end: 1.0)
                height = lerp(from: wallMinHeight, to: wallEmberHeight, t: t)
            } else if wallTime < 3.0 {
                let t = segmentProgress(time: wallTime, start: 1.0, end: 3.0)
                width = lerp(from: wallBaseWidth, to: wideWidth, t: t)
            } else if wallTime < 5.0 {
                let t = segmentProgress(time: wallTime, start: 3.0, end: 5.0)
                width = lerp(from: wideWidth, to: narrowWidth, t: t)
            } else {
                let t = segmentProgress(time: wallTime, start: 5.0, end: 6.0)
                width = lerp(from: narrowWidth, to: wallBaseWidth, t: t)
                height = lerp(from: wallEmberHeight, to: wallMinHeight, t: t)
            }
            updateWall(width: width, height: height)
            applyWallTransformFromHands(animationTime: animationTime)
        case .wallRotationBoth:
            guard let wallTime = wallAnimationTime(timeInLoop: timeInLoop, duration: duration) else {
                setWallVisible(false)
                break
            }
            let isVisible = wallTime < 6.0
            setWallVisible(isVisible)
            var height = wallEmberHeight
            if wallTime < 1.0 {
                let t = segmentProgress(time: wallTime, start: 0, end: 1.0)
                height = lerp(from: wallMinHeight, to: wallEmberHeight, t: t)
            } else if wallTime >= 5.0 {
                let t = segmentProgress(time: wallTime, start: 5.0, end: 6.0)
                height = lerp(from: wallEmberHeight, to: wallMinHeight, t: t)
            }
            var rotationOffset: Float = 0
            if wallTime >= 2.0 && wallTime < 3.0 {
                let t = segmentProgress(time: wallTime, start: 2.0, end: 3.0)
                rotationOffset = lerp(from: 0, to: wallRotationRadians, t: t)
            } else if wallTime >= 3.0 && wallTime < 4.0 {
                let t = segmentProgress(time: wallTime, start: 3.0, end: 4.0)
                rotationOffset = lerp(from: wallRotationRadians, to: -wallRotationRadians, t: t)
            } else if wallTime >= 4.0 && wallTime < 5.0 {
                let t = segmentProgress(time: wallTime, start: 4.0, end: 5.0)
                rotationOffset = lerp(from: -wallRotationRadians, to: 0, t: t)
            }
            updateWall(width: wallBaseWidth, height: height)
            applyWallTransformFromHands(animationTime: animationTime, rotationOffset: rotationOffset)
        case .wallConfirmBoth:
            guard let wallTime = wallAnimationTime(timeInLoop: timeInLoop, duration: duration) else {
                setWallVisible(false)
                break
            }
            let isVisible = wallTime < 5.0
            setWallVisible(isVisible)
            let highHeight = wallBaseHeight * wallHeightHighScale
            let height: Float
            if wallTime < 0.33 {
                let t = segmentProgress(time: wallTime, start: 0, end: 0.33)
                height = lerp(from: wallMinHeight, to: wallBaseHeight, t: t)
            } else if wallTime < 1.0 {
                height = wallBaseHeight
            } else if wallTime < 2.0 {
                let t = segmentProgress(time: wallTime, start: 1.0, end: 2.0)
                height = lerp(from: wallBaseHeight, to: highHeight, t: t)
            } else if wallTime < 3.66 {
                height = highHeight
            } else {
                let t = segmentProgress(time: wallTime, start: 3.66, end: 5.0)
                height = lerp(from: highHeight, to: wallMinHeight, t: t)
            }
            updateWall(width: wallBaseWidth, height: height)
            // Wall starts blue (unconfirmed), turns red/orange after confirm at 3.33s
            let confirmed = wallTime >= 3.33 && wallTime < 5.0
            if let visual = activeEffect.wallVisual, height > wallEmberHeight {
                let palette = confirmed ? defaultFireWallPalette() : highlightFireWallPalette()
                applyFireWallPalette(visual, palette: palette)
            }
            applyWallTransformFromHands(animationTime: animationTime)
        }
    }

    private func updateWall(width: Float, height: Float) {
        updateWallVisuals(width: width, height: height)
    }

    private func updateWallVisuals(width: Float, height: Float) {
        let showEmbers = height <= wallEmberHeight

        if showEmbers {
            if let ember = activeEffect.wallEmberVisual {
                ember.root.isEnabled = true
                updateEmberLineEffect(ember, width: width)
            }
            activeEffect.wallRoot?.isEnabled = false
        } else {
            if let visual = activeEffect.wallVisual {
                visual.root.isEnabled = true
                updateFireWallEffect(visual, width: width, height: height)
            }
            activeEffect.wallEmberVisual?.root.isEnabled = false
        }
    }

    private func setWallVisible(_ isVisible: Bool) {
        activeEffect.wallRoot?.isEnabled = isVisible
        activeEffect.wallEmberVisual?.root.isEnabled = isVisible
    }

    private func wallAnimationTime(timeInLoop: TimeInterval, duration: TimeInterval) -> TimeInterval? {
        guard timeInLoop >= wallSpawnDelay else { return nil }
        let available = max(duration - wallSpawnDelay, 0.001)
        let wallTime = timeInLoop - wallSpawnDelay
        let scaledTime = min(wallTime * (duration / available), duration)
        return scaledTime
    }

    private func resetWallTransform() {
        activeEffect.wallRoot?.position = activeEffect.wallBasePosition
        activeEffect.wallEmberVisual?.root.position = activeEffect.wallBasePosition
        resetWallRotation()
    }

    private func resetWallRotation() {
        activeEffect.wallRoot?.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
        activeEffect.wallEmberVisual?.root.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
    }

    /// Calculates wall position and rotation from hand positions
    /// Returns (position, rotationAngle) or nil if hands aren't tracked
    private func calculateWallTransformFromHands(animationTime: TimeInterval) -> (position: SIMD3<Float>, angle: Float)? {
        // Get current hand positions from skeletal animation
        var leftPos: SIMD3<Float>?
        var rightPos: SIMD3<Float>?

        if let leftSkeletal = handTargets.left.skeletal,
           let transform = currentJointTransform(for: leftSkeletal, animationTime: animationTime) {
            leftPos = transform.translation
        }

        if let rightSkeletal = handTargets.right.skeletal,
           let transform = currentJointTransform(for: rightSkeletal, animationTime: animationTime) {
            rightPos = transform.translation
        }

        // Need both hands for wall positioning
        guard let left = leftPos, let right = rightPos else { return nil }

        // Calculate midpoint between hands
        let midpoint = (left + right) * 0.5

        // Wall position: at floor level (Y=0), in front of hands (Z offset from midpoint)
        let wallZOffset: Float = -0.3  // Wall spawns in front of hands
        let wallPosition = SIMD3<Float>(midpoint.x, 0, midpoint.z + wallZOffset)

        // Wall orientation: parallel to the line between hands
        let handDirection = right - left
        let angle = atan2(handDirection.z, handDirection.x)

        return (wallPosition, angle)
    }

    /// Applies wall transform from hands with optional position and rotation offsets
    private func applyWallTransformFromHands(animationTime: TimeInterval,
                                             positionOffset: SIMD3<Float> = .zero,
                                             rotationOffset: Float = 0) {
        guard activeEffect.wallTracksHands,
              let wallRoot = activeEffect.wallRoot,
              let (basePosition, baseAngle) = calculateWallTransformFromHands(animationTime: animationTime) else {
            return
        }

        wallRoot.position = basePosition + positionOffset
        wallRoot.transform.rotation = simd_quatf(angle: baseAngle + rotationOffset, axis: [0, 1, 0])
        if let emberRoot = activeEffect.wallEmberVisual?.root {
            emberRoot.position = basePosition + positionOffset
            emberRoot.transform.rotation = simd_quatf(angle: baseAngle + rotationOffset, axis: [0, 1, 0])
        }
    }

    private func updateEffectAnchors(animationTime: TimeInterval) {
        for attachment in effectAttachments {
            if attachment.isTracking {
                applyAnchor(attachment.anchor, to: attachment.effect, offset: attachment.offset, animationTime: animationTime, isFlamethrower: attachment.isFlamethrower)
            } else if let frozen = attachment.frozenTransform {
                attachment.effect.position = frozen.translation
                attachment.effect.orientation = frozen.rotation
                attachment.effect.scale = frozen.scale
            }
        }
    }

    private var applyAnchorDebugCounter = 0

    /// Rotation correction for flamethrower effects to align jet (+Z) with palm forward direction
    /// The flamethrower shoots along +Z, but the hand's orientation has +Z pointing sideways
    /// Apply a -90 degree rotation around Y to correct this
    private func flamethrowerRotationCorrection(for side: HandSide?) -> simd_quatf {
        let angle: Float = side == .left ? .pi / 2 : -.pi / 2
        return simd_quatf(angle: angle, axis: [0, 1, 0])
    }

    private func applyAnchor(_ anchor: HandAnchor, to effect: Entity, offset: SIMD3<Float>, animationTime: TimeInterval, isFlamethrower: Bool = false) {
        applyAnchorDebugCounter += 1

        // Debug every 30 calls (~1 second at 30fps)
        let shouldDebug = applyAnchorDebugCounter % 30 == 1

        if shouldDebug {
            print("[TutorialPlayback] applyAnchor called: hasSkeletal=\(anchor.skeletal != nil), animTime=\(animationTime), isFlamethrower=\(isFlamethrower)")
        }

        // PRIMARY: Use skeletal animation sampling - this is the ONLY way to track skinned mesh animations
        if let skeletal = anchor.skeletal {
            if let jointTransform = currentJointTransform(for: skeletal, animationTime: animationTime) {
                let baseRotation = jointTransform.rotation
                if isFlamethrower {
                    let correction = flamethrowerRotationCorrection(for: anchor.side)
                    let correctedRotation = baseRotation * correction
                    let rotatedOffset = correctedRotation.act(offset)
                    effect.position = jointTransform.translation + rotatedOffset
                    effect.orientation = correctedRotation
                } else {
                    let rotatedOffset = baseRotation.act(offset)
                    effect.position = jointTransform.translation + rotatedOffset
                    effect.orientation = baseRotation
                }

                if shouldDebug {
                    print("[TutorialPlayback] ✓ Applied skeletal transform: pos=\(effect.position)")
                }
                return
            } else if shouldDebug {
                print("[TutorialPlayback] ✗ currentJointTransform returned nil!")
            }
        }

        // FALLBACK: Use entity transform (static, won't animate)
        guard let target = anchor.target else {
            if shouldDebug {
                print("[TutorialPlayback] ✗ No target entity, skipping")
            }
            return
        }
        let worldTransform = target.transformMatrix(relativeTo: tutorialContainer)
        let transform = Transform(matrix: worldTransform)
        let baseRotation = transform.rotation
        if isFlamethrower {
            let correction = flamethrowerRotationCorrection(for: anchor.side)
            let correctedRotation = baseRotation * correction
            let rotatedOffset = correctedRotation.act(offset)
            effect.position = transform.translation + rotatedOffset
            effect.orientation = correctedRotation
        } else {
            let rotatedOffset = baseRotation.act(offset)
            effect.position = transform.translation + rotatedOffset
            effect.orientation = baseRotation
        }

        if shouldDebug {
            print("[TutorialPlayback] Used fallback entity transform: pos=\(effect.position)")
        }
    }

    private func updatePreviewBounds(animationTime: TimeInterval) {
        let bounds: (min: SIMD3<Float>, max: SIMD3<Float>)
        if let skeletalBounds = currentSkeletalBounds(animationTime: animationTime) {
            bounds = skeletalBounds
        } else {
            let fallback = rootEntity.visualBounds(relativeTo: rootEntity)
            bounds = (fallback.min, fallback.max)
        }

        if let currentMin = previewBoundsMin, let currentMax = previewBoundsMax {
            previewBoundsMin = SIMD3<Float>(
                min(currentMin.x, bounds.min.x),
                min(currentMin.y, bounds.min.y),
                min(currentMin.z, bounds.min.z)
            )
            previewBoundsMax = SIMD3<Float>(
                max(currentMax.x, bounds.max.x),
                max(currentMax.y, bounds.max.y),
                max(currentMax.z, bounds.max.z)
            )
        } else {
            previewBoundsMin = bounds.min
            previewBoundsMax = bounds.max
        }

        guard let unionMin = previewBoundsMin, let unionMax = previewBoundsMax else { return }
        let size = unionMax - unionMin + SIMD3<Float>(repeating: previewPadding)
        previewSize = clamp(size, min: previewMinSize, max: previewMaxSize)
    }

    private func removeActiveEffects() {
        let effectEntities: [Entity?] = [
            activeEffect.leftFireball,
            activeEffect.rightFireball,
            activeEffect.combinedFireball,
            activeEffect.leftFlamethrower,
            activeEffect.rightFlamethrower,
            activeEffect.combinedFlamethrower,
            activeEffect.wallRoot,
            activeEffect.wallEmberVisual?.root,
            activeEffect.launchedProjectile,
            activeEffect.projectileTrail,
            activeEffect.explosion,
            activeEffect.scorchMark,
            activeEffect.combineFlash,
            activeEffect.flamethrowerCombineFlash
        ]

        for effect in effectEntities.compactMap({ $0 }) {
            effect.removeFromParent()
        }
    }

    // MARK: - Projectile Launch System

    private let projectileSpeed: Float = 3.0  // Slower for tutorial visibility
    private let projectileGravity: Float = 1.5
    private let floorY: Float = -0.5  // Floor level in tutorial space

    /// Launches a fireball projectile from the given position in the given direction
    private func launchProjectile(from position: SIMD3<Float>, direction: SIMD3<Float>, sourceFireball: Entity?) {
        // Don't re-launch if already launched
        guard !activeEffect.projectileLaunched else { return }

        // Create a new fireball for the projectile (clone from source or create new)
        let projectile = createRealisticFireball(scale: fireballScale)
        projectile.position = position
        tutorialContainer.addChild(projectile)

        // Add fire trail
        let trail = createFireTrail()
        projectile.addChild(trail)

        // Set velocity (direction * speed)
        let normalizedDirection = simd_normalize(direction)
        activeEffect.projectileVelocity = normalizedDirection * projectileSpeed

        activeEffect.launchedProjectile = projectile
        activeEffect.projectileTrail = trail
        activeEffect.projectileLaunched = true

        print("[TutorialPlayback] Launched projectile from \(position) in direction \(normalizedDirection)")
    }

    /// Updates the projectile position based on velocity and gravity
    /// Returns true if projectile is still flying, false if it hit something
    private func updateProjectile(deltaTime: Float) -> Bool {
        guard activeEffect.projectileLaunched,
              let projectile = activeEffect.launchedProjectile else {
            return false
        }

        // Apply gravity to velocity
        activeEffect.projectileVelocity.y -= projectileGravity * deltaTime

        // Update position
        projectile.position += activeEffect.projectileVelocity * deltaTime

        // Check for floor collision
        if projectile.position.y <= floorY {
            // Hit the floor - create explosion
            let impactPosition = SIMD3<Float>(projectile.position.x, floorY, projectile.position.z)
            createImpactEffects(at: impactPosition)

            // Remove projectile
            projectile.removeFromParent()
            activeEffect.launchedProjectile = nil
            activeEffect.projectileTrail = nil

            return false
        }

        return true
    }

    /// Creates explosion and scorch mark at the impact position
    private func createImpactEffects(at position: SIMD3<Float>) {
        // Create explosion
        let explosion = createExplosionEffect(scale: 0.5)  // Smaller for tutorial
        explosion.position = position
        tutorialContainer.addChild(explosion)
        activeEffect.explosion = explosion

        // Create scorch mark on the floor
        let scorch = createScorchMark(scale: 0.5)  // Smaller for tutorial
        scorch.position = position
        // Rotate scorch mark to lie flat on the floor (XZ plane)
        scorch.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        tutorialContainer.addChild(scorch)
        activeEffect.scorchMark = scorch

        print("[TutorialPlayback] Created impact effects at \(position)")

        // Schedule cleanup of explosion after a delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.0))
            explosion.removeFromParent()
        }
    }

    /// Resets projectile state for loop restart
    private func resetProjectileState() {
        activeEffect.launchedProjectile?.removeFromParent()
        activeEffect.projectileTrail?.removeFromParent()
        activeEffect.explosion?.removeFromParent()
        activeEffect.scorchMark?.removeFromParent()

        activeEffect.launchedProjectile = nil
        activeEffect.projectileTrail = nil
        activeEffect.explosion = nil
        activeEffect.scorchMark = nil
        activeEffect.projectileVelocity = .zero
        activeEffect.projectileLaunched = false
    }

    private func updateFireballLifecycle(
        _ entity: Entity?,
        time: TimeInterval,
        showStart: TimeInterval,
        showEnd: TimeInterval,
        spawnAnimation: Bool = true,
        despawnAnimation: Bool = true,
        spawnSmoke: Bool,
        smokeShown: inout Bool
    ) {
        guard let entity, showStart < showEnd else { return }

        if time < showStart || time >= showEnd {
            setVisibility(entity, isVisible: false)
            entity.scale = SIMD3<Float>(repeating: fireballSpawnScale)
            return
        }

        setVisibility(entity, isVisible: true)

        let spawnEnd = spawnAnimation ? min(showStart + fireballSpawnDuration, showEnd) : showStart
        let despawnStart = despawnAnimation ? max(showEnd - fireballDespawnDuration, showStart) : showEnd

        var scale: Float = 1.0
        if spawnAnimation, time < spawnEnd {
            let t = segmentProgress(time: time, start: showStart, end: spawnEnd)
            scale = lerp(from: fireballSpawnScale, to: 1.0, t: t)
        } else if despawnAnimation, time >= despawnStart {
            let t = segmentProgress(time: time, start: despawnStart, end: showEnd)
            scale = lerp(from: 1.0, to: fireballDespawnScale, t: t)
            if spawnSmoke, !smokeShown {
                spawnSmokePuff(at: entity.position(relativeTo: tutorialContainer))
                smokeShown = true
            }
        }

        entity.scale = SIMD3<Float>(repeating: scale)
    }

    private func spawnSmokePuff(at position: SIMD3<Float>) {
        let smokePuff = createSmokePuff()
        smokePuff.position = position
        smokePuff.scale = [fireballSpawnScale, fireballSpawnScale, fireballSpawnScale]
        tutorialContainer.addChild(smokePuff)

        var smokeTransform = smokePuff.transform
        smokeTransform.scale = [1.0, 1.0, 1.0]
        smokePuff.move(to: smokeTransform, relativeTo: smokePuff.parent, duration: 0.25, timingFunction: .linear)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            if var emitter = smokePuff.components[ParticleEmitterComponent.self] {
                emitter.mainEmitter.birthRate = 0
                smokePuff.components.set(emitter)
            }
            try? await Task.sleep(for: .milliseconds(2500))
            smokePuff.removeFromParent()
        }
    }

    private func launchDirection(from primary: HandAnchor, fallback: HandAnchor? = nil, animationTime: TimeInterval) -> SIMD3<Float> {
        if let direction = sampledVelocityDirection(for: primary, animationTime: animationTime) {
            return direction
        }
        if let fallback, let direction = sampledVelocityDirection(for: fallback, animationTime: animationTime) {
            return direction
        }
        return SIMD3<Float>(0, 0, -1)
    }

    private func sampledVelocityDirection(for anchor: HandAnchor, animationTime: TimeInterval) -> SIMD3<Float>? {
        guard let skeletal = anchor.skeletal else { return nil }
        let sampleOffset = min(0.08, animationTime)
        guard let current = currentJointTransform(for: skeletal, animationTime: animationTime),
              let previous = currentJointTransform(for: skeletal, animationTime: max(0, animationTime - sampleOffset)) else {
            return nil
        }
        let delta = current.translation - previous.translation
        let length = simd_length(delta)
        guard length > 0.001 else { return nil }
        return simd_normalize(delta)
    }

    private func setVisibility(_ entity: Entity?, isVisible: Bool) {
        guard let entity else { return }
        entity.isEnabled = true
        entity.components.set(OpacityComponent(opacity: isVisible ? 1.0 : 0.0))
        setLightVisibility(in: entity, isEnabled: isVisible)
    }

    private func setLightVisibility(in entity: Entity, isEnabled: Bool) {
        for child in collectEntities(from: entity) {
            if child.components[PointLightComponent.self] != nil ||
                child.components[SpotLightComponent.self] != nil ||
                child.components[DirectionalLightComponent.self] != nil {
                child.isEnabled = isEnabled
            }
        }
    }

    private func updateFireballOffsetAttachments() {
        for index in effectAttachments.indices where effectAttachments[index].effect.name == "RealisticFireball" {
            effectAttachments[index].offset = fireballOffset
        }
    }

    private func resetLoopState() {
        for index in effectAttachments.indices {
            effectAttachments[index].isTracking = true
            effectAttachments[index].frozenTransform = nil
        }
        // Reset projectile state when loop restarts
        resetProjectileState()
        // Reset combine flash state
        activeEffect.combineFlashShown = false
        activeEffect.combineFlash?.isEnabled = false
        // Reset flamethrower combine flash state
        activeEffect.flamethrowerCombineFlashShown = false
        activeEffect.flamethrowerSplitFlashShown = false
        activeEffect.flamethrowerCombineFlash?.isEnabled = false
        // Reset fireball smoke flags and timing
        activeEffect.leftFireballSmokeShown = false
        activeEffect.rightFireballSmokeShown = false
        activeEffect.combinedFireballSmokeShown = false
        lastUpdateTime = 0
    }

    private func lerp(from: Float, to: Float, t: Float) -> Float {
        from + (to - from) * t
    }

    private func lerp(from: SIMD3<Float>, to: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        from + (to - from) * t
    }

    private func timeInRange(_ time: TimeInterval, start: TimeInterval, end: TimeInterval) -> Bool {
        time >= start && time < end
    }

    private func segmentProgress(time: TimeInterval, start: TimeInterval, end: TimeInterval) -> Float {
        guard end > start else { return 0 }
        let clamped = min(max(time, start), end)
        return Float((clamped - start) / (end - start))
    }

    private func entityCenterX(_ entity: Entity) -> Float {
        let bounds = entity.visualBounds(relativeTo: tutorialContainer)
        let center = (bounds.min + bounds.max) * 0.5
        return center.x
    }

    private func preferredJointIndex(for state: SkeletalAnimationState) -> Int? {
        let jointCount = state.jointNames.count
        guard jointCount > 0 else { return nil }

        let lowerNames = state.jointNames.map { $0.lowercased() }
        for (index, name) in lowerNames.enumerated() {
            if name.hasSuffix("/hand_r") || name == "hand_r" {
                return index
            }
        }
        for (index, name) in lowerNames.enumerated() where name.contains("hand_r_001") {
            return index
        }

        var childCounts = Array(repeating: 0, count: jointCount)
        for parent in state.parentIndices {
            if let parent, parent < childCounts.count {
                childCounts[parent] += 1
            }
        }

        var bestIndex = 0
        var bestCount = childCounts[0]
        for index in 1..<childCounts.count where childCounts[index] > bestCount {
            bestIndex = index
            bestCount = childCounts[index]
        }

        return bestIndex
    }

    private func clamp(_ value: SIMD3<Float>, min minValue: SIMD3<Float>, max maxValue: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            max(minValue.x, min(value.x, maxValue.x)),
            max(minValue.y, min(value.y, maxValue.y)),
            max(minValue.z, min(value.z, maxValue.z))
        )
    }

    private final class SkeletalAnimationState {
        let modelEntity: ModelEntity
        let sampledAnimation: SampledAnimation<JointTransforms>
        let jointNames: [String]
        let jointNameToIndex: [String: Int]
        let parentIndices: [Int?]
        let meshBounds: BoundingBox?
        let sideHint: HandSide?

        init(modelEntity: ModelEntity,
             sampledAnimation: SampledAnimation<JointTransforms>,
             jointNames: [String],
             jointNameToIndex: [String: Int],
             parentIndices: [Int?],
             meshBounds: BoundingBox?,
             sideHint: HandSide?) {
            self.modelEntity = modelEntity
            self.sampledAnimation = sampledAnimation
            self.jointNames = jointNames
            self.jointNameToIndex = jointNameToIndex
            self.parentIndices = parentIndices
            self.meshBounds = meshBounds
            self.sideHint = sideHint
        }
    }

    private func collectAnimations(from entity: Entity) -> [AnimationResource] {
        var animations: [AnimationResource] = []
        var seen = Set<ObjectIdentifier>()

        func addAnimations(_ newAnimations: [AnimationResource]) {
            for animation in newAnimations {
                let identifier = ObjectIdentifier(animation)
                if seen.insert(identifier).inserted {
                    animations.append(animation)
                }
            }
        }

        addAnimations(entity.availableAnimations)
        for child in entity.children {
            addAnimations(collectAnimations(from: child))
        }

        return animations
    }

    private func buildSkeletalStates(in entity: Entity, animations: [AnimationResource]) -> [SkeletalAnimationState] {
        print("[TutorialPlayback] Building skeletal states from \(animations.count) animations")

        // Try to extract SampledAnimation<JointTransforms> from each animation
        var sampledAnimations: [SampledAnimation<JointTransforms>] = []
        for (i, animation) in animations.enumerated() {
            let definition = animation.definition
            print("[TutorialPlayback] Animation \(i): definition type = \(type(of: definition))")

            if let sampled = definition as? SampledAnimation<JointTransforms> {
                print("[TutorialPlayback] ✓ Animation \(i) is SampledAnimation<JointTransforms> with \(sampled.jointNames.count) joints")
                print("[TutorialPlayback]   Joint names: \(sampled.jointNames)")
                print("[TutorialPlayback]   Frames: \(sampled.frames.count), duration: \(sampled.duration)")
                sampledAnimations.append(sampled)
            } else {
                print("[TutorialPlayback] ✗ Animation \(i) is NOT SampledAnimation<JointTransforms>")
            }
        }

        guard !sampledAnimations.isEmpty else {
            print("[TutorialPlayback] ✗ No sampled skeletal animations found!")
            return []
        }

        let modelEntities = collectEntities(from: entity).compactMap { $0 as? ModelEntity }
        print("[TutorialPlayback] Found \(modelEntities.count) model entities")

        var states: [SkeletalAnimationState] = []

        for modelEntity in modelEntities {
            guard let mesh = modelEntity.model?.mesh else {
                print("[TutorialPlayback] Model entity \(modelEntity.name) has no mesh")
                continue
            }

            let skeletons = mesh.contents.skeletons
            var skeletonCount = 0
            var iterator = skeletons.makeIterator()

            while let skeleton = iterator.next() {
                skeletonCount += 1
                print("[TutorialPlayback] Found skeleton with \(skeleton.joints.count) joints in \(modelEntity.name)")

                guard let sampled = bestSample(for: skeleton, samples: sampledAnimations) else {
                    print("[TutorialPlayback] ✗ No matching sampled animation for skeleton")
                    continue
                }

                let jointNames = sampled.jointNames
                let nameToIndex = Dictionary(uniqueKeysWithValues: jointNames.enumerated().map { ($1, $0) })
                let parentIndices = buildParentIndices(for: skeleton, jointNames: jointNames, sampledIndex: nameToIndex)
                let bounds = modelEntity.visualBounds(relativeTo: modelEntity)
                let hint = sideHint(for: modelEntity)

                let state = SkeletalAnimationState(
                    modelEntity: modelEntity,
                    sampledAnimation: sampled,
                    jointNames: jointNames,
                    jointNameToIndex: nameToIndex,
                    parentIndices: parentIndices,
                    meshBounds: bounds,
                    sideHint: hint
                )
                states.append(state)
                print("[TutorialPlayback] ✓ Created skeletal state for \(modelEntity.name)")
            }

            if skeletonCount == 0 {
                print("[TutorialPlayback] Model entity \(modelEntity.name) has no skeletons")
            }
        }

        print("[TutorialPlayback] Built \(states.count) skeletal states")
        return states
    }

    private func bestSample(for skeleton: MeshResource.Skeleton,
                            samples: [SampledAnimation<JointTransforms>]) -> SampledAnimation<JointTransforms>? {
        let jointNameSet = Set(skeleton.joints.map { $0.name.lowercased() })
        var bestSample: SampledAnimation<JointTransforms>?
        var bestMatch = 0

        for sample in samples {
            let matches = sample.jointNames.filter { jointNameSet.contains($0.lowercased()) }.count
            if matches > bestMatch {
                bestMatch = matches
                bestSample = sample
            }
        }

        return bestSample
    }

    private func buildParentIndices(for skeleton: MeshResource.Skeleton,
                                    jointNames: [String],
                                    sampledIndex: [String: Int]) -> [Int?] {
        let skeletonNameToIndex = Dictionary(uniqueKeysWithValues: skeleton.joints.enumerated().map { ($1.name, $0) })
        var parentIndices: [Int?] = Array(repeating: nil, count: jointNames.count)

        for (sampleIndex, name) in jointNames.enumerated() {
            guard let skeletonIndex = skeletonNameToIndex[name] else { continue }
            guard let parentSkeletonIndex = skeleton.joints[skeletonIndex].parentIndex else { continue }
            let parentName = skeleton.joints[parentSkeletonIndex].name
            parentIndices[sampleIndex] = sampledIndex[parentName]
        }

        return parentIndices
    }

    private var lastDebugTime: TimeInterval = -10  // Start negative so first call triggers debug

    private func currentJointTransform(for anchor: SkeletalAnchor, animationTime: TimeInterval) -> Transform? {
        let shouldDebug = animationTime - lastDebugTime > 1.0

        guard let jointTransforms = jointTransforms(for: anchor.state, animationTime: animationTime) else {
            if shouldDebug {
                print("[TutorialPlayback] ✗ jointTransforms returned nil at time \(animationTime)")
                print("[TutorialPlayback]   frames.count=\(anchor.state.sampledAnimation.frames.count)")
                lastDebugTime = animationTime
            }
            return nil
        }

        guard anchor.jointIndex < jointTransforms.count else {
            if shouldDebug {
                print("[TutorialPlayback] ✗ Joint index \(anchor.jointIndex) out of bounds (\(jointTransforms.count) joints)")
                lastDebugTime = animationTime
            }
            return nil
        }

        var cache = Array<simd_float4x4?>(repeating: nil, count: jointTransforms.count)
        let jointMatrix = jointGlobalMatrix(
            for: anchor.jointIndex,
            transforms: jointTransforms,
            parentIndices: anchor.state.parentIndices,
            cache: &cache
        )

        let modelMatrix = anchor.state.modelEntity.transformMatrix(relativeTo: tutorialContainer)
        let worldMatrix = simd_mul(modelMatrix, jointMatrix)
        let transform = Transform(matrix: worldMatrix)

        if shouldDebug {
            print("[TutorialPlayback] ✓ currentJointTransform success:")
            print("[TutorialPlayback]   animTime=\(animationTime), jointIndex=\(anchor.jointIndex)")
            print("[TutorialPlayback]   jointMatrix translation=\(SIMD3<Float>(jointMatrix.columns.3.x, jointMatrix.columns.3.y, jointMatrix.columns.3.z))")
            print("[TutorialPlayback]   worldMatrix translation=\(transform.translation)")
            lastDebugTime = animationTime
        }

        return transform
    }

    private func jointTransforms(for state: SkeletalAnimationState, animationTime: TimeInterval) -> JointTransforms? {
        let frames = state.sampledAnimation.frames
        guard !frames.isEmpty else { return nil }

        let frameInterval = max(state.sampledAnimation.frameInterval, 0.001)
        let duration = max(Float(state.sampledAnimation.duration), frameInterval * Float(frames.count))
        let timeInClip = Float(animationTime).truncatingRemainder(dividingBy: duration)
        let frameIndex = min(Int(timeInClip / frameInterval), frames.count - 1)
        return frames[frameIndex]
    }

    private func jointGlobalMatrix(for jointIndex: Int,
                                   transforms: JointTransforms,
                                   parentIndices: [Int?],
                                   cache: inout [simd_float4x4?]) -> simd_float4x4 {
        if let cached = cache[jointIndex] {
            return cached
        }

        var matrix = transforms[jointIndex].matrix
        if jointIndex < parentIndices.count, let parentIndex = parentIndices[jointIndex] {
            let parentMatrix = jointGlobalMatrix(
                for: parentIndex,
                transforms: transforms,
                parentIndices: parentIndices,
                cache: &cache
            )
            matrix = simd_mul(parentMatrix, matrix)
        }

        cache[jointIndex] = matrix
        return matrix
    }

    private func currentSkeletalBounds(animationTime: TimeInterval) -> (min: SIMD3<Float>, max: SIMD3<Float>)? {
        guard !skeletalStates.isEmpty else { return nil }

        var minPoint = SIMD3<Float>(repeating: Float.greatestFiniteMagnitude)
        var maxPoint = SIMD3<Float>(repeating: -Float.greatestFiniteMagnitude)
        var hasSamples = false

        for state in skeletalStates {
            guard let jointTransforms = jointTransforms(for: state, animationTime: animationTime) else { continue }
            let jointCount = min(jointTransforms.count, state.parentIndices.count)
            var cache = Array<simd_float4x4?>(repeating: nil, count: jointCount)
            let modelMatrix = state.modelEntity.transformMatrix(relativeTo: tutorialContainer)

            for jointIndex in 0..<jointCount {
                let jointMatrix = jointGlobalMatrix(
                    for: jointIndex,
                    transforms: jointTransforms,
                    parentIndices: state.parentIndices,
                    cache: &cache
                )
                let worldMatrix = simd_mul(modelMatrix, jointMatrix)
                let position = SIMD3<Float>(
                    worldMatrix.columns.3.x,
                    worldMatrix.columns.3.y,
                    worldMatrix.columns.3.z
                )
                minPoint = SIMD3<Float>(
                    min(minPoint.x, position.x),
                    min(minPoint.y, position.y),
                    min(minPoint.z, position.z)
                )
                maxPoint = SIMD3<Float>(
                    max(maxPoint.x, position.x),
                    max(maxPoint.y, position.y),
                    max(maxPoint.z, position.z)
                )
            }

            if let bounds = state.meshBounds {
                let extents = bounds.max - bounds.min
                let radius = max(extents.x, max(extents.y, extents.z)) * 0.5
                let padding = SIMD3<Float>(repeating: radius)
                minPoint -= padding
                maxPoint += padding
            }

            hasSamples = true
        }

        return hasSamples ? (minPoint, maxPoint) : nil
    }

    // MARK: - User Transform (Pinch/Drag)

    /// Applies user scale and offset to the tutorial container
    func applyUserTransform() {
        let clampedScale = max(0.3, min(3.0, userScale))
        tutorialContainer.scale = SIMD3<Float>(repeating: clampedScale)
        tutorialContainer.position = userOffset
    }

    /// Resets user transform to defaults
    func resetUserTransform() {
        userScale = 1.0
        userOffset = .zero
        applyUserTransform()
    }

    /// Updates user scale (from pinch gesture)
    func setUserScale(_ scale: Float) {
        userScale = max(0.3, min(3.0, scale))
        applyUserTransform()
    }

    /// Updates user offset (from drag gesture)
    func setUserOffset(_ offset: SIMD3<Float>) {
        userOffset = offset
        applyUserTransform()
    }
}
