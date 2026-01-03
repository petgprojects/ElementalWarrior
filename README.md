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
- **Scene Reconstruction**: Real-world surface detection for fireball collisions
- **Gesture Recognition**:
  - Open palm facing up gesture detection to spawn fireballs
  - Fist detection for punch-to-throw gesture
  - Velocity tracking for punch detection
  - Both hands work independently and simultaneously
  - Intent-based gesture system with delayed despawn (1.5s grace period)
- **Fire Bending**:
  - Realistic multi-layered fireball particle effects
  - Fireballs appear in open palms and track hand position
  - **Punch-to-throw**: Close fist and punch to launch fireballs toward your gaze direction
  - Projectiles fly at 12 m/s with fire trail effects
  - Fireballs explode on impact with walls/surfaces or after 20m max range
  - Smooth spawn/extinguish animations with smoke puffs
  - Dynamic point lighting from fireballs
- **Visual Effects**:
  - Four-layer particle system for realistic fire (hot core, inner flame, spikes, outer flame)
  - Fire trail effect on flying projectiles
  - Five-layer explosion effect (white flash, yellow core, orange flame, red outer, smoke)
  - Smoke puff effects when fireballs extinguish
  - Organic scorch marks on impact with textured soot, ember glow, and subtle wall smoke
  - Dynamic explosion lighting with fade animation
  - Programmatically generated particle emitters for optimal performance

### Planned Features

- **Element Bending Expansion**
  - Fire bending: Add projectile launching, fire shields, sustained flame jets
  - Water bending: Manipulate water projectiles and defensive waves
  - Earth bending: Launch rocks and create protective barriers
  - Air bending: Generate wind blasts and aerial evasion

- **Advanced Gesture Recognition**
  - Detect dynamic gestures (punches, sweeps, circular motions)
  - Gesture power based on hand velocity
  - Additional poses for different bending techniques

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
- **ECS (Entity Component System)**: Custom component/system architecture for game logic

### Key Components

#### App Structure (`ElementalWarriorApp.swift`)
- `WindowGroup` ("home"): Main home window with menu interface
- `ImmersiveSpace` ("arena"): Full immersive environment using `.mixed` immersion style
- Supports simultaneous window and immersive space display

#### Views

- **HomeView** (`HomeView.swift`): Entry point with animated fireball display and navigation controls
- **ArenaImmersiveView** (`ArenaImmersiveView.swift`): Immersive passthrough environment with hand tracking

#### Hand Tracking System

- **HandTrackingManager** (`ArenaImmersiveView.swift:26-427`): Core hand tracking implementation
  - Uses `ARKitSession` and `HandTrackingProvider` for real-time hand skeleton data
  - Maintains independent `HandState` for left and right hands
  - Gesture recognition: palm orientation + hand openness detection
  - Per-hand fireball spawning/extinguishing with animations
  - Preloads fireball template for performance optimization

#### Fireball System

- **FireballEntity** (`FireballEntity.swift`): Programmatic particle effect creation
  - `createRealisticFireball()`: Multi-layered particle emitter (4 layers)
  - `createSmokePuff()`: Smoke effect for fireball extinguishing
  - All effects scale proportionally for visual consistency

#### State Management

- **AppModel** (`AppModel.swift`): Observable app-wide state container
  - Tracks immersive space state (closed, in transition, open)
  - Shared across views via SwiftUI environment

### Visual Effects Pipeline

1. **Particle Systems**: Multi-layered particle emitters for fire effects
   - Additive blend mode for glowing fire appearance
   - Color evolution with alpha fade for realistic flames
   - Four-layer fireball: hot core, inner flame, spikes, outer flame
   - Smoke puffs with 2-second fade and auto-cleanup

2. **Lighting**: Point lights attached to fireballs for environmental illumination

3. **Animation**:
   - Spawn animation: 0.5s scale from 0.01 → 1.0
   - Extinguish animation: 0.1s shrink with smoke burst
   - Real-time position tracking following hand movement

## Project Structure

```
ElementalWarrior/
├── ElementalWarrior/
│   ├── ElementalWarriorApp.swift      # Main app entry point
│   ├── AppModel.swift                 # App-wide state management
│   ├── HomeView.swift                 # Main menu interface
│   ├── ArenaImmersiveView.swift       # Immersive view setup
│   ├── Info.plist                     # App permissions (hand/world sensing)
│   ├── Managers/
│   │   └── HandTrackingManager.swift  # Hand tracking, gestures, projectiles, collisions
│   └── Effects/
│       └── FireEffects.swift          # Fireball, trail, and explosion particle effects
├── RealityAssetStuff/                 # Reality Composer Pro project (experimental)
├── CLAUDE.md                          # Developer guidance for AI assistants
└── ElementalWarrior.xcodeproj/        # Xcode project
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
5. Fireballs fly toward where you're looking and explode on impact
6. Flip your palms down to extinguish fireballs (they persist for 1.5s after closing palm)
7. Click "Quit Immersion" to return to the home view

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
- [ ] Particle effects and VFX
- [ ] Sound effects and spatial audio
- [ ] Tutorial system
- [ ] Progression and unlocks

## Implementation Notes

### Hand Tracking Implementation
VisionOS provides `ARKitSession` with multiple providers for comprehensive tracking. Current implementation:
- **HandTrackingProvider**: Tracks hand joint positions in 3D space (wrist, knuckles, fingertips)
- **WorldTrackingProvider**: Tracks device pose for gaze direction (head-based aiming)
- **SceneReconstructionProvider**: Detects real-world surfaces for projectile collisions
- Detects open palm gesture by measuring finger extension (>5cm tip-to-knuckle)
- Detects fist gesture by checking finger extension (<3.5cm threshold)
- Calculates hand velocity from 100ms position history for punch detection
- Detects palm orientation by checking wrist transform Y-axis alignment with world up
- Handles left/right hand coordinate system mirroring correctly
- Intent-based delayed despawn system (1.5s grace period) for smoother gesture flow

### Physics and Collision
Current projectile system implementation:
- Manual projectile movement at 60fps update rate (12 m/s flight speed)
- Scene reconstruction meshes for real-world surface collision detection
- Distance-based collision checking with 0.5m proximity threshold
- Maximum projectile range: 20 meters before auto-explosion
- Future: RealityKit physics for enemy entity collisions

### Performance Considerations
- Use entity pooling for frequently spawned projectiles
- Optimize particle effects for Vision Pro's rendering pipeline
- Implement level-of-detail (LOD) for complex visual effects

## Contributing

This is a personal project, but ideas and feedback are welcome. Future iterations of Claude or other developers can reference this README to understand the project's architecture and goals.

## License

Private project - all rights reserved.

## Acknowledgments

Inspired by Avatar: The Last Airbender created by Michael Dante DiMartino and Bryan Konietzko.
