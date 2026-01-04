# Elemental Warrior

A VisionOS immersive experience inspired by Avatar: The Last Airbender, allowing players to master elemental bending through hand gestures and engage in battles with AI opponents in both passthrough and fully immersive environments.

## Overview

Elemental Warrior brings the magic of elemental bending to Apple Vision Pro. Using natural hand tracking and spatial computing, players can conjure and control the four elements - Fire, Water, Earth, and Air - to battle AI opponents in stunning mixed reality and immersive environments.

## Vision

The goal is to create an intuitive, gesture-based combat system where:
- Players use hand movements to bend elements (inspired by Avatar: The Last Airbender)
- Combat takes place in both passthrough mode (mixed reality in your physical space) and fully immersive arena environments
- AI opponents provide challenging battles with unique elemental abilities
- Hand gestures feel natural and responsive, making players truly feel like element benders

## Features

### Current Implementation

- **Home Interface**: A welcoming window with an animated fireball and quick access to the arena
- **Immersive Arena**: Full passthrough mixed reality environment for combat (no floor plane)
- **Hand Tracking**: Real-time ARKit hand skeleton tracking for both left and right hands
- **World Tracking**: Device pose tracking for gaze-based aiming
- **Scene Reconstruction**: Real-world surface detection with persistent mesh caching for fireball collisions
- **Gesture Recognition**:
  - Open palm facing up gesture detection to spawn fireballs
  - Multi-signal fist detection (4 detection methods for reliability)
  - Velocity tracking for punch detection
  - Both hands work independently and simultaneously
  - Intent-based gesture system with delayed despawn (1.5s grace period)
  - 2-second tracking loss grace period
