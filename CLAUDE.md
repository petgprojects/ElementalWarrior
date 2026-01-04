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
- Central orchestrator for ARKit hand tracking, projectile launching, and collisions
- Uses `ARKitSession` with `HandTrackingProvider`, `WorldTrackingProvider`, and `SceneReconstructionProvider`
- Maintains independent `HandState` for left and right hands with intent-based delayed despawn
- Spawns/extinguishes fireballs based on hand gestures (open palm facing up)
- Punch detection: fist gesture + velocity threshold (0.3 m/s) to launch fireballs
- Cross-hand punch support (punch with opposite hand)
- **Mega fireball combining**: When both hands have fireballs and they come within 15cm, they combine into a 2x mega fireball with scaled explosions, scorch marks, and louder audio
- **Flamethrower mode**: "Stop" gesture (palm facing away, fingers up) activates continuous flame stream
- **Combined flamethrower**: When both hands use flamethrowers and come within 15cm, they merge into a single enhanced stream; separating hands splits back into two streams
- **Fire Wall mode**: "Zombie pose" gesture (arms extended, palms down, hands open) creates a defensive fire wall on the ground
- Gaze-based targeting using device head direction
- Projectile flight at 12 m/s with 20m max range
- **Persistent mesh collision system** - scanned geometry stays in memory even when out of LiDAR range
- Coordinates with `GestureDetection`, `CollisionSystem`, and effect modules

**GestureTypes** (Managers/GestureTypes.swift)
- Shared data structures: `HandGestureState`, `HandState`, `ProjectileState`, `CachedMeshGeometry`
- `HandState.isMegaFireball` - Tracks whether the hand is holding a combined mega fireball
- `HandState.isPartOfCombinedFlamethrower` - Tracks whether this hand's flamethrower is merged
- `ProjectileState.isMegaFireball` - Tracks mega state for projectiles in flight
- `FireWallColorState` enum - Color states for fire walls (blue=editing, redOrange=confirmed, green=selected)
- `FireWallState` struct - Tracks wall entity, position, rotation, width, height, color state, and audio
- `FireWallEditingState` struct - Tracks active editing session, current wall ID, hand positions
- `GestureConstants` enum with all timing and threshold values including mega fireball constants (combine distance, scale multipliers, audio boost), combined flamethrower constants, and fire wall constants (dimensions, zombie pose thresholds, rotation limits, selection timing)

**GestureDetection** (Managers/GestureDetection.swift)
- Multi-signal fist detection using 4 methods:
  1. Finger alignment (palm-to-finger direction)
  2. Thumb curl detection
  3. Hand compactness ratio
  4. Fingertip clustering
- Open palm detection (palm orientation + finger extension)
- Zombie pose detection (for fire walls):
  - `checkPalmFacingDown()` - Palm normal dot product with world down vector
  - `checkArmExtended()` - Hand position forward from chest
  - `checkZombiePose()` - Combined check for both hands in zombie pose
  - `calculateHeightPercent()` - Maps arm elevation (chest to eye) to 0-1
  - `calculateHandSeparation()` - Horizontal distance between hands for wall width
  - `calculateWallRotation()` - Rotation from hand forward offset (left forward=CCW, right forward=CW)
- Position and velocity calculation helpers

**CollisionSystem** (Managers/CollisionSystem.swift)
- Ray-triangle intersection using Möller–Trumbore algorithm
- Raycast against cached mesh geometry for persistent collision
- `HitResult` struct with position and surface normal
- `CachedMeshGeometry` initializer from `MeshAnchor`

**Persistent Room Scanning**
- `CachedMeshGeometry` struct extracts and stores vertices + triangle indices from MeshAnchors
- `persistentMeshCache: [UUID: CachedMeshGeometry]` - Geometry survives ARKit anchor removal
- Users can scan entire room by walking around, then hit walls from anywhere
- Visual scan overlay (semi-transparent cyan) shows scanned surfaces
- UI controls: toggle visualization, clear scan data, view scan statistics

### Fire Effects (Effects/)

**FireballEffects.swift**
- `createRealisticFireball()` - Multi-layered particle effect (4 layers: white core, yellow inner, orange spikes, red outer)
- `createFireTrail()` - Trail effect for flying projectiles
- `createSmokePuff()` - Smoke effect when fireballs extinguish
- All effects include PointLight components for environmental lighting

