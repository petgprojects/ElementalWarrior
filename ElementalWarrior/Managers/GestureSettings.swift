//
//  GestureSettings.swift
//  ElementalWarrior
//
//  Tunable gesture and effect settings backed by GestureConstants.
//

import SwiftUI

@MainActor
@Observable
final class GestureSettings {
    // Fireball values
    var despawnDelayDuration: Double { didSet { GestureConstants.despawnDelayDuration = despawnDelayDuration } }
    var punchVelocityThreshold: Double { didSet { GestureConstants.punchVelocityThreshold = Float(punchVelocityThreshold) } }
    var punchProximityThreshold: Double { didSet { GestureConstants.punchProximityThreshold = Float(punchProximityThreshold) } }
    var fistExtensionThreshold: Double { didSet { GestureConstants.fistExtensionThreshold = Float(fistExtensionThreshold) } }
    var velocityHistoryDuration: Double { didSet { GestureConstants.velocityHistoryDuration = velocityHistoryDuration } }
    var projectileSpeed: Double { didSet { GestureConstants.projectileSpeed = Float(projectileSpeed) } }
    var maxProjectileRange: Double { didSet { GestureConstants.maxProjectileRange = Float(maxProjectileRange) } }
    var trackingLostGraceDuration: Double { didSet { GestureConstants.trackingLostGraceDuration = trackingLostGraceDuration } }
    var crossPunchResummonDelay: Double { didSet { GestureConstants.crossPunchResummonDelay = crossPunchResummonDelay } }
    var fireballCombineDistance: Double { didSet { GestureConstants.fireballCombineDistance = Float(fireballCombineDistance) } }
    var megaFireballScale: Double { didSet { GestureConstants.megaFireballScale = Float(megaFireballScale) } }
    var megaExplosionScale: Double { didSet { GestureConstants.megaExplosionScale = Float(megaExplosionScale) } }
    var megaScorchScale: Double { didSet { GestureConstants.megaScorchScale = Float(megaScorchScale) } }
    var megaAudioGainBoost: Double { didSet { GestureConstants.megaAudioGainBoost = megaAudioGainBoost } }

    // Flamethrower values
    var flamethrowerRange: Double { didSet { GestureConstants.flamethrowerRange = Float(flamethrowerRange) } }
    var flamethrowerForwardDotThreshold: Double { didSet { GestureConstants.flamethrowerForwardDotThreshold = Float(flamethrowerForwardDotThreshold) } }
    var flamethrowerUpRejectThreshold: Double { didSet { GestureConstants.flamethrowerUpRejectThreshold = Float(flamethrowerUpRejectThreshold) } }
    var flamethrowerScorchCooldown: Double { didSet { GestureConstants.flamethrowerScorchCooldown = flamethrowerScorchCooldown } }
    var flamethrowerScorchScale: Double { didSet { GestureConstants.flamethrowerScorchScale = Float(flamethrowerScorchScale) } }
    var flamethrowerScorchLifetime: Double { didSet { GestureConstants.flamethrowerScorchLifetime = flamethrowerScorchLifetime } }
    var flamethrowerRaycastInterval: Double { didSet { GestureConstants.flamethrowerRaycastInterval = flamethrowerRaycastInterval } }
    var flamethrowerTrackingGraceDuration: Double { didSet { GestureConstants.flamethrowerTrackingGraceDuration = flamethrowerTrackingGraceDuration } }
    var flamethrowerCombineDistance: Double { didSet { GestureConstants.flamethrowerCombineDistance = Float(flamethrowerCombineDistance) } }
    var flamethrowerSplitDistance: Double { didSet { GestureConstants.flamethrowerSplitDistance = Float(flamethrowerSplitDistance) } }
    var combinedFlamethrowerJetIntensity: Double { didSet { GestureConstants.combinedFlamethrowerJetIntensity = Float(combinedFlamethrowerJetIntensity) } }
    var combinedFlamethrowerMuzzleScale: Double { didSet { GestureConstants.combinedFlamethrowerMuzzleScale = Float(combinedFlamethrowerMuzzleScale) } }
    var combinedFlamethrowerAudioBoost: Double { didSet { GestureConstants.combinedFlamethrowerAudioBoost = combinedFlamethrowerAudioBoost } }

