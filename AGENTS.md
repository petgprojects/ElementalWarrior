# Repository Guidelines

## Project Structure & Module Organization
- `ElementalWarrior/` contains the SwiftUI app code and VisionOS logic.
- `ElementalWarrior/Managers/` holds gesture recognition, hand tracking, and collision systems.
- `ElementalWarrior/Effects/` contains particle and VFX builders for fire, explosions, scorch marks, and flamethrower streams.
- `ElementalWarrior/Assets.xcassets/` stores images, audio, and app icons.
- `Packages/RealityKitContent/` includes the RealityKit content package and .rkassets.
- `ElementalWarrior.xcodeproj/` is the Xcode project entry point.

## Build, Test, and Development Commands
- Open in Xcode: `open ElementalWarrior.xcodeproj`
- Build in CLI: `xcodebuild -project ElementalWarrior.xcodeproj -scheme ElementalWarrior -destination 'platform=visionOS Simulator,name=Apple Vision Pro'`
- Run locally: use Xcode (Cmd+R) with a Vision Pro device or the VisionOS simulator.

## Coding Style & Naming Conventions
- Swift style follows Xcode defaults (4-space indentation, trailing closure syntax).
- Types and files use `UpperCamelCase` (e.g., `HandTrackingManager.swift`).
- Methods and variables use `lowerCamelCase` (e.g., `spawnFireball()`).
- Keep effect builders and system managers isolated in their respective folders.
- No formatter is enforced; keep diffs tidy and align with existing patterns.

## Testing Guidelines
- No automated test targets are present in the repo.
- Validate changes by running the app in the VisionOS simulator and exercising gestures.
- If you add tests, co-locate them in a standard Xcode test target and document how to run them.

## Commit & Pull Request Guidelines
- Recent commits use short, lowercase, past-tense summaries (e.g., "fixed cross punch").
- Keep commits scoped to one feature or fix.
- PRs should include a clear description, testing notes, and screenshots or screen captures for UI/VFX changes.

## Documentation & Configuration Notes
- When behavior or architecture changes, update `README.md` to match (see `CLAUDE.md`).
- Hand/world sensing permissions live in `ElementalWarrior/Info.plist`; update entries when adding new providers.

## Agent Build Requirement
- Always run the build after any code or asset change, and treat failures as blockers.
- Command: `xcodebuild -project ElementalWarrior.xcodeproj -scheme ElementalWarrior -destination 'platform=visionOS Simulator,name=Apple Vision Pro' | grep -A 5 -B 5 "BUILD"`
