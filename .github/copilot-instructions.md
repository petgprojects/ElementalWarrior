# Elemental Warrior Copilot Instructions

## Project Overview
Elemental Warrior is a VisionOS immersive experience using SwiftUI and RealityKit. It features hand tracking for elemental bending (fireballs), gesture recognition, and mixed reality combat with persistent room scanning.

## Architecture & Core Components

### App Structure
- **Entry Point**: `ElementalWarriorApp.swift` defines a `WindowGroup` ("home") and an `ImmersiveSpace` ("arena").
- **State Management**: `AppModel.swift` uses `@Observable` and `@MainActor` for app-wide state.
- **Immersive View**: `ArenaImmersiveView.swift` hosts the AR experience.

### Key Managers
- **HandTrackingManager** (`Managers/HandTrackingManager.swift`):
  - **Central Hub**: Manages `ARKitSession`, `HandTrackingProvider`, `WorldTrackingProvider`, and `SceneReconstructionProvider`.
  - **Gesture Recognition**: Detects "Palm Up" (spawn) and "Punch" (throw) gestures using joint positions/velocities.
  - **Physics & Collision**: Implements custom ray-triangle intersection against `CachedMeshGeometry` for persistent room scanning (geometry survives anchor removal).
  - **State**: Maintains independent `HandState` for left/right hands.

### Effects
- **FireEffects** (`Effects/FireEffects.swift`):
  - Programmatic creation of RealityKit particle emitters.
  - `createRealisticFireball()`: Multi-layered particle system (core, inner, outer).
  - `createExplosionEffect()`: 5-layer explosion sequence.

## Developer Workflows

### Building & Running
- **Xcode**: Open `ElementalWarrior.xcodeproj`.
- **Simulator**: Run on "Apple Vision Pro" simulator.
- **Mandatory Build Verification**: After EVERY major change, you MUST run the following command to verify the build. Check the output for `** BUILD SUCCEEDED **` or `** BUILD FAILED **`.
  ```bash
  xcodebuild -project ElementalWarrior.xcodeproj -scheme ElementalWarrior -destination 'platform=visionOS Simulator,name=Apple Vision Pro' | grep -A 5 -B 5 "BUILD"
  ```

### Debugging
- **Hand Tracking**: `HandTrackingManager` has debug state enums (`HandGestureState`).
- **Visualizations**: The app supports visualizing scanned room geometry (cyan overlay).

## Conventions & Patterns

### RealityKit & ARKit
- **Programmatic Entities**: Prefer creating complex entities (like fireballs) via code in `Effects/` rather than loading `.usdz` for dynamic effects.
- **Coordinate Spaces**: Be mindful of transforms: Joint Space -> Anchor Space -> World Space.
- **Performance**: Use `CachedMeshGeometry` for collision checks to avoid querying ARKit anchors every frame.

### Swift & SwiftUI
- **Concurrency**: Heavy use of `@MainActor` for UI and RealityKit updates.
- **Observation**: Use the `@Observable` macro for data models.

## Integration Points
- **RealityKitContent**: Custom package for shared assets (materials, static models).
- **ARKit**: Deep integration for hand skeleton and world mesh.

## Critical Files
- `Managers/HandTrackingManager.swift`: The "brain" of the AR logic.
- `Effects/FireEffects.swift`: Visual effects definitions.
- `ElementalWarriorApp.swift`: App lifecycle and scene definition.