    // Wall of fire values
    var zombiePosePalmDownDotThreshold: Double { didSet { GestureConstants.zombiePosePalmDownDotThreshold = Float(zombiePosePalmDownDotThreshold) } }
    var zombiePoseMinForwardDistance: Double { didSet { GestureConstants.zombiePoseMinForwardDistance = Float(zombiePoseMinForwardDistance) } }
    var zombiePoseMinDownAngleDegrees: Double { didSet { GestureConstants.zombiePoseMinDownAngleDegrees = Float(zombiePoseMinDownAngleDegrees) } }
    var zombiePoseUpdateWindow: Double { didSet { GestureConstants.zombiePoseUpdateWindow = zombiePoseUpdateWindow } }
    var wallControlGraceDuration: Double { didSet { GestureConstants.wallControlGraceDuration = wallControlGraceDuration } }
    var wallConfirmHoldDuration: Double { didSet { GestureConstants.wallConfirmHoldDuration = wallConfirmHoldDuration } }
    var wallRearmCooldownDuration: Double { didSet { GestureConstants.wallRearmCooldownDuration = wallRearmCooldownDuration } }
    var wallPlacementMinWidth: Double { didSet { GestureConstants.wallPlacementMinWidth = Float(wallPlacementMinWidth) } }
    var wallPlacementMaxWidth: Double { didSet { GestureConstants.wallPlacementMaxWidth = Float(wallPlacementMaxWidth) } }
    var wallPlacementSmoothing: Double { didSet { GestureConstants.wallPlacementSmoothing = Float(wallPlacementSmoothing) } }
    var wallPlacementMoveScale: Double { didSet { GestureConstants.wallPlacementMoveScale = Float(wallPlacementMoveScale) } }
    var wallPlacementWidthScale: Double { didSet { GestureConstants.wallPlacementWidthScale = Float(wallPlacementWidthScale) } }
    var wallPlacementRotationScale: Double { didSet { GestureConstants.wallPlacementRotationScale = Float(wallPlacementRotationScale) } }
    var wallPlacementRotationMaxRadians: Double { didSet { GestureConstants.wallPlacementRotationMaxRadians = Float(wallPlacementRotationMaxRadians) } }
    var wallEmberOffset: Double { didSet { GestureConstants.wallEmberOffset = Float(wallEmberOffset) } }
    var wallPlacementMaxDistance: Double { didSet { GestureConstants.wallPlacementMaxDistance = Float(wallPlacementMaxDistance) } }
    var wallRaiseStartThreshold: Double { didSet { GestureConstants.wallRaiseStartThreshold = Float(wallRaiseStartThreshold) } }
    var wallHeightScale: Double { didSet { GestureConstants.wallHeightScale = Float(wallHeightScale) } }
    var wallMinHeight: Double { didSet { GestureConstants.wallMinHeight = Float(wallMinHeight) } }
    var wallEmberHeight: Double { didSet { GestureConstants.wallEmberHeight = Float(wallEmberHeight) } }
    var wallMaxHeight: Double { didSet { GestureConstants.wallMaxHeight = Float(wallMaxHeight) } }
    var wallHeightReferenceLowOffset: Double { didSet { GestureConstants.wallHeightReferenceLowOffset = Float(wallHeightReferenceLowOffset) } }
    var wallHeightReferenceHighOffset: Double { didSet { GestureConstants.wallHeightReferenceHighOffset = Float(wallHeightReferenceHighOffset) } }
    var wallHeightMinSnapThreshold: Double { didSet { GestureConstants.wallHeightMinSnapThreshold = Float(wallHeightMinSnapThreshold) } }
    var wallFinalizeDropThreshold: Double { didSet { GestureConstants.wallFinalizeDropThreshold = Float(wallFinalizeDropThreshold) } }
    var wallRemovalDropThreshold: Double { didSet { GestureConstants.wallRemovalDropThreshold = Float(wallRemovalDropThreshold) } }
    var wallSelectionMaxDistance: Double { didSet { GestureConstants.wallSelectionMaxDistance = Float(wallSelectionMaxDistance) } }
    var wallSelectionHoldDuration: Double { didSet { GestureConstants.wallSelectionHoldDuration = wallSelectionHoldDuration } }

