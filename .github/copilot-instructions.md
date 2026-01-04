# Elemental Warrior Copilot Instructions

## Source of Truth
- Use `README.md` as the authoritative description of the current feature set and architecture. Keep changes in this file aligned with it.

## Project Overview
Elemental Warrior is a visionOS immersive experience built with SwiftUI + RealityKit + ARKit. It currently focuses on fire bending via hand tracking: palm-up spawns fireballs, punch-to-throw launches them toward gaze direction, and projectiles collide against real-world surfaces using scene reconstruction with a persistent mesh cache.

## Architecture & Core Components

### App Structure
- **Entry Point**: `ElementalWarriorApp.swift` defines a `WindowGroup` ("home") and an `ImmersiveSpace` ("arena") using `.mixed` immersion style.
- **State Management**: `AppModel.swift` is `@Observable` + `@MainActor` and owns the shared `HandTrackingManager` (used both for gameplay and the Home debug UI).
- **Views**:
  - `HomeView.swift`: Home window UI with an animated fireball preview plus debug panels for hand gesture state and room scanning.
  - `ArenaImmersiveView.swift`: Passthrough arena; attaches `handTrackingManager.rootEntity` to the `RealityView` and starts tracking.

### Managers (ElementalWarrior/Managers)
- `HandTrackingManager.swift`
  - Central orchestrator for `ARKitSession` and providers: `HandTrackingProvider`, `WorldTrackingProvider`, and `SceneReconstructionProvider` (when supported).
  - Owns per-hand state (`HandState`), projectile state (`ProjectileState`), audio playback controllers, and the persistent mesh cache.
  - Implements core gameplay behaviors: spawn/hold/despawn, punch-to-throw, cross-hand punch, mega fireball combining, projectile updates, and impact/explosion handling.
- `GestureTypes.swift`
  - Shared model types and constants (`HandState`, `ProjectileState`, `CachedMeshGeometry`, `HandGestureState`, `GestureConstants`).
- `GestureDetection.swift`
  - Gesture recognition algorithms:
    - Palm-up + open-hand detection for spawning/holding.
    - Multi-signal fist detection (4 signals) plus velocity-based punch detection support.
    - Zombie pose detection for fire walls with hysteresis (relaxed initial detection, even more relaxed when already active). Checks: back of hand visible, not-fist, arms somewhat forward.
    - Position history utilities for velocity calculation.
- `CollisionSystem.swift`
  - Projectile collision via custom ray-triangle intersection (Möller–Trumbore) against `CachedMeshGeometry` to support collisions even when ARKit removes mesh anchors.

### Effects (ElementalWarrior/Effects)
- All major VFX are created programmatically (no dynamic `.usdz` loading for these effects).
- `FireballEffects.swift`
  - `createRealisticFireball(scale:)`: Four-layer fireball particle system plus a point light.
  - `createFireTrail()`: Trail particles for flying projectiles.
  - `createSmokePuff()` / `createSmokePuffEmitter()`: Extinguish smoke.
- `ExplosionEffects.swift`
  - `createExplosionEffect(scale:)`: Five-layer explosion (flash/core/flame/outer/smoke) plus explosion lighting.
- `ScorchMarkEffects.swift`
  - `createScorchMark(scale:)`: Procedural scorch mark mesh + radial gradient texture + ember glow animation + lingering smoke.

## Developer Workflows

### Building & Running
- Open `ElementalWarrior.xcodeproj` in Xcode.
- Run on "Apple Vision Pro" simulator (or device if available).
- **Mandatory Build Verification**: After EVERY major change, run:
  ```bash
  xcodebuild -project ElementalWarrior.xcodeproj -scheme ElementalWarrior -destination 'platform=visionOS Simulator,name=Apple Vision Pro' | grep -A 5 -B 5 "BUILD"
  ```

### Debugging & Visualization
- Home debug UI (in `HomeView.swift`) surfaces `HandGestureState` and per-hand debug strings from `HandTrackingManager`.
- Room scanning UI supports:
  - Toggling scan visualization entities (cyan overlay)
  - Clearing cached scanned data

## Conventions & Patterns

### RealityKit & ARKit
- **Coordinate Spaces**: Be explicit about transforms: Joint Space → Anchor Space → World Space. Most gesture logic uses `anchor.originFromAnchorTransform * joint.anchorFromJointTransform`.
- **Performance**: Prefer using `CachedMeshGeometry` for collision checks over per-frame ARKit anchor queries.
- **Programmatic VFX**: Continue to generate particle systems procedurally in `Effects/` to keep runtime assets light and parameters easy to tune.

### Swift & SwiftUI
- Keep RealityKit mutations and SwiftUI state changes on `@MainActor`.
- Prefer shared state via `@Observable` models (current pattern: `AppModel` owns managers used by both window and immersive space).

## Integration Points
- `Packages/RealityKitContent`: Shared materials/static assets.
- ARKit providers: hand tracking, world tracking (for gaze aiming), and scene reconstruction (for surface collision).

## Critical Files
- `ElementalWarrior/ElementalWarriorApp.swift`: App entry point + scene configuration.
- `ElementalWarrior/AppModel.swift`: App-wide state + manager ownership.
- `ElementalWarrior/HomeView.swift`: Home UI + debug and scanning controls.
- `ElementalWarrior/ArenaImmersiveView.swift`: Immersive space root view.
- `ElementalWarrior/Managers/HandTrackingManager.swift`: Gameplay orchestration.
- `ElementalWarrior/Managers/GestureDetection.swift`: Gesture algorithms.
- `ElementalWarrior/Managers/CollisionSystem.swift`: Mesh collision.
- `ElementalWarrior/Effects/*.swift`: Fireball/explosion/scorch VFX.

## Documentation Hygiene (Required)
- When you change behavior, UX, file structure, or public APIs, you MUST update BOTH:
  - `README.md` (feature set + architecture description)
  - `.github/copilot-instructions.md` (how future agents should work in this repo)
- If a change is experimental or incomplete, say so explicitly in `README.md` under the appropriate section rather than letting docs drift.
- Before finishing a task, do a quick consistency check:
  - Does `README.md` still describe the current gestures/effects/managers?
  - Do the file names mentioned in `.github/copilot-instructions.md` still exist?
  - Does the build verification command still work?