**ExplosionEffects.swift**
- `createExplosionEffect(scale:)` - 5-layer explosion (flash, core, flame, outer, smoke)
- Scale parameter allows 2x mega explosions for combined fireballs
- Dynamic point light with fade animation (intensity scales with explosion)

**ScorchMarkEffects.swift**
- `createScorchMark(scale:)` - Multi-layered procedural scorch marks
- Scale parameter allows larger scorch marks for mega fireballs
- `generateIrregularSootMesh()` - Organic edge variation with sinusoidal lobes and spurs
- `generateRadialGradientTexture()` - Burnt texture with turbulence noise
- Animated ember glow effect with pulsing heat colors
- Lingering smoke particle effect rising from impact
- 16-second lifetime with 1-second fade out

**FlamethrowerEffects.swift**
- `createFlamethrowerStream(scale:muzzleScale:jetIntensityMultiplier:)` - Multi-layer flamethrower stream (5 layers: core jet, body jet, sparks, heat smoke, muzzle flash)
- `muzzleScale` parameter: 0.5 for single-hand (50% size), 1.0 for combined
- `jetIntensityMultiplier` parameter: 1.0 for single-hand, 1.5 for combined flamethrower
- `createCombinedFlamethrowerStream()` - Convenience function with enhanced settings for merged stream
- `createFlamethrowerShutdownSmoke()` - Smoke puff when flamethrower stops
- Includes PointLight component for environmental lighting

**FireWallEffects.swift**
- `createFireWall(width:height:colorState:)` - Multi-layer fire wall with dynamic height scaling
- Color palettes for three states: blue (editing), red/orange (confirmed), green (selected)
- `createEmberLine()` - Ground-level spark line along wall base (always visible)
- `createFlameBase()` - Wide, slow base flames (bright core)
- `createFlameBody()` - Medium-speed main flame layer
- `createFlameTips()` - Fast, chaotic flame tips
- `createWallSmoke()` - Rising smoke above flames
- `createFireWallDespawnSmoke()` - One-shot smoke burst for despawn effect
- Dynamic point lights distributed along wall length
- Box emitter shapes with width parameter for wall length
- Height-based particle lifespan and speed scaling

### Audio System

**Sound Effects**
- Fire crackle (looping) - Plays while holding fireball, fades in/out
- Flamethrower sound (looping) - Plays during flame stream, audio boost when combined
- Woosh sound - Plays on fireball launch
- Explosion sound - Plays on impact

Audio is loaded from bundle or NSDataAsset fallback, with proper gain control and fade transitions.

### Hand Gesture Recognition

The system detects multiple gestures using the `GestureDetection` module:

1. **Open Palm Facing Up** - Spawns fireball
   - Palm orientation: wrist -Y axis dot product >0.4 with world up
   - Hand openness: finger tip-to-knuckle distance >5cm

2. **Fist Detection** - For punch-to-throw (multi-signal, requires 3/4 signals)
   - Finger alignment: palm-to-finger direction alignment <0.75
   - Thumb curl: thumb tip close to middle finger or folded toward wrist
   - Hand compactness: tip-to-wrist / knuckle-to-wrist ratio <1.4
   - Fingertip clustering: max fingertip spread <8cm

3. **Punch Detection** - Launches fireball
   - Fist + velocity >0.3 m/s + proximity within 20cm of fireball
   - Supports cross-hand punching (punch with opposite hand)

4. **Flamethrower Gesture** - Activates continuous flame stream
   - "Stop" sign gesture: palm facing away from user, fingers pointing up
   - Palm forward dot product threshold for alignment with gaze direction
   - Cancels any active fireball when activated

5. **Zombie Pose** - Creates fire wall (requires both hands)
   - Both arms extended forward from chest (>35cm forward)
   - Both palms facing down (palm normal dot product >0.5 with world down)
   - Both hands open (not fists)
   - Height controlled by arm elevation (chest=0%, eye=100%)
   - Width controlled by hand separation (20cm min to 4m max)
   - Rotation controlled by hand forward offset (±90°)
   - Cancels fireballs and flamethrowers when activated

6. **Simultaneous Fist Confirmation** - Confirms fire wall
   - Both hands make fists within 200ms window
   - While editing (blue wall): Confirms wall (blue→red/orange)
   - While wall selected (green): Enters edit mode (green→blue)
   - While editing at minimum height: Despawns wall with smoke

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
- `crackleController: AudioPlaybackController?` - Looping audio controller
- `flamethrower: Entity?` - Reference to active flamethrower stream
- `flamethrowerAudio: AudioPlaybackController?` - Looping flamethrower audio
- `isUsingFlamethrower: Bool` - Whether flamethrower is currently active
- `isPartOfCombinedFlamethrower: Bool` - True when merged with other hand's flamethrower

