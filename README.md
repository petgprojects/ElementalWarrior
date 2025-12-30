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
- **Immersive Arena**: A dedicated spatial environment with a floor plane for combat
- **Visual Effects**:
  - Physically-based rendering for fire effects with emissive materials
  - Point lighting for realistic glow effects
  - Custom rotation system for animated elemental effects

### Planned Features

- **Element Bending System**
  - Fire bending: Shoot fireballs, create fire shields
  - Water bending: Manipulate water projectiles and defensive waves
  - Earth bending: Launch rocks and create protective barriers
  - Air bending: Generate wind blasts and aerial evasion

- **Hand Gesture Recognition**
  - Track hand positions and movements in 3D space
  - Recognize specific gestures for different bending techniques
  - Intuitive casting mechanics (punch for fireball, sweep for water wave, etc.)

- **AI Combat System**
  - Enemy AI with different elemental specializations
  - Adaptive difficulty and combat patterns
  - Health systems for both player and enemies
  - Hit detection and collision physics

- **Dual Environment Support**
  - **Passthrough Mode**: Fight in your physical space with AR overlays
  - **Arena Mode**: Fully immersive battle arenas with unique themes

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

#### App Structure (`ElementalWarriorApp.swift:11`)
- `WindowGroup`: Main home window with menu interface
- `ImmersiveSpace`: Full immersive arena environment
- Uses `.mixed` immersion style for blended reality

#### Views

- **HomeView** (`HomeView.swift:11`): Entry point with animated fireball display and navigation controls
- **ArenaImmersiveView** (`ArenaImmersiveView.swift:11`): Immersive combat environment with floor plane
- **FireballVolumeView** (`FireballVolumeView.swift:11`): Reusable fireball entity with lighting

#### Systems

- **RotationSystem** (`RotationSystem.swift:14`): Custom ECS system for rotating entities
  - `RotationComponent`: Defines rotation speed for entities
  - Automatically rotates entities each frame based on delta time

#### State Management

- **AppModel** (`AppModel.swift:13`): Observable app-wide state container
  - Tracks immersive space state (closed, in transition, open)
  - Shared across views via SwiftUI environment

### Visual Effects Pipeline

1. **Physical Materials**: Using `PhysicallyBasedMaterial` for realistic rendering
   - Base color and emissive properties for glowing effects
   - Roughness and metallic parameters for material properties

2. **Lighting**: Point lights positioned near elemental effects for dynamic illumination

3. **Animation**: Component-based rotation system extensible to other animations

## Project Structure

```
ElementalWarrior/
├── ElementalWarrior/
│   ├── ElementalWarriorApp.swift      # Main app entry point
│   ├── AppModel.swift                 # App-wide state management
│   ├── HomeView.swift                 # Main menu interface
│   ├── ArenaImmersiveView.swift       # Immersive arena environment
│   ├── FireballVolumeView.swift       # Fireball entity component
│   ├── RotationSystem.swift           # Custom ECS rotation system
│   └── [Legacy files from template]
├── Packages/
│   └── RealityKitContent/             # 3D assets and Reality Composer content
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
3. Click "Quit Immersion" to return to the home view

## Development Roadmap

### Phase 1: Core Mechanics (In Progress)
- [x] Basic app structure and navigation
- [x] Immersive space setup
- [x] Initial fire visual effects
- [ ] Hand tracking integration
- [ ] Basic gesture recognition
- [ ] Fireball projectile system

### Phase 2: Combat System
- [ ] AI enemy entities
- [ ] Health and damage system
- [ ] Collision detection
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

### Hand Tracking Strategy
VisionOS provides `ARKitSession` and `HandTrackingProvider` for accessing hand skeleton data. The planned implementation will:
- Track hand joint positions in 3D space
- Calculate hand velocity for gesture power
- Detect specific poses (fist, open palm, pointing) for different techniques

### Physics and Collision
RealityKit's physics system will handle:
- Projectile trajectories
- Collision detection between elements and entities
- Environmental interactions

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
