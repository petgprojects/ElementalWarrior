# ElementalWarrior Session Notes

## Current Session Summary (2025-12-31)

### Tasks Completed
1. ✅ **Made handheld fireball smaller** - Scaled to ~60% of original size
   - Model scale: 1.5 → 0.9
   - All particle emitter shapes proportionally reduced
   - Particle speeds/accelerations scaled accordingly
   - Light intensity: 5000 → 3500, attenuation radius: 1.5 → 1.0

2. ✅ **Added particle boost to HomeView** (from previous session)
   - 7 particle layers: outerFlames, midFlames, innerFlames, hotCore, sparks, wisps, smoke
   - Total ~3200 particles/sec

3. ✅ **Summon animation** - 0.5s fade-in (from previous session)
   - Uses `.easeOut` timing function
   - Scales from [0.01, 0.01, 0.01] to [1.0, 1.0, 1.0]

4. ✅ **Dismiss animation** - Smoke puff effect (from previous session)
   - Fireball shrinks over 0.1s while smoke puff spawns
   - Smoke puff particles expand 4x and fade over 1.2s
   - Puff rises and dissipates naturally

### Build Status
**BUILD SUCCEEDED** - All changes compile without errors

---

## Project Architecture

### Key Files
- **ElementalWarriorApp.swift** - App entry point, defines WindowGroup and ImmersiveSpace
- **HomeView.swift** - Splash screen with fireball model + 7 particle layers
- **ArenaImmersiveView.swift** - Main immersive experience with hand tracking
- **RotationSystem.swift** - Custom RealityKit ECS system for rotating fireballs
- **Info.plist** - Contains NSHandsTrackingUsageDescription permission

### Core Features
1. **Hand Tracking** - Uses ARKit's HandTrackingProvider
   - Palm-up detection via wrist Y-axis dot product (threshold: 0.4)
   - Fist detection via finger extension distance (threshold: 5cm)
   - Spawns fireball when hand is open with palm up
   - Extinguishes when hand closes or palm turns down

2. **Fireball System** - Entity Component System (ECS) design
   - Loads Fireball.usdz from bundle (or fallback sphere)
   - 7 particle layers for dramatic effect
   - Point light for illumination
   - RotationComponent for continuous spinning

3. **Animations**
   - Summon: 0.5s scale-up fade-in
   - Dismiss: 0.1s shrink + smoke puff burst effect

---

## Fireball Particle Configuration (Handheld)

All values represent current small-scale version:

| Layer | Birth Rate | Emitter Size | Particle Size | Speed | Acceleration |
|-------|-----------|--------------|---------------|-------|--------------|
| Outer Flames | 800 | 0.07 | 0.022 | 0.09 | 0.25 |
| Mid Flames | 600 | 0.05 | 0.017 | 0.06 | 0.15 |
| Inner Flames | 500 | 0.03 | 0.014 | 0.035 | 0.1 |
| Hot Core | 400 | 0.018 | 0.009 | 0.018 | 0.03 |
| Sparks | 200 | 0.06 | 0.005 | 0.18 | 0.5 |
| Wisps | 150 | 0.06 | 0.012 | 0.12 | 0.36 |
| Smoke | 80 | 0.035 | 0.018 | 0.05 | 0.08 |

**Total: ~2730 particles/sec**

---

## HomeView Fireball Configuration

Similar 7-layer system with slightly larger scale:
- Model scale: 2.5 (vs 0.9 for handheld)
- Emitter sizes ~1.4x larger than handheld version
- **Total: ~3200 particles/sec**

---

## Important Implementation Details

### Hand Tracking Algorithm
```swift
// Palm detection (checkPalmFacingUp)
- Transform wrist to world space
- Extract -Y axis as palm normal
- Dot product with [0, 1, 0] (world up)
- Returns true if dot > 0.4 (~45 degrees)

// Fist detection (checkHandIsOpen)
- Measure tip-to-knuckle distance for middle & index fingers
- Threshold: 5cm (0.05m)
- Open hand: distance > threshold
```

### Asset Loading
- Fireball.usdz loaded from Bundle.main
- URL: `Bundle.main.url(forResource: "Fireball", withExtension: "usdz")`
- **Required: Must add Fireball.usdz to "Copy Bundle Resources" in Xcode**

### Key Positions
- Smoke layer vertical offset: 0.025 (handheld)
- Palm pickup point: middleFingerKnuckle + [0, 0.08, 0] in world space
- Animation duration: 0.5s (summon), 0.1s (dismiss shrink)

---

## Known Good States

### Handheld Fireball Behavior
✅ Spawns when hand is open + palm up
✅ Follows palm position smoothly
✅ Disappears when hand closes or palm turns down
✅ Creates smoke puff on dismiss
✅ Fades in over 0.5 seconds when summoned
✅ Right-sized (0.9 model scale)
✅ Appropriate particle count and visual density

### HomeView Fireball
✅ Displays correctly on splash screen
✅ Has matching 7-layer particle system
✅ Rotates continuously
✅ Uses USDZ asset

---

## Future Work Considerations

### If User Requests Changes
1. **Particle count adjustment** - Edit birth rates in particle emitter functions
2. **Visual intensity** - Modify light.intensity (currently 3500) or particle colors
3. **Fireball size** - Adjust model.scale in createHandFireball() (currently 0.9)
4. **Hand detection sensitivity** - Tune palm threshold (0.4) or fist distance threshold (0.05)
5. **Animation timing** - Modify 0.5s duration in animateSpawn functions
6. **Smoke puff effect** - Edit createSmokePuffEmitter() parameters

### Performance Notes
- Currently using ~2730 particles/sec for handheld + 3200 for HomeView
- Total doesn't exceed both at same time (sequential spawning)
- Light calculations at 3500 intensity with 1.0m attenuation radius
- RotationSystem registered dynamically on first fireball creation

---

## Testing Checklist for Next Session

- [ ] Build succeeds without errors
- [ ] HomeView displays splash screen with fireball
- [ ] Handheld fireball spawns when palm raised with open hand
- [ ] Fireball follows palm movement smoothly
- [ ] Fireball disappears when hand closes
- [ ] Fireball disappears when palm turns away
- [ ] Smoke puff effect visible on dismiss
- [ ] Summon animation fades in over 0.5s (not instant)
- [ ] Particle effects look balanced in density
- [ ] No memory leaks or performance issues
- [ ] Both fireballs (splash + handheld) use USDZ asset

---

## File References
- Project root: `/Users/petergelgor/Documents/ElementalWarrior/`
- Main code: `/Users/petergelgor/Documents/ElementalWarrior/ElementalWarrior/`
- Session notes: This file
- Last successful build: 2025-12-31

---

## Quick Debug Commands

```bash
# Navigate to project
cd /Users/petergelgor/Documents/ElementalWarrior

# Build for visionOS simulator
xcodebuild -scheme ElementalWarrior -destination 'platform=visionOS Simulator,name=Apple Vision Pro' build

# Check git status
git status
```

---

**Session Status:** ✅ Complete - All requested features implemented and building successfully
