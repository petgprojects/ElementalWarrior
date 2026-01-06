//
//  TutorialPlaybackManager.swift
//  ElementalWarrior
//
//  Manages tutorial hand animation playback and companion VFX previews.
//

import SwiftUI
import RealityKit
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

    private struct HandTargets {
        var left: Entity?
        var right: Entity?
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

    private var animationController: AnimationPlaybackController?
    private var effectTask: Task<Void, Never>?
    private var tutorialEntity: Entity?
    private var activeEffect = ActiveEffect()

    private let fireballOffset = SIMD3<Float>(0, 0.02, 0.05)
    private let flamethrowerOffset = SIMD3<Float>(0, 0, 0.07)
    private let fireballScale: Float = 0.35
    private let combinedFireballScale: Float = 0.52
    private let flamethrowerScale: Float = 0.55
    private let combinedFlamethrowerScale: Float = 0.7
    private let wallBaseWidth: Float = 0.7
    private let wallBaseHeight: Float = 0.7
    private let wallBaseOffset = SIMD3<Float>(0, -0.08, -0.2)
    private let stageScale: Float = 0.25
    private let stageOffset = SIMD3<Float>(0, -0.06, -0.32)

    init() {
        rootEntity.name = "TutorialRoot"
        stageEntity.name = "TutorialStage"
        tutorialContainer.name = "TutorialContainer"

        rootEntity.addChild(stageEntity)
        stageEntity.addChild(tutorialContainer)

        stageEntity.position = stageOffset
        stageEntity.scale = [stageScale, stageScale, stageScale]

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

            let animation = entity.availableAnimations.first
            if let animation {
                let looping = animation.repeat()
                animationController = entity.playAnimation(looping, transitionDuration: 0.15, startsPaused: false)
            } else {
                lastError = "No animation found in \(tutorial.id)"
            }

            let duration = tutorial.kind.loopDuration
            let handTargets = resolveHandTargets(in: entity)
            activeEffect = configureEffects(for: tutorial, handTargets: handTargets)
            startEffectLoop(for: tutorial, duration: max(duration, 0.5))

            isPlaying = true
        } catch {
            lastError = "Failed to load \(tutorial.id): \(error.localizedDescription)"
            isPlaying = false
        }
    }

    func stop(resetTutorial: Bool = false) {
        effectTask?.cancel()
        effectTask = nil

        animationController?.stop()
        animationController = nil

        tutorialContainer.children.forEach { $0.removeFromParent() }
        tutorialEntity = nil
        activeEffect = ActiveEffect()
        isPlaying = false

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
        let allEntities = collectEntities(from: entity)
        var leftCandidates: [Entity] = []
        var rightCandidates: [Entity] = []
        var handCandidates: [Entity] = []

        for node in allEntities {
            let name = node.name.lowercased()
            if name.contains("hand") {
                handCandidates.append(node)
            }
            if name.contains("left") || name.contains("_l") || name.contains("l_") {
                leftCandidates.append(node)
            }
            if name.contains("right") || name.contains("_r") || name.contains("r_") {
                rightCandidates.append(node)
            }
        }

        let left = leftCandidates.first ?? handCandidates.first ?? entity
        let right = rightCandidates.first ?? handCandidates.first ?? entity

        return HandTargets(left: left, right: right)
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
            effect.rightFireball = attachEffect(fireball, preferredParent: handTargets.right, offset: fireballOffset)
        case .fireballCombineBoth:
            let leftFireball = createRealisticFireball(scale: fireballScale)
            let rightFireball = createRealisticFireball(scale: fireballScale)
            let combined = createRealisticFireball(scale: combinedFireballScale)
            effect.leftFireball = attachEffect(leftFireball, preferredParent: handTargets.left, offset: fireballOffset)
            effect.rightFireball = attachEffect(rightFireball, preferredParent: handTargets.right, offset: fireballOffset)
            effect.combinedFireball = attachEffect(combined, preferredParent: handTargets.right, offset: fireballOffset)
            effect.combinedFireball?.isEnabled = false
        case .flamethrowerSummonRight:
            let stream = createFlamethrowerStream(scale: flamethrowerScale, muzzleScale: 0.5, jetIntensityMultiplier: 1.0)
            effect.rightFlamethrower = attachEffect(stream, preferredParent: handTargets.right, offset: flamethrowerOffset)
        case .flamethrowerCombineBoth:
            let leftStream = createFlamethrowerStream(scale: flamethrowerScale, muzzleScale: 0.5, jetIntensityMultiplier: 1.0)
            let rightStream = createFlamethrowerStream(scale: flamethrowerScale, muzzleScale: 0.5, jetIntensityMultiplier: 1.0)
            let combinedStream = createCombinedFlamethrowerStream(scale: combinedFlamethrowerScale)
            effect.leftFlamethrower = attachEffect(leftStream, preferredParent: handTargets.left, offset: flamethrowerOffset)
            effect.rightFlamethrower = attachEffect(rightStream, preferredParent: handTargets.right, offset: flamethrowerOffset)
            effect.combinedFlamethrower = attachEffect(combinedStream, preferredParent: handTargets.right, offset: flamethrowerOffset)
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

    private func attachEffect(_ effect: Entity, preferredParent: Entity?, offset: SIMD3<Float>) -> Entity {
        let parent = preferredParent ?? tutorialContainer
        effect.position = offset
        parent.addChild(effect)
        return effect
    }

    private func startEffectLoop(for tutorial: HandTutorial, duration: TimeInterval) {
        effectTask?.cancel()

        let startTime = CACurrentMediaTime()
        effectTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let elapsed = CACurrentMediaTime() - startTime
                let progress = Float((elapsed.truncatingRemainder(dividingBy: duration)) / duration)
                self?.updateEffects(for: tutorial, progress: progress)
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private func updateEffects(for tutorial: HandTutorial, progress: Float) {
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

    private func setVisibility(_ entity: Entity?, isVisible: Bool) {
        entity?.isEnabled = isVisible
    }

    private func lerp(from: Float, to: Float, t: Float) -> Float {
        from + (to - from) * t
    }
}
