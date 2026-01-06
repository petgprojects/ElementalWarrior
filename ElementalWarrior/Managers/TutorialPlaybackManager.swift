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
        switch category {
        case .fireball:
            return 4.0
        case .flamethrower:
            return 5.0
        case .wall:
            return 5.0
        }
    }
}

struct HandTutorial: Identifiable, Hashable {
    let kind: HandTutorialKind

    var id: String { kind.rawValue }
    var category: TutorialCategory { kind.category }
    var title: String { kind.title }
    var description: String { kind.description }
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

    private struct HandAnchor {
        var target: Entity?  // Fallback: bone entity (doesn't animate, but useful for initial position)
        var skeletal: SkeletalAnchor?  // Primary: sampled skeletal animation data
    }

    private struct SkeletalAnchor {
        let state: SkeletalAnimationState
        let jointIndex: Int
    }

    private struct HandTargets {
        var left: HandAnchor
        var right: HandAnchor
    }

    private struct EffectAttachment {
        var effect: Entity
        var anchor: HandAnchor
        var offset: SIMD3<Float>
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
        var wallBasePosition: SIMD3<Float> = .zero
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

    private let fireballOffset = SIMD3<Float>(0, 0.02, 0.05)
    private let flamethrowerOffset = SIMD3<Float>(0, 0, 0.07)
    private let fireballScale: Float = 0.35
    private let combinedFireballScale: Float = 0.52
    private let flamethrowerScale: Float = 0.55
    private let combinedFlamethrowerScale: Float = 0.7
    private let wallBaseWidth: Float = 0.7
    private let wallBaseHeight: Float = 0.7
    private let wallBaseOffset = SIMD3<Float>(0, -0.08, -0.2)
    private let baseStageScale: Float = 0.12
    private var currentStageScale: Float = 0.12
    private let stageOffset = SIMD3<Float>(0, 0, 0)
    private let previewPadding: Float = 0.08
    private let previewMinSize: SIMD3<Float> = [0.25, 0.25, 0.25]
    private let previewMaxSize: SIMD3<Float> = [1.8, 1.8, 1.8]
    private let windowVolume: Float = 1.2 // Usable volume inside 1.5m window (with margin)

