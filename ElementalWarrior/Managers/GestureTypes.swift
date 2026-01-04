//
//  GestureTypes.swift
//  ElementalWarrior
//
//  Shared types and data structures for hand gesture recognition and state management.
//

import Foundation
import RealityKit
import simd

// MARK: - Hand Gesture State

/// Debug state for UI display showing what gesture is currently detected
enum HandGestureState: String {
    case none = "NONE"
    case fist = "FIST"
    case summon = "SUMMON"
    case holdingFireball = "HOLDING"
    case collision = "COLLISION"
    case flamethrower = "FLAME"
    case wallControl = "WALL"
}

// MARK: - Per-Hand State

/// Tracks the state of a single hand including fireball, animations, and tracking
struct HandState {
    var fireball: Entity?
    var isShowingFireball: Bool = false
    var isAnimating: Bool = false

    // Flamethrower stream state
    var flamethrower: Entity?
    var flamethrowerAudio: AudioPlaybackController?
    var isUsingFlamethrower: Bool = false
    var lastFlamethrowerScorchTime: TimeInterval = 0
    var lastFlamethrowerHitDistance: Float = GestureConstants.flamethrowerRange
    var lastFlamethrowerRaycastTime: TimeInterval = 0
    var flamethrowerDespawnTask: Task<Void, Never>?
    var isPartOfCombinedFlamethrower: Bool = false  // True when this hand's flamethrower is merged

    // Fields for throwing system
    var despawnTask: Task<Void, Never>?
    var lastPositions: [(position: SIMD3<Float>, timestamp: TimeInterval)] = []
    var isPendingDespawn: Bool = false
    var lastKnownPosition: SIMD3<Float>?
    var isTrackingLost: Bool = false  // Only true when ARKit tracking is actually lost

    // Audio controller for looping sounds
    var crackleController: AudioPlaybackController?

    // Mega fireball state
    var isMegaFireball: Bool = false
    var suppressSpawnUntilRelease: Bool = false
    var nextSummonAllowedTime: TimeInterval = 0
}

// MARK: - Projectile State

/// Tracks the state of a projectile in flight
struct ProjectileState {
    let entity: Entity
    let direction: SIMD3<Float>
    let startPosition: SIMD3<Float>
    let startTime: TimeInterval
    let speed: Float
    var trailEntity: Entity?
    var previousPosition: SIMD3<Float>  // Track previous position for raycast collision
    let isMegaFireball: Bool  // Whether this is a mega fireball for scaled effects
}

// MARK: - Cached Mesh Geometry

/// Stores extracted mesh geometry that persists even when ARKit removes the anchor.
/// This enables collision detection with surfaces that are no longer in LiDAR range.
struct CachedMeshGeometry {
    let id: UUID
    let transform: simd_float4x4
    let vertices: [SIMD3<Float>]
    let triangleIndices: [(UInt32, UInt32, UInt32)]  // Pre-extracted triangle indices
    var lastUpdated: Date
}

// MARK: - Timing Constants

/// Central configuration for timing and threshold constants
enum GestureConstants {
    static let despawnDelayDuration: TimeInterval = 1.5       // Time before despawn after gesture ends
    static let punchVelocityThreshold: Float = 0.3            // m/s minimum for punch detection
    static let punchProximityThreshold: Float = 0.20          // meters - max distance from fireball center
    static let fistExtensionThreshold: Float = 0.045          // meters - finger extension for closed fist
    static let velocityHistoryDuration: TimeInterval = 0.15   // seconds of position history to keep
    static let projectileSpeed: Float = 12.0                  // m/s flight speed
    static let maxProjectileRange: Float = 20.0               // meters before auto-explode
    static let trackingLostGraceDuration: TimeInterval = 2.0  // seconds grace period for tracking loss
    static let crossPunchResummonDelay: TimeInterval = 0.5   // delay before resummon after cross-punch

    // Mega fireball constants
    static let fireballCombineDistance: Float = 0.15          // meters to combine fireballs
    static let megaFireballScale: Float = 2.0                 // scale multiplier for mega fireball
    static let megaExplosionScale: Float = 2.0                // scale multiplier for explosion
    static let megaScorchScale: Float = 2.0                   // scale multiplier for scorch mark
    static let megaAudioGainBoost: Double = 6.0               // dB boost for mega sounds