- **Fire Bending**:
  - Realistic multi-layered fireball particle effects
  - Fireballs appear in open palms and track hand position
  - **Punch-to-throw**: Close fist and punch to launch fireballs toward your gaze direction
  - Cross-hand punching supported (punch opposite hand's fireball)
  - **Mega Fireball Combining**: Bring two fireballs together (within 15cm) to combine them into a mega fireball 2x the size with larger explosions, bigger scorch marks, and louder sounds
  - Projectiles fly at 12 m/s with fire trail effects
  - Fireballs explode on impact with walls/surfaces or after 20m max range
  - Smooth spawn/extinguish animations with smoke puffs
  - Dynamic point lighting from fireballs
  - **Flamethrower Mode**: Open hand in "stop" gesture (palm facing away, fingers up) to shoot a continuous flame stream from your palm
  - **Combined Flamethrower**: When using flamethrowers with both hands, bring hands together (within 15cm) to merge into a single powerful combined stream with enhanced visuals and audio; separating hands splits back into individual streams
  - **Fire Wall Mode**: Extend both arms forward with backs of hands visible (palms down, relaxed hands not fists) to create defensive fire walls
    - Walls spawn at your gaze position on the actual scanned floor (uses LiDAR mesh for accurate floor detection)
    - Relaxed gesture detection: only requires arms extended, palms facing down, and hands not clenched into fists
    - **Height**: Raise/lower arms (chest level = embers only, eye level = full 2.5m wall)
    - **Width**: Spread hands apart (20cm to 4m)
    - **Rotation**: Move one hand forward to rotate wall (left forward = counter-clockwise, right forward = clockwise, ±90°)
    - **Position**: Move both hands together to reposition wall on floor
    - **Confirm**: Clench both fists simultaneously to lock wall in place (blue → red/orange)
    - **Select**: Look at a confirmed wall for 0.5s while in zombie pose (red/orange → green)
    - **Edit**: Clench both fists while wall is green to re-enter edit mode
    - **Despawn**: Lower wall to minimum height (embers) + clench both fists
    - Maximum 3 confirmed fire walls at once
- **Audio System**:
  - Fire crackle sound (looping) while holding fireballs with fade in/out
  - Flamethrower sound (looping) during flame stream with audio boost when combined
  - Woosh sound on fireball launch
  - Explosion sound on impact
- **Visual Effects**:
  - Four-layer particle system for realistic fire (hot core, inner flame, spikes, outer flame)
  - Fire trail effect on flying projectiles
  - Five-layer explosion effect (white flash, yellow core, orange flame, red outer, smoke)
  - **Multi-layer flamethrower stream** (core jet, body jet, sparks, heat smoke, muzzle flash)
  - Combined flamethrower with enhanced particle intensity and larger muzzle flash
  - Smoke puff effects when fireballs extinguish
  - **Procedural scorch marks** with animated ember glow, multi-layer textures, and lingering smoke
  - **Multi-layer fire walls** with ember base, flame layers (base, body, tips), and rising smoke
  - Fire wall color states: blue (editing), red/orange (confirmed), green (selected)
  - Dynamic explosion lighting with fade animation
  - Programmatically generated particle emitters for optimal performance

### Planned Features

- **Element Bending Expansion**
  - Fire bending: ~~Add fire shields~~, ~~sustained flame jets~~ (Flamethrower and Fire Wall implemented!)
  - Water bending: Manipulate water projectiles and defensive waves
  - Earth bending: Launch rocks and create protective barriers
  - Air bending: Generate wind blasts and aerial evasion

- **AI Combat System**
  - Enemy AI with different elemental specializations
  - Adaptive difficulty and combat patterns
  - Health systems for both player and enemies
  - Hit detection and collision physics

- **Environment Expansion**
  - **Current**: Passthrough mixed reality mode
  - **Planned**: Themed battle arenas (fire temple, water oasis, earth cavern, air temple)

- **Progression System**
  - Unlock new bending techniques
  - Master multiple elements
  - Increasing difficulty levels

## Technical Architecture

### Core Technologies

- **SwiftUI**: Application UI and state management
- **RealityKit**: 3D rendering, physics, and entity management
- **VisionOS**: Spatial computing, hand tracking, and immersive spaces
- **ARKit**: Hand tracking, world tracking, and scene reconstruction

### Key Components

#### App Structure (`ElementalWarriorApp.swift`)
- `WindowGroup` ("home"): Main home window with menu interface
- `ImmersiveSpace` ("arena"): Full immersive environment using `.mixed` immersion style
- Supports simultaneous window and immersive space display

#### Views

- **HomeView** (`HomeView.swift`): Entry point with animated fireball display and navigation controls
- **ArenaImmersiveView** (`ArenaImmersiveView.swift`): Immersive passthrough environment with hand tracking

#### Hand Tracking System (Managers/)

- **HandTrackingManager**: Central orchestrator for hand tracking, projectiles, and collision
- **GestureTypes**: Shared data structures (`HandState`, `ProjectileState`, `CachedMeshGeometry`, `GestureConstants`)
- **GestureDetection**: Multi-signal gesture recognition algorithms
- **CollisionSystem**: Raycast collision using Möller–Trumbore ray-triangle intersection

#### Fire Effects System (Effects/)

- **FireballEffects**: Fireball, trail, and smoke puff particle effects
- **ExplosionEffects**: Multi-layer explosion with dynamic lighting
- **ScorchMarkEffects**: Procedural scorch marks with ember glow animation
- **FlamethrowerEffects**: Multi-layer flamethrower stream with configurable muzzle and jet intensity for single/combined modes
- **FireWallEffects**: Multi-layer fire wall with ember base, flame layers, smoke, and three color states (blue/red-orange/green)

#### State Management

- **AppModel** (`AppModel.swift`): Observable app-wide state container
  - Tracks immersive space state (closed, in transition, open)
  - Shared across views via SwiftUI environment

### Visual Effects Pipeline

1. **Particle Systems**: Multi-layered particle emitters for fire effects
   - Additive blend mode for glowing fire appearance
   - Color evolution with alpha fade for realistic flames
   - Four-layer fireball: hot core, inner flame, spikes, outer flame
   - Smoke puffs with 2.5-second fade and auto-cleanup

2. **Scorch Marks**: Procedural burnt texture effects
   - Irregular mesh generation with organic edges
   - Radial gradient texture with turbulence noise
   - Animated ember glow with pulsing heat colors
   - Lingering smoke particle effect
   - 16-second lifetime with fade-out

3. **Lighting**: Point lights attached to fireballs and explosions for environmental illumination

4. **Animation**:
   - Spawn animation: 0.5s scale from 0.01 → 1.0
   - Extinguish animation: 0.25s shrink with smoke burst
   - Real-time position tracking following hand movement

## Project Structure

```
ElementalWarrior/
├── ElementalWarrior/
│   ├── ElementalWarriorApp.swift       # Main app entry point
│   ├── AppModel.swift                  # App-wide state management
│   ├── HomeView.swift                  # Main menu interface
│   ├── ArenaImmersiveView.swift        # Immersive view setup
│   ├── Info.plist                      # App permissions (hand/world sensing)
│   ├── Managers/
│   │   ├── HandTrackingManager.swift   # Central hand tracking orchestrator
│   │   ├── GestureTypes.swift          # Shared types and constants
│   │   ├── GestureDetection.swift      # Gesture recognition algorithms
│   │   └── CollisionSystem.swift       # Raycast collision detection
│   └── Effects/
│       ├── FireballEffects.swift       # Fireball and trail particles
│       ├── ExplosionEffects.swift      # Explosion particle effects
│       ├── ScorchMarkEffects.swift     # Procedural scorch marks
│       ├── FlamethrowerEffects.swift   # Flamethrower stream effects
│       └── FireWallEffects.swift       # Fire wall with color states
├── RealityAssetStuff/                  # Reality Composer Pro project (experimental)
├── CLAUDE.md                           # Developer guidance for AI assistants
└── ElementalWarrior.xcodeproj/         # Xcode project
```

## Requirements

- Apple Vision Pro device or simulator
- Xcode 15.2 or later
- VisionOS 1.0 or later
- Swift 5.9+

## Getting Started

### Setup

1. Clone the repository
2. Open `ElementalWarrior.xcodeproj` in Xcode
3. Select your Vision Pro device or the VisionOS simulator
4. Build and run (Cmd+R)

### First Launch

1. The app opens with the Home window showing an animated fireball
2. Click "Start" to enter the immersive arena
3. Open your palms facing upward to spawn fireballs (works for both hands)
4. **To throw**: Look at your target, then make a fist and punch the fireball
5. **Mega fireball**: Spawn fireballs in both hands, then bring them together (within 15cm) to combine into a mega fireball with 2x size, bigger explosions, and louder sounds!
6. Fireballs fly toward where you're looking and explode on impact with scorch marks
7. Flip your palms down to extinguish fireballs (they persist for 1.5s after closing palm)
8. **Flamethrower**: Hold your hand in a "stop" gesture (palm facing away from you, fingers up) to shoot a continuous flame stream
9. **Combined Flamethrower**: Use flamethrowers with both hands and bring them together to create a more powerful combined stream; separate hands to split back into two streams
10. **Fire Wall**: Extend both arms forward with palms facing down and hands open (zombie pose) to create a fire wall at where you're looking
    - Raise/lower arms to control wall height, spread hands to control width
    - Move one hand forward to rotate the wall
    - Clench both fists simultaneously to confirm (blue → red/orange)
    - Look at a confirmed wall to select it (turns green), then fists to edit
    - Maximum 3 confirmed walls
11. Click "Quit Immersion" to return to the home view

## Development Roadmap

### Phase 1: Core Mechanics (Completed)
- [x] Basic app structure and navigation
- [x] Immersive space setup with passthrough
- [x] Multi-layered fire particle effects
- [x] Hand tracking integration (ARKit)
- [x] Palm-up gesture recognition (both hands)
- [x] Fireball spawn/extinguish system
- [x] Fireball projectile launching (punch-to-throw)
- [x] Projectile physics and trajectories
- [x] Gaze-based aiming (head direction targeting)
- [x] Scene reconstruction for surface collision
- [x] Explosion effects on impact
- [x] Scorch marks with ember glow
- [x] Audio system (crackle, woosh, explosion)
- [x] Persistent mesh collision (works beyond LiDAR range)
- [x] Code refactoring for maintainability
- [x] Mega fireball combining (two fireballs → mega fireball with scaled effects)
- [x] Flamethrower mode with combined dual-hand stream
- [x] Fire Wall defensive barriers with zombie pose gesture

### Phase 2: Combat System
- [ ] AI enemy entities
- [ ] Health and damage system
- [x] Collision detection (real-world surfaces)
- [ ] Basic combat loop
- [ ] Enemy AI behaviors

### Phase 3: Element Expansion
- [ ] Water bending implementation
- [ ] Earth bending implementation
- [ ] Air bending implementation
- [ ] Element switching UI

### Phase 4: Polish & Features
- [ ] Arena environments (fire temple, water oasis, earth cavern, air temple)
- [ ] Additional particle effects and VFX
- [x] Sound effects and spatial audio
- [ ] Tutorial system
- [ ] Progression and unlocks

## Implementation Notes

### Hand Tracking Implementation
VisionOS provides `ARKitSession` with multiple providers for comprehensive tracking. Current implementation:
- **HandTrackingProvider**: Tracks hand joint positions in 3D space (wrist, knuckles, fingertips)
- **WorldTrackingProvider**: Tracks device pose for gaze direction (head-based aiming)
- **SceneReconstructionProvider**: Detects real-world surfaces for projectile collisions
- Multi-signal fist detection (4 methods: alignment, thumb curl, compactness, clustering)
- Calculates hand velocity from 150ms position history for punch detection
- Detects palm orientation by checking wrist transform Y-axis alignment with world up
- Handles left/right hand coordinate system mirroring correctly
- Intent-based delayed despawn system (1.5s grace period) for smoother gesture flow
- 2-second tracking loss grace period before force extinguish

### Physics and Collision
Current projectile system implementation:
- Manual projectile movement at 60fps update rate (12 m/s flight speed)
- Persistent mesh cache stores geometry even when surfaces leave LiDAR range
- Möller–Trumbore ray-triangle intersection for precise collision detection
- Returns hit position and surface normal for scorch mark orientation
- Maximum projectile range: 20 meters before auto-explosion
- Future: RealityKit physics for enemy entity collisions

### Performance Considerations
- Use entity pooling for frequently spawned projectiles
- Fireball and explosion templates preloaded once
- Persistent mesh cache eliminates re-scanning for collision
- Particle emitters use finite lifespans with automatic cleanup

## Contributing

This is a personal project, but ideas and feedback are welcome. Future iterations of Claude or other developers can reference this README to understand the project's architecture and goals.

## License

Private project - all rights reserved.

## Acknowledgments

Inspired by Avatar: The Last Airbender created by Michael Dante DiMartino and Bryan Konietzko.