    init() {
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

        guard let url = tutorial.resourceURL() else {
            lastError = "Missing tutorial asset: \(tutorial.id)"
            isPlaying = false
            return
        }

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

            let duration = tutorial.kind.loopDuration
            previewBoundsMin = nil
            previewBoundsMax = nil
            previewSize = [0.4, 0.4, 0.4]
            effectAttachments.removeAll()
            skeletalStates = buildSkeletalStates(in: entity, animations: animations)
            handTargets = resolveHandTargets(in: entity)
            activeEffect = configureEffects(for: tutorial, handTargets: handTargets)

            // Calculate appropriate scale to fit animation in window
            calculateAndApplyScale(for: entity, tutorial: tutorial)

            startEffectLoop(for: tutorial, duration: max(duration, 0.5))

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

    func stop(resetTutorial: Bool = false) {
        effectTask?.cancel()
        effectTask = nil

        for controller in animationControllers {
            controller.stop()
        }
        animationControllers.removeAll()

        tutorialContainer.children.forEach { $0.removeFromParent() }
        tutorialEntity = nil
        activeEffect = ActiveEffect()
        effectAttachments.removeAll()
        previewBoundsMin = nil
        previewBoundsMax = nil
        skeletalStates.removeAll()
        isPlaying = false

        // Reset stage scale to base
        currentStageScale = baseStageScale
        stageEntity.scale = [baseStageScale, baseStageScale, baseStageScale]

        if resetTutorial {
            currentTutorial = nil
            lastError = nil
        }
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

        // PRIMARY: Try to resolve skeletal anchors from sampled animation data
        // This is the ONLY reliable way to track skinned mesh animations
        if let skeletalLeft = resolveSkeletalAnchor(for: .left) {
            leftAnchor.skeletal = skeletalLeft
            print("[TutorialPlayback] ✓ Found LEFT skeletal anchor: joint \(skeletalLeft.jointIndex) in \(skeletalLeft.state.jointNames)")
        } else {
            print("[TutorialPlayback] ✗ No LEFT skeletal anchor found")
        }

        if let skeletalRight = resolveSkeletalAnchor(for: .right) {
            rightAnchor.skeletal = skeletalRight
            print("[TutorialPlayback] ✓ Found RIGHT skeletal anchor: joint \(skeletalRight.jointIndex) in \(skeletalRight.state.jointNames)")
        } else {
            print("[TutorialPlayback] ✗ No RIGHT skeletal anchor found")
        }

        // Debug: print skeletal states info
        print("[TutorialPlayback] Skeletal states count: \(skeletalStates.count)")
        for (i, state) in skeletalStates.enumerated() {
            print("[TutorialPlayback] State \(i): \(state.jointNames.count) joints, names: \(state.jointNames)")
        }

        // FALLBACK: Find bone entities (won't animate, but used for initial position if skeletal fails)
        let allEntities = collectEntities(from: entity)
        let boneEntities = allEntities.filter { !($0 is ModelEntity) && !$0.name.isEmpty }
        let handBoneNamesLeft = ["handsmooth_left", "hand_left", "hand_l", "hand.l", "lefthand", "l_hand", "wrist_left", "wrist_l"]
        let handBoneNamesRight = ["handsmooth_right", "hand_right", "hand_r", "hand.r", "righthand", "r_hand", "wrist_right", "wrist_r"]

        leftAnchor.target = findBestBoneEntity(from: boneEntities, boneNames: handBoneNamesLeft)
        rightAnchor.target = findBestBoneEntity(from: boneEntities, boneNames: handBoneNamesRight)

        print("[TutorialPlayback] Fallback bone entities: left=\(leftAnchor.target?.name ?? "nil"), right=\(rightAnchor.target?.name ?? "nil")")

        return HandTargets(left: leftAnchor, right: rightAnchor)
    }

    private func findBestBoneEntity(from entities: [Entity], boneNames: [String]) -> Entity? {
        for boneName in boneNames {
            for entity in entities {
                let entityName = entity.name.lowercased()
                if entityName == boneName || entityName.contains(boneName) {
                    return entity
                }
            }
        }
        return nil
    }

    private func collectEntities(from root: Entity) -> [Entity] {
        var result: [Entity] = [root]
        for child in root.children {
            result.append(contentsOf: collectEntities(from: child))
        }
        return result
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
        case .fireballCombineBoth:
            let leftFireball = createRealisticFireball(scale: fireballScale)
            let rightFireball = createRealisticFireball(scale: fireballScale)
            let combined = createRealisticFireball(scale: combinedFireballScale)
            effect.leftFireball = attachEffect(leftFireball, offset: fireballOffset, anchor: handTargets.left)
            effect.rightFireball = attachEffect(rightFireball, offset: fireballOffset, anchor: handTargets.right)
            effect.combinedFireball = attachEffect(combined, offset: fireballOffset, anchor: handTargets.right)
            registerAttachment(effect.leftFireball, anchor: handTargets.left, offset: fireballOffset)
            registerAttachment(effect.rightFireball, anchor: handTargets.right, offset: fireballOffset)
            registerAttachment(effect.combinedFireball, anchor: handTargets.right, offset: fireballOffset)
            effect.combinedFireball?.isEnabled = false
        case .flamethrowerSummonRight:
            let stream = createFlamethrowerStream(scale: flamethrowerScale, muzzleScale: 0.5, jetIntensityMultiplier: 1.0)
            effect.rightFlamethrower = attachEffect(stream, offset: flamethrowerOffset, anchor: handTargets.right)
            registerAttachment(effect.rightFlamethrower, anchor: handTargets.right, offset: flamethrowerOffset)
        case .flamethrowerCombineBoth:
            let leftStream = createFlamethrowerStream(scale: flamethrowerScale, muzzleScale: 0.5, jetIntensityMultiplier: 1.0)
            let rightStream = createFlamethrowerStream(scale: flamethrowerScale, muzzleScale: 0.5, jetIntensityMultiplier: 1.0)
            let combinedStream = createCombinedFlamethrowerStream(scale: combinedFlamethrowerScale)
            effect.leftFlamethrower = attachEffect(leftStream, offset: flamethrowerOffset, anchor: handTargets.left)
            effect.rightFlamethrower = attachEffect(rightStream, offset: flamethrowerOffset, anchor: handTargets.right)
            effect.combinedFlamethrower = attachEffect(combinedStream, offset: flamethrowerOffset, anchor: handTargets.right)
            registerAttachment(effect.leftFlamethrower, anchor: handTargets.left, offset: flamethrowerOffset)
            registerAttachment(effect.rightFlamethrower, anchor: handTargets.right, offset: flamethrowerOffset)
            registerAttachment(effect.combinedFlamethrower, anchor: handTargets.right, offset: flamethrowerOffset)
            effect.combinedFlamethrower?.isEnabled = false
        case .wallSummonBoth,
             .wallHeightBoth,
             .wallLocationBoth,
             .wallWidthBoth,
             .wallRotationBoth,
             .wallConfirmBoth:
            let visual = createFireWallEffect(width: wallBaseWidth, height: wallBaseHeight)
            applyFireWallPalette(visual, palette: defaultFireWallPalette())
            visual.root.position = wallBaseOffset
            tutorialContainer.addChild(visual.root)
            effect.wallVisual = visual
            effect.wallRoot = visual.root
            effect.wallBasePosition = wallBaseOffset
        }

        return effect
    }

