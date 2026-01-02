# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Important: Keep Documentation Updated

**CRITICAL**: Whenever you make significant changes to the codebase, you MUST update the README.md to reflect those changes. This includes:
- Adding new features or functionality
- Changing existing behavior or architecture
- Completing items from the development roadmap
- Removing or refactoring major components
- Fixing significant bugs that affect user experience

Always check if the README accurately reflects the current state of the project after your work is complete.

## Project Overview

Elemental Warrior is a VisionOS immersive experience inspired by Avatar: The Last Airbender. Players use hand gestures to control elemental bending and battle AI opponents in mixed reality.

## Build and Run Commands

```bash
# Open project in Xcode
open ElementalWarrior.xcodeproj

# Build from command line (requires xcode-select)
xcodebuild -project ElementalWarrior.xcodeproj -scheme ElementalWarrior -destination 'platform=visionOS Simulator,name=Apple Vision Pro'

# Build and run (use Cmd+R in Xcode or the Vision Pro simulator)
```

## Architecture Overview

### App Structure

The app uses a dual-space architecture:

1. **WindowGroup** (`home`): A plain-styled 1000x1000 window showing HomeView with navigation controls
2. **ImmersiveSpace** (`arena`): Full immersive environment using `.mixed` immersion style for hand tracking and gameplay

### Core Components

**HandTrackingManager** (Managers/HandTrackingManager.swift)
- Central system managing ARKit hand tracking, projectile launching, and collisions
- Uses `ARKitSession` with `HandTrackingProvider`, `WorldTrackingProvider`, and `SceneReconstructionProvider`
- Maintains independent `HandState` for left and right hands with intent-based delayed despawn
- Spawns/extinguishes fireballs based on hand gestures (open palm facing up)
- Punch detection: fist gesture + velocity threshold (1.5 m/s) to launch fireballs
- Cross-hand punch support (punch with opposite hand)
- Gaze-based targeting using device head direction
- Projectile flight at 12 m/s with 20m max range
- Distance-based collision with scene reconstruction meshes
- Transform pipeline: Joint space → Anchor space → World space

**Fire Effects** (Effects/FireEffects.swift)
- `createRealisticFireball()` - Multi-layered particle effect (4 layers)
- `createFireTrail()` - Trail effect for flying projectiles
- `createExplosionEffect()` - 5-layer explosion (flash, core, flame, outer, smoke)
- All effects include PointLight components for environmental lighting
- All particle properties scale proportionally for consistent visuals

### Hand Gesture Recognition

The system detects multiple gestures:

1. **Open Palm Facing Up** - Spawns fireball
   - Palm orientation: wrist -Y axis dot product >0.4 with world up
   - Hand openness: finger tip-to-knuckle distance >5cm

2. **Fist Detection** - For punch-to-throw
   - Finger extension <3.5cm threshold for index, middle, ring fingers

3. **Punch Detection** - Launches fireball
   - Fist + velocity >1.5 m/s + proximity within 15cm of fireball
   - Supports cross-hand punching (punch with opposite hand)

### Entity State Management

**Per-hand state tracking (HandState struct):**
- `fireball: Entity?` - Reference to active fireball
- `isShowingFireball: Bool` - Whether fireball is currently visible
- `isAnimating: Bool` - Prevents concurrent animations
- `despawnTask: Task<Void, Never>?` - Delayed despawn timer
- `lastPositions: [(position, timestamp)]` - Position history for velocity calculation
- `isPendingDespawn: Bool` - Fireball awaiting despawn (can still be punched)
- `lastKnownPosition: SIMD3<Float>?` - Position before tracking loss
- `isTrackingLost: Bool` - Whether hand tracking was lost

**State transitions:**
- Spawn: 0.5s scale animation (0.01 → 1.0)
- Delayed despawn: 1.5s grace period after gesture ends (fireball floats, can be punched)
- Extinguish: 0.1s shrink + smoke puff particle burst
- Force extinguish: Immediate removal with smoke (used when tracking is lost)
- Launch: Detach from hand, add trail effect, fly toward gaze at 12 m/s

### Smoke Puff System

When fireballs extinguish:
1. Fireball shrinks over 0.1s
2. Smoke puff entity spawns at same position
3. Particle emitter bursts for 150ms
4. Birth rate drops to 0 (stops new particles)
5. Existing particles fade over 2s lifespan
6. Entity cleanup after 2.3s total

## Key Implementation Patterns

### Async Hand Tracking Loop

```swift
for await update in handTracking.anchorUpdates {
    // Process each hand independently
    // Check tracking state, gesture recognition, position updates
}
```

### Transform Chain for Position

```swift
// Joint → Anchor space
let jointTransform = middleKnuckle.anchorFromJointTransform
// Anchor → World space
let worldTransform = anchor.originFromAnchorTransform * jointTransform
```

### Particle Emitter Configuration

All emitters use:
- `.additive` blend mode for glowing fire effect
- Color evolution from opaque start to transparent end (alpha fade)
- Noise/turbulence for organic movement
- Scale-proportional sizing for consistent visuals

## Development Notes

### VisionOS Requirements

- Requires VisionOS 1.0+ (Apple Vision Pro or simulator)
- Hand tracking must be supported (`HandTrackingProvider.isSupported`)
- App uses passthrough (no floor plane) for mixed reality experience

### Performance Considerations

- Fireball template is preloaded once to avoid per-spawn asset loading
- Particle emitters use finite lifespans with automatic cleanup
- Entity cloning (`clone(recursive: true)`) reuses template structure
- Smoke puffs self-terminate after particle fade completes

### Current Limitations

- Only fire element implemented (water, earth, air planned)
- No AI enemies or combat system
- No health/damage mechanics
- HomeView fireball is decorative only (not interactive)

## File Organization

```
ElementalWarrior/
├── ElementalWarriorApp.swift    # App entry, window/space definitions
├── AppModel.swift               # Observable state (currently minimal)
├── HomeView.swift               # Menu window with decorative fireball
├── ArenaImmersiveView.swift     # Immersive view setup
├── Info.plist                   # App permissions (hand/world sensing)
├── Managers/
│   └── HandTrackingManager.swift  # Hand tracking, gestures, projectiles, collisions
└── Effects/
    └── FireEffects.swift          # Fireball, trail, explosion particle effects
```

## Reality Composer Pro Assets

RealityAssetStuff/ contains Reality Composer Pro project with custom materials and shader graphs (currently used for experimentation; fireballs are created programmatically).