    init() {
        despawnDelayDuration = GestureConstants.despawnDelayDuration
        punchVelocityThreshold = Double(GestureConstants.punchVelocityThreshold)
        punchProximityThreshold = Double(GestureConstants.punchProximityThreshold)
        fistExtensionThreshold = Double(GestureConstants.fistExtensionThreshold)
        velocityHistoryDuration = GestureConstants.velocityHistoryDuration
        projectileSpeed = Double(GestureConstants.projectileSpeed)
        maxProjectileRange = Double(GestureConstants.maxProjectileRange)
        trackingLostGraceDuration = GestureConstants.trackingLostGraceDuration
        crossPunchResummonDelay = GestureConstants.crossPunchResummonDelay
        fireballCombineDistance = Double(GestureConstants.fireballCombineDistance)
        megaFireballScale = Double(GestureConstants.megaFireballScale)
        megaExplosionScale = Double(GestureConstants.megaExplosionScale)
        megaScorchScale = Double(GestureConstants.megaScorchScale)
        megaAudioGainBoost = GestureConstants.megaAudioGainBoost

        flamethrowerRange = Double(GestureConstants.flamethrowerRange)
        flamethrowerForwardDotThreshold = Double(GestureConstants.flamethrowerForwardDotThreshold)
        flamethrowerUpRejectThreshold = Double(GestureConstants.flamethrowerUpRejectThreshold)
        flamethrowerScorchCooldown = GestureConstants.flamethrowerScorchCooldown
        flamethrowerScorchScale = Double(GestureConstants.flamethrowerScorchScale)
        flamethrowerScorchLifetime = GestureConstants.flamethrowerScorchLifetime
        flamethrowerRaycastInterval = GestureConstants.flamethrowerRaycastInterval
        flamethrowerTrackingGraceDuration = GestureConstants.flamethrowerTrackingGraceDuration
        flamethrowerCombineDistance = Double(GestureConstants.flamethrowerCombineDistance)
        flamethrowerSplitDistance = Double(GestureConstants.flamethrowerSplitDistance)
        combinedFlamethrowerJetIntensity = Double(GestureConstants.combinedFlamethrowerJetIntensity)
        combinedFlamethrowerMuzzleScale = Double(GestureConstants.combinedFlamethrowerMuzzleScale)
        combinedFlamethrowerAudioBoost = GestureConstants.combinedFlamethrowerAudioBoost

        zombiePosePalmDownDotThreshold = Double(GestureConstants.zombiePosePalmDownDotThreshold)
        zombiePoseMinForwardDistance = Double(GestureConstants.zombiePoseMinForwardDistance)
        zombiePoseMinDownAngleDegrees = Double(GestureConstants.zombiePoseMinDownAngleDegrees)
        zombiePoseUpdateWindow = GestureConstants.zombiePoseUpdateWindow
        wallControlGraceDuration = GestureConstants.wallControlGraceDuration
        wallConfirmHoldDuration = GestureConstants.wallConfirmHoldDuration
        wallRearmCooldownDuration = GestureConstants.wallRearmCooldownDuration
        wallPlacementMinWidth = Double(GestureConstants.wallPlacementMinWidth)
        wallPlacementMaxWidth = Double(GestureConstants.wallPlacementMaxWidth)
        wallPlacementSmoothing = Double(GestureConstants.wallPlacementSmoothing)
        wallPlacementMoveScale = Double(GestureConstants.wallPlacementMoveScale)
        wallPlacementWidthScale = Double(GestureConstants.wallPlacementWidthScale)
        wallPlacementRotationScale = Double(GestureConstants.wallPlacementRotationScale)
        wallPlacementRotationMaxRadians = Double(GestureConstants.wallPlacementRotationMaxRadians)
        wallEmberOffset = Double(GestureConstants.wallEmberOffset)
        wallPlacementMaxDistance = Double(GestureConstants.wallPlacementMaxDistance)
        wallRaiseStartThreshold = Double(GestureConstants.wallRaiseStartThreshold)
        wallHeightScale = Double(GestureConstants.wallHeightScale)
        wallMinHeight = Double(GestureConstants.wallMinHeight)
        wallEmberHeight = Double(GestureConstants.wallEmberHeight)
        wallMaxHeight = Double(GestureConstants.wallMaxHeight)
        wallHeightReferenceLowOffset = Double(GestureConstants.wallHeightReferenceLowOffset)
        wallHeightReferenceHighOffset = Double(GestureConstants.wallHeightReferenceHighOffset)
        wallHeightMinSnapThreshold = Double(GestureConstants.wallHeightMinSnapThreshold)
        wallFinalizeDropThreshold = Double(GestureConstants.wallFinalizeDropThreshold)
        wallRemovalDropThreshold = Double(GestureConstants.wallRemovalDropThreshold)
        wallSelectionMaxDistance = Double(GestureConstants.wallSelectionMaxDistance)
        wallSelectionHoldDuration = GestureConstants.wallSelectionHoldDuration
    }
}