    private func attachEffect(_ effect: Entity, offset: SIMD3<Float>, anchor: HandAnchor? = nil) -> Entity {
        // Always add to tutorialContainer - positioning is handled by updateEffectAnchors each frame
        effect.position = offset
        tutorialContainer.addChild(effect)
        return effect
    }

    private func registerAttachment(_ effect: Entity?, anchor: HandAnchor, offset: SIMD3<Float>) {
        guard let effect else { return }
        effectAttachments.append(EffectAttachment(effect: effect, anchor: anchor, offset: offset))
    }

    private func startEffectLoop(for tutorial: HandTutorial, duration: TimeInterval) {
        effectTask?.cancel()

        let startTime = CACurrentMediaTime()
        effectTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let elapsed = CACurrentMediaTime() - startTime
                let progress = Float((elapsed.truncatingRemainder(dividingBy: duration)) / duration)
                // Pass actual elapsed time for skeletal animation sampling
                self?.updateEffects(for: tutorial, progress: progress, elapsedTime: elapsed)
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private func updateEffects(for tutorial: HandTutorial, progress: Float, elapsedTime: TimeInterval = 0) {
        // Use our tracked elapsed time instead of controller time (which returns 0)
        let animationTime = elapsedTime
        updateEffectAnchors(animationTime: animationTime)
        updatePreviewBounds(animationTime: animationTime)

        switch tutorial.kind {
        case .fireballSummonRight:
            let visible = progress > 0.2 && progress < 0.75
            setVisibility(activeEffect.rightFireball, isVisible: visible)
        case .fireballMaintainRight,
             .fireballFollowRight,
             .fireballCrossPunchBoth:
            setVisibility(activeEffect.rightFireball, isVisible: true)
        case .fireballPunchRight:
            let visible = progress < 0.82
            setVisibility(activeEffect.rightFireball, isVisible: visible)
        case .fireballCombineBoth:
            let useCombined = progress > 0.55
            setVisibility(activeEffect.leftFireball, isVisible: !useCombined)
            setVisibility(activeEffect.rightFireball, isVisible: !useCombined)
            setVisibility(activeEffect.combinedFireball, isVisible: useCombined)
        case .flamethrowerSummonRight:
            setVisibility(activeEffect.rightFlamethrower, isVisible: true)
        case .flamethrowerCombineBoth:
            let combined = progress > 0.45 && progress < 0.75
            setVisibility(activeEffect.leftFlamethrower, isVisible: !combined)
            setVisibility(activeEffect.rightFlamethrower, isVisible: !combined)
            setVisibility(activeEffect.combinedFlamethrower, isVisible: combined)
        case .wallSummonBoth:
            let height = lerp(from: 0.15, to: wallBaseHeight, t: min(progress * 1.2, 1.0))
            updateWall(width: wallBaseWidth, height: height)
            resetWallTransform()
        case .wallHeightBoth:
            let phase = 2 * Float.pi * progress
            let height = wallBaseHeight * (0.6 + 0.4 * (0.5 + 0.5 * sin(phase)))
            updateWall(width: wallBaseWidth, height: height)
            resetWallTransform()
        case .wallLocationBoth:
            let phase = 2 * Float.pi * progress
            let offsetX = 0.15 * sin(phase)
            let offsetZ = 0.12 * cos(phase)
            updateWall(width: wallBaseWidth, height: wallBaseHeight)
            activeEffect.wallRoot?.position = activeEffect.wallBasePosition + SIMD3<Float>(offsetX, 0, offsetZ)
            resetWallRotation()
        case .wallWidthBoth:
            let phase = 2 * Float.pi * progress
            let width = wallBaseWidth * (0.6 + 0.6 * (0.5 + 0.5 * sin(phase)))
            updateWall(width: width, height: wallBaseHeight)
            resetWallTransform()
        case .wallRotationBoth:
            let phase = 2 * Float.pi * progress
            let angle = 0.55 * sin(phase)
            updateWall(width: wallBaseWidth, height: wallBaseHeight)
            activeEffect.wallRoot?.transform.rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
            activeEffect.wallRoot?.position = activeEffect.wallBasePosition
        case .wallConfirmBoth:
            let height = wallBaseHeight * min(0.4 + progress, 1.25)
            updateWall(width: wallBaseWidth, height: height)
            let palette = progress > 0.7 ? highlightFireWallPalette() : defaultFireWallPalette()
            if let visual = activeEffect.wallVisual {
                applyFireWallPalette(visual, palette: palette)
            }
            resetWallTransform()
        }
    }

    private func updateWall(width: Float, height: Float) {
        if let visual = activeEffect.wallVisual {
            updateFireWallEffect(visual, width: width, height: height)
        }
    }

    private func resetWallTransform() {
        activeEffect.wallRoot?.position = activeEffect.wallBasePosition
        resetWallRotation()
    }

    private func resetWallRotation() {
        activeEffect.wallRoot?.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
    }

    private func updateEffectAnchors(animationTime: TimeInterval) {
        for attachment in effectAttachments {
            applyAnchor(attachment.anchor, to: attachment.effect, offset: attachment.offset, animationTime: animationTime)
        }
    }

    private var applyAnchorDebugCounter = 0

    private func applyAnchor(_ anchor: HandAnchor, to effect: Entity, offset: SIMD3<Float>, animationTime: TimeInterval) {
        applyAnchorDebugCounter += 1

        // Debug every 30 calls (~1 second at 30fps)
        let shouldDebug = applyAnchorDebugCounter % 30 == 1

        if shouldDebug {
            print("[TutorialPlayback] applyAnchor called: hasSkeletal=\(anchor.skeletal != nil), animTime=\(animationTime)")
        }

        // PRIMARY: Use skeletal animation sampling - this is the ONLY way to track skinned mesh animations
        if let skeletal = anchor.skeletal {
            if let jointTransform = currentJointTransform(for: skeletal, animationTime: animationTime) {
                let rotatedOffset = jointTransform.rotation.act(offset)
                effect.position = jointTransform.translation + rotatedOffset
                effect.orientation = jointTransform.rotation

                if shouldDebug {
                    print("[TutorialPlayback] ✓ Applied skeletal transform: pos=\(effect.position)")
                }
                return
            } else if shouldDebug {
                print("[TutorialPlayback] ✗ currentJointTransform returned nil!")
            }
        }

        // FALLBACK: Use bone entity transform (static, won't animate)
        guard let target = anchor.target else {
            if shouldDebug {
                print("[TutorialPlayback] ✗ No target entity, skipping")
            }
            return
        }
        let worldTransform = target.transformMatrix(relativeTo: tutorialContainer)
        let transform = Transform(matrix: worldTransform)
        let rotatedOffset = transform.rotation.act(offset)
        effect.position = transform.translation + rotatedOffset
        effect.orientation = transform.rotation

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

    private func setVisibility(_ entity: Entity?, isVisible: Bool) {
        entity?.isEnabled = isVisible
    }

    private func lerp(from: Float, to: Float, t: Float) -> Float {
        from + (to - from) * t
    }

    private func pickSideEntity(from entities: [Entity], sideTokens: [String]) -> Entity? {
        for entity in entities {
            let name = hierarchyName(for: entity)
            if sideTokens.contains(where: { name.contains($0) }) {
                return entity
            }
        }
        return nil
    }

    private func hierarchyName(for entity: Entity) -> String {
        var components: [String] = []
        var current: Entity? = entity
        while let node = current {
            if !node.name.isEmpty {
                components.append(node.name.lowercased())
            }
            current = node.parent
        }
        return components.joined(separator: "/")
    }

    private func bestFallbackEntity(from entities: [Entity]) -> Entity? {
        let modelEntities = entities.filter { $0 is ModelEntity }
        if let firstModel = modelEntities.first {
            return firstModel
        }
        return entities.first
    }

    private func clamp(_ value: SIMD3<Float>, min minValue: SIMD3<Float>, max maxValue: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            max(minValue.x, min(value.x, maxValue.x)),
            max(minValue.y, min(value.y, maxValue.y)),
            max(minValue.z, min(value.z, maxValue.z))
        )
    }

    private enum HandSide {
        case left
        case right

        var nameToken: String {
            switch self {
            case .left:
                return "left"
            case .right:
                return "right"
            }
        }

        var suffixToken: String {
            switch self {
            case .left:
                return "_l"
            case .right:
                return "_r"
            }
        }
    }

    private final class SkeletalAnimationState {
        let modelEntity: ModelEntity
        let sampledAnimation: SampledAnimation<JointTransforms>
        let jointNames: [String]
        let jointNameToIndex: [String: Int]
        let parentIndices: [Int?]
        let meshBounds: BoundingBox?

        init(modelEntity: ModelEntity,
             sampledAnimation: SampledAnimation<JointTransforms>,
             jointNames: [String],
             jointNameToIndex: [String: Int],
             parentIndices: [Int?],
             meshBounds: BoundingBox?) {
            self.modelEntity = modelEntity
            self.sampledAnimation = sampledAnimation
            self.jointNames = jointNames
            self.jointNameToIndex = jointNameToIndex
            self.parentIndices = parentIndices
            self.meshBounds = meshBounds
        }
    }

    private func resolveSkeletalAnchor(for side: HandSide) -> SkeletalAnchor? {
        var bestAnchor: SkeletalAnchor?
        var bestScore = -1

        for state in skeletalStates {
            guard let (jointIndex, jointScore) = pickJointIndex(for: side, in: state.jointNames) else { continue }
            let nameScore = hierarchyName(for: state.modelEntity).contains(side.nameToken) ? 2 : 0
            let totalScore = jointScore + nameScore
            if totalScore > bestScore {
                bestScore = totalScore
                bestAnchor = SkeletalAnchor(state: state, jointIndex: jointIndex)
            }
        }

        return bestAnchor
    }

    private func pickJointIndex(for side: HandSide, in jointNames: [String]) -> (Int, Int)? {
        var bestIndex: Int?
        var bestScore = -1
        let preferredSuffix = "hand\(side.suffixToken)"

        for (index, name) in jointNames.enumerated() {
            let lower = name.lowercased()
            var score = 0
            if lower.hasSuffix(preferredSuffix) || lower.hasSuffix("/" + preferredSuffix) {
                score += 6
            }
            if lower.contains("hand") {
                score += 2
            }
            if lower.contains(side.suffixToken) {
                score += 2
            }
            if lower.contains("wrist") {
                score += 1
            }
            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        guard let bestIndex, bestScore >= 3 else { return nil }
        return (bestIndex, bestScore)
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

                let state = SkeletalAnimationState(
                    modelEntity: modelEntity,
                    sampledAnimation: sampled,
                    jointNames: jointNames,
                    jointNameToIndex: nameToIndex,
                    parentIndices: parentIndices,
                    meshBounds: bounds
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
}