**State transitions:**
- Spawn: 0.5s scale animation (0.01 → 1.0) with audio fade-in
- Delayed despawn: 1.5s grace period after gesture ends (fireball floats, can be punched)
- Extinguish: 0.25s shrink + smoke puff particle burst + audio fade-out
- Force extinguish: Immediate removal with smoke (used when tracking is lost after 2s grace)
- Launch: Detach from hand, add trail effect, play woosh, fly toward gaze at 12 m/s

### Fire Wall State Management

**Fire wall properties (in HandTrackingManager):**
- `confirmedFireWalls: [UUID: FireWallState]` - Dictionary of confirmed (locked) walls
- `editingWallState: FireWallEditingState` - Current editing session state
- `gazeSelectedWallID: UUID?` - Wall currently being looked at
- `gazeSelectionStartTime: TimeInterval?` - When gaze dwell started
- `leftFistTime/rightFistTime: TimeInterval?` - For simultaneous fist detection

**Fire wall lifecycle:**
1. **Create**: Zombie pose spawns blue wall at gaze floor position
2. **Edit**: Adjust height/width/rotation/position with hand movements
3. **Confirm**: Simultaneous fists transition blue→red/orange, wall locks in place
4. **Select**: Gaze dwell (0.5s) on confirmed wall turns it green
5. **Re-edit**: Simultaneous fists on green wall transitions to blue for editing
6. **Despawn**: Minimum height + fists triggers smoke effect and removal

**Color states:**
- **Blue**: Active editing mode (being created or modified)
- **Red/Orange**: Confirmed and locked in place
- **Green**: Selected via gaze dwell, ready for editing or other action

**Constraints:**
- Maximum 3 confirmed walls at once
- Wall width: 20cm to 4m
- Wall height: 0% (embers only) to 100% (2.5m)
- Wall rotation: ±90° from perpendicular to user

### Smoke Puff System

When fireballs extinguish:
1. Fireball shrinks over 0.25s
2. Smoke puff entity spawns at same position, scales up
3. Particle emitter bursts for 100ms
4. Birth rate drops to 0 (stops new particles)
5. Existing particles fade over 2.5s lifespan
6. Entity cleanup after 2.5s total

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

- Fireball and explosion templates are preloaded once to avoid per-spawn asset loading
- Particle emitters use finite lifespans with automatic cleanup
- Entity cloning (`clone(recursive: true)`) reuses template structure
- Smoke puffs and scorch marks self-terminate after particle fade completes
- Persistent mesh cache allows collision even when surfaces are out of LiDAR range

### Current Limitations

- Only fire element implemented (water, earth, air planned)
- No AI enemies or combat system
- No health/damage mechanics
- HomeView fireball is decorative only (not interactive)

## File Organization

```
ElementalWarrior/
├── ElementalWarriorApp.swift       # App entry, window/space definitions
├── AppModel.swift                  # Observable state (currently minimal)
├── HomeView.swift                  # Menu window with decorative fireball
├── ArenaImmersiveView.swift        # Immersive view setup
├── Info.plist                      # App permissions (hand/world sensing)
├── Managers/
│   ├── HandTrackingManager.swift   # Central orchestrator for tracking and projectiles
│   ├── GestureTypes.swift          # Shared types: HandState, ProjectileState, etc.
│   ├── GestureDetection.swift      # Gesture recognition algorithms
│   └── CollisionSystem.swift       # Raycast collision with Möller–Trumbore algorithm
└── Effects/
    ├── FireballEffects.swift       # Fireball, trail, and smoke puff effects
    ├── ExplosionEffects.swift      # Multi-layer explosion particles
    ├── ScorchMarkEffects.swift     # Procedural scorch marks with ember glow
    ├── FlamethrowerEffects.swift   # Multi-layer flamethrower stream effects
    └── FireWallEffects.swift       # Multi-layer fire wall with color states
```

## Reality Composer Pro Assets

RealityAssetStuff/ contains Reality Composer Pro project with custom materials and shader graphs (currently used for experimentation; fireballs are created programmatically).
