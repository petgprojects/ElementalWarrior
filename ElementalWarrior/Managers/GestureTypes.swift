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
}

// MARK: - Per-Hand State

/// Tracks the state of a single hand including fireball, animations, and tracking
struct HandState {
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

    // Mega fireball state
    var isMegaFireball: Bool = false
    var suppressSpawnUntilRelease: Bool = false
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

    // Mega fireball constants
    static let fireballCombineDistance: Float = 0.15          // meters to combine fireballs
    static let megaFireballScale: Float = 2.0                 // scale multiplier for mega fireball
    static let megaExplosionScale: Float = 2.0                // scale multiplier for explosion
    static let megaScorchScale: Float = 2.0                   // scale multiplier for scorch mark
    static let megaAudioGainBoost: Double = 6.0               // dB boost for mega sounds
}
