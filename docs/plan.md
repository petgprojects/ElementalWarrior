# Tutorial Bug Fixes Implementation Plan

## Files to Modify
- `ElementalWarrior/Managers/TutorialPlaybackManager.swift` - Main changes
- `ElementalWarrior/TutorialPreviewWindowView.swift` - Loading + gestures
- `ElementalWarrior/TutorialsDebugView.swift` - UI cleanup
- `ElementalWarrior/Effects/FireballEffects.swift` - Mega fireball + combine flash
- `ElementalWarrior/Effects/FlamethrowerEffects.swift` - Combine effect

---

## FIREBALL FIXES

### 1. Maintain - Wrong Hand Animation
**Issue:** USDZ file loading incorrectly (user sees wrong animation)
**Fix:**
- Add debug logging in `play()` to print loaded URL
- Verify `fireball_maintain_right.usdz` is correctly bundled
- Check Xcode project file references for duplicate/wrong files

### 2. Punch - Add Launch Animation
**Issue:** Fireball disappears at punch, no projectile flight
**Fix in `TutorialPlaybackManager.swift`:**
- Add `launchedProjectile`, `projectileVelocity`, `projectileLaunchTime` to `ActiveEffect`
- Create `launchFireball(from:direction:)` - clones fireball, adds trail, sets velocity
- Create `updateProjectile(deltaTime:)` - moves projectile, checks floor collision (Y<0)
- Create `createExplosionAtImpact(position:)` - spawns explosion + scorch mark
- In `fireballPunchRight` case: at 3.66s trigger launch, update projectile each frame

### 3. Cross-Punch - Wrong Hand + Add Launch
**Issue:** Fireball on LEFT hand instead of RIGHT; no launch animation
**Fix:**
- `resolveHandTargets()` assigns by X position - may be swapped at t=0
- Add tutorial-specific override or sample animation at t=1.0s to determine correct hand
- Add launch animation same as Punch (trigger at 2.33s)

### 4. Combine - Multiple Issues
**Issues:** Left fireball below hand; combined under wrong hand; no merge animation; no mega visual
**Fix:**
- Create hand-specific offsets: `leftFireballOffset = [0.3, 0.12, 0.18]` (mirror X)
- Create `createMegaFireball()` in FireballEffects.swift - enhanced particles, pulsing glow
- Create `createCombineFlashEffect()` - bright flash at merge point
- Show flash at t=1.30-1.36s (merge moment)

---

## FLAMETHROWER FIXES

### 1. Summon - Wrong Jet Direction
**Issue:** Jet from side of hand, not palm
**Fix:**
- Add `isFlamethrower` flag to `EffectAttachment`
- Create `applyFlamethrowerAnchor()` with palm-forward rotation correction
- Calculate palm forward direction from joint hierarchy
- Apply 90-degree rotation correction to align +Z jet with palm forward

### 2. Combine - Wrong Direction + No Combine Animation
**Fix:**
- Apply same jet direction fix
- Create `createFlamethrowerCombineEffect()` - flash at merge point
- Show at t=3.0s (combine) and t=5.0s (split)

---

## WALL FIXES (All in `TutorialPlaybackManager.swift`)

### 1. Position - Below Hands Instead of In Front at Floor
**Fix:**
- Calculate position from hand midpoint: `[midpoint.x, 0, midpoint.z - 0.3]`
- Y=0 for floor level, Z offset for "in front"
- Update position each frame based on hand anchors

### 2. Orientation - Perpendicular Instead of Parallel
**Fix:**
- Calculate rotation from hand span direction
- `angle = atan2(handDirection.z, handDirection.x)`
- Wall runs along line between hands (spanning left-right)

### 3. Color - Red Instead of Blue
**Fix:**
- Swap palette usage: start with `highlightFireWallPalette()` (blue)
- In `wallConfirmBoth`: switch to `defaultFireWallPalette()` (red) after t=3.33s

### 4. Initial Height - Too High
**Fix:**
- Initialize with `wallMinHeight` (0.06) instead of `wallBaseHeight` (0.7)
- Wall starts as ember line, grows according to animation timing

### 5. Initial Width - Too Narrow
**Fix:**
- Change `wallBaseWidth` from 0.7 to 1.4 (double)
- Or create `wallInitialWidth = 1.4` constant

---

## GENERAL FIXES

### 1. Loading Screen
**Fix in `TutorialPlaybackManager.swift`:**
- Add `var isLoading: Bool = false`
- Set `isLoading = true` at start of `play()`, `false` in defer block

**Fix in `TutorialPreviewWindowView.swift`:**
- Add overlay with `ProgressView()` when `isLoading == true`

### 2. Pinch/Drag Gestures
**Fix in `TutorialPlaybackManager.swift`:**
- Add `userScale: Float = 1.0` and `userOffset: SIMD3<Float> = .zero`
- Add `applyUserTransform()` and `resetUserTransform()` methods

**Fix in `TutorialPreviewWindowView.swift`:**
- Add `MagnifyGesture` for scale (clamp 0.3x - 3.0x)
- Add `DragGesture` for move (convert 2D to 3D offset)
- Reset on `onDisappear`

### 3. UI Cleanup
**Fix in `TutorialsDebugView.swift`:**
- Redesign `TutorialsDetailView` with better layout
- Create `TutorialDetailPanel` view with:
  - Title and description
  - Play/Stop controls
  - Animation info (duration, status)
  - Error display
  - Tips section about gestures

---

## Implementation Order

**Phase 1 - Critical (blocking issues):**
1. Wall fixes (position, orientation, color, height, width)
2. Flamethrower jet direction
3. Cross-punch hand assignment

**Phase 2 - Features:**
4. Punch/Cross-punch launch animations
5. Fireball combine (mega visual + flash)
6. Flamethrower combine effect

**Phase 3 - Polish:**
7. Loading screen
8. Pinch/drag gestures
9. UI cleanup

**Phase 4 - Investigation:**
10. Maintain animation file issue (may need Xcode project inspection)
