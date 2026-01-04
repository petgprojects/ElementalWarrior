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
    case fireWall = "FIREWALL"
}

// MARK: - Fire Wall Color State

/// Color state for fire walls indicating their mode
enum FireWallColorState {
    case blue       // Spawning/editing mode
    case redOrange  // Confirmed (locked in place)
    case green      // Selected for editing (gaze dwell)
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

// MARK: - Fire Wall State

/// Tracks the state of a fire wall entity
struct FireWallState {
    let id: UUID
    var entity: Entity?
    var position: SIMD3<Float>       // Center position on floor
    var rotation: Float              // Rotation angle in radians
    var width: Float                 // Wall length
    var height: Float                // Wall height (0-1 normalized, maps to actual meters)
    var colorState: FireWallColorState
    var isAnimating: Bool = false
    var isEditing: Bool = false
    var creationTime: TimeInterval
    var lastModifiedTime: TimeInterval
    var audioController: AudioPlaybackController?

    /// Whether the wall is at minimum height (embers only, will despawn on confirm)
    var isEmbersOnly: Bool { height < 0.05 }
}

/// State for the current fire wall editing session
struct FireWallEditingState {
    var isActive: Bool = false
    var currentWall: UUID?           // Wall being created or edited
    var isCreatingNew: Bool = false  // true if creating, false if editing existing
    var lastLeftHandPosition: SIMD3<Float>?
    var lastRightHandPosition: SIMD3<Float>?
    var initialWallWidth: Float?
    var initialWallRotation: Float?
    var baseUserRotation: Float = 0  // User's rotation when wall was created
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

    // Fire Wall constants
    static let fireWallDefaultWidth: Float = 1.5              // meters default wall length
    static let fireWallMinWidth: Float = 0.20                 // meters minimum (20cm)
    static let fireWallMaxWidth: Float = 4.0                  // meters maximum
    static let fireWallMaxHeight: Float = 2.5                 // meters at 100% height
    static let fireWallMaxCount: Int = 3                      // maximum confirmed walls
    static let fireWallSpawnDistance: Float = 2.0             // meters in front of user for gaze spawn

    // Zombie pose thresholds
    static let zombiePalmDownDotThreshold: Float = 0.5        // palm normal alignment with world down
    static let zombieArmExtensionMinDistance: Float = 0.35    // meters forward from chest
    static let zombieHandHeightChestOffset: Float = -0.30     // meters below head for min height (chest)
    static let zombieHandHeightEyeOffset: Float = 0.0         // meters relative to head for max height (eye)

    // Fire wall rotation control
    static let fireWallMaxRotation: Float = Float.pi / 2      // +/- 90 degrees max rotation
    static let fireWallRotationSensitivity: Float = 2.0       // multiplier for hand offset to rotation

    // Fire wall selection and confirmation
    static let fireWallGazeDwellDuration: TimeInterval = 0.5  // seconds to select via gaze
    static let fireWallFistConfirmWindow: TimeInterval = 0.2  // 200ms simultaneous fist tolerance
    static let fireWallGazeSelectionRadius: Float = 0.5       // meters from wall center for gaze selection
}