    // Flamethrower constants
    static let flamethrowerRange: Float = 8.0                 // meters max flame reach
    static let flamethrowerForwardDotThreshold: Float = 0.28  // palm alignment with gaze (lower = more forgiving)
    static let flamethrowerUpRejectThreshold: Float = 0.6     // allow more tilt before rejecting
    static let flamethrowerScorchCooldown: TimeInterval = 0.35 // seconds between scorch spawns
    static let flamethrowerScorchScale: Float = 0.55          // default scorch size for flame hits
    static let flamethrowerScorchLifetime: TimeInterval = 6.0 // seconds before scorch fades
    static let flamethrowerRaycastInterval: TimeInterval = 0.04 // seconds between beam raycasts (per hand)
    static let flamethrowerTrackingGraceDuration: TimeInterval = 0.5 // seconds before despawn after tracking loss

    // Combined flamethrower constants
    static let flamethrowerCombineDistance: Float = 0.15      // meters to combine flamethrowers (same as fireballs)
    static let flamethrowerSplitDistance: Float = 0.25        // meters to split combined flamethrower (larger for hysteresis)
    static let combinedFlamethrowerJetIntensity: Float = 1.5  // jet intensity multiplier when combined
    static let combinedFlamethrowerMuzzleScale: Float = 1.0   // full-size muzzle when combined (vs 0.5 for single)
    static let combinedFlamethrowerAudioBoost: Double = 3.0   // dB boost for combined flamethrower sound

    // Wall of fire constants
    static let zombiePosePalmDownDotThreshold: Float = -0.2   // palm normal dot with world up for palms-down
    static let zombiePoseMinForwardDistance: Float = 0.12     // meters in front of head for zombie pose
    static let zombiePoseMinDownAngleDegrees: Float = 45.0    // degrees from world-down to require arms extended
    static let zombiePoseUpdateWindow: TimeInterval = 0.25    // seconds between both hand updates
    static let wallControlGraceDuration: TimeInterval = 0.25  // seconds of grace for pose flicker
    static let wallConfirmHoldDuration: TimeInterval = 0.12   // seconds of both fists to confirm/cancel
    static let wallPlacementMinWidth: Float = 0.4             // meters minimum wall width
    static let wallPlacementMaxWidth: Float = 3.5             // meters maximum wall width
    static let wallPlacementSmoothing: Float = 0.25           // smoothing factor for ember line updates
    static let wallPlacementMoveScale: Float = 3.5            // scaling factor for ember line translation
    static let wallPlacementWidthScale: Float = 3.0           // scaling factor for ember line width
    static let wallPlacementRotationScale: Float = 2.0        // radians per meter for wall rotation
    static let wallPlacementRotationMaxRadians: Float = 1.2   // max rotation in either direction
    static let wallEmberOffset: Float = 0.01                  // meters above ground for embers
    static let wallPlacementMaxDistance: Float = 6.0          // meters for gaze placement raycast
    static let wallRaiseStartThreshold: Float = 0.12          // meters above base to start wall growth
    static let wallHeightScale: Float = 7.0                   // meters of wall per meter of hand raise
    static let wallMinHeight: Float = 0.4                     // meters minimum wall height
    static let wallEmberHeight: Float = 0.12                  // meters considered ember height for despawn
    static let wallMaxHeight: Float = 3.2                     // meters maximum wall height
    static let wallHeightReferenceLowOffset: Float = -0.25    // meters below device position for 0% height
    static let wallHeightReferenceHighOffset: Float = 0.08    // meters above device position for 100% height
    static let wallHeightMinSnapThreshold: Float = 0.2        // normalized range to snap to minimum height
    static let wallFinalizeDropThreshold: Float = 0.1         // meters below base to lock wall height
    static let wallRemovalDropThreshold: Float = 0.12         // meters below base to drop wall
    static let wallSelectionMaxDistance: Float = 6.0          // meters max gaze selection distance
    static let wallSelectionHoldDuration: TimeInterval = 0.5  // seconds to gaze before selection highlight
}
