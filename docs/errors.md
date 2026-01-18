# Thunderdome Collision Handoff (2026-01-12)

Use this file to pick up with a fresh context. The goal was to fix fireball collisions with the thunderdome dome walls (doors are openings). Floor/props collide fine; dome wall collisions are inconsistent or missing.

## Current symptom
- Fireball collisions with the dome walls are not working. Projectiles travel to max range (50m) and explode with no wall hit.
- Earlier: collisions worked when shooting perpendicular to doors but drifted behind walls as you rotate toward door directions (likely due to using a simple cylinder).
- **Regression (latest change):** after switching the dome collision to a convex hull from the dome mesh, the thunderdome no longer loads at all (previously it loaded after ~1 minute).

## Environment notes
- Immersive dome asset: `thunderdome_final.usdz`
- Dome mesh path (confirmed via candidate dump):
  - `ThunderdomeEnvironment/ThunderdomeEnvironment/root/dome/Mesh`
  - This had radius ~19.99, height ~39.98, center ~(0,0,9.81).
- Build requirement (per AGENTS): run
  - `xcodebuild -project ElementalWarrior.xcodeproj -scheme ElementalWarrior -destination 'platform=visionOS Simulator,name=Apple Vision Pro' | grep -A 5 -B 5 "BUILD"`

## Files touched
- `ElementalWarrior/Managers/ThunderdomeManager.swift`
- `ElementalWarrior/Managers/HandTrackingManager.swift`
- `ElementalWarrior/Managers/GestureTypes.swift`

## What was tried (chronological)
1. **Normal flipping + impact offset** in `HandTrackingManager` to push impacts toward the player. This made hits worse and was reverted.
2. **Dynamic collision shapes** for thunderdome:
   - Changed `generateCollisionShapes(recursive: true, static: false)` so collisions move with teleport.
3. **Collision shell (cylinder)** around the dome:
   - Added an open cylinder collision shell generated from visual bounds.
   - Double-sided triangles for inside raycasts.
   - This helped in some directions but failed near door openings due to the cylinder approximation.
4. **Candidate picker** to find the dome mesh by name/path:
   - Collected `visualBounds` per `ModelComponent` and logged candidates.
   - Override path was identified: `ThunderdomeEnvironment/ThunderdomeEnvironment/root/dome/Mesh`.
5. **Mesh-based collision**:
   - Added a collision component on the dome mesh directly.
   - Tried `ShapeResource.generateStaticMesh(from:)` (worked inconsistently).
   - Then switched to `ShapeResource.generateConvex(from:)` (current state). After this, wall collisions stopped entirely.

## Current state of key code
### `ElementalWarrior/Managers/HandTrackingManager.swift`
- `raycastProjectile` in thunderdome uses:
  - `CollisionSystem.raycastScene(..., minDistance: 0.0)`
- `adjustThunderdomeHit` only flips normals if they face the ray direction.
- Flamethrower raycast uses `minDistance: 0.02`.

### `ElementalWarrior/Managers/GestureTypes.swift`
- Removed `thunderdomeImpactOffset`.

### `ElementalWarrior/Managers/ThunderdomeManager.swift`
- `generateCollisionShapes(recursive: true, static: false)` for the loaded environment.
- Collision shell:
  - `collisionShellInset = 0.5`
  - `collisionShellSegments = 48`
  - Only used as fallback if mesh collision fails.
- Dome mesh collision (current):
  - `addDomeMeshCollision` uses `ShapeResource.generateConvex(from: model.mesh)`
  - Sets `CollisionComponent` on the dome mesh entity.
  - `collisionShellNameOverrides` includes:
    - `ThunderdomeEnvironment/ThunderdomeEnvironment/root/dome/Mesh`
    - `dome/mesh`
    - `dome`
- Candidate logging is now disabled.

## Likely issue now
The convex hull collision either:
- fails to generate (maybe shape too complex or invalid), or
- creates a hull that doesn’t actually intersect raycasts from inside (or gets overridden/ignored).
Additionally, the convex-hull generation may now be blocking or failing during load, causing the thunderdome to never finish loading.

## Recommended next steps
1. **Verify the dome mesh collision actually exists and is used**:
   - Add log in `addDomeMeshCollision` to confirm success or catch errors.
   - Log raycast hits in `CollisionSystem.raycastScene` to print `hit.entity.name` and `hit.distance` when collisions happen.
2. **Try `ShapeResource.generateStaticMesh(from:)` again but keep the cylinder shell**:
   - If static mesh collides but is flaky, combine the dome mesh collision with a slightly inset collision shell just as a fallback.
3. **Alternative: attach a simple analytic collision mesh**:
   - Build a *custom* dome collider mesh in RCP (no doors) and import as a hidden collision-only asset.
   - This avoids approximations from `visualBounds` and avoids convex hull issues.
4. **Check transforms/centering**:
   - The dome mesh center is offset in Z (~9.81). Make sure collision entities respect that offset.
5. **Confirm collision masks**:
   - All thunderdome collisions are using `CollisionGroups.thunderdome`.
   - Ensure dome mesh collision component uses that group and that raycasts use the same mask.

## Previous console errors (from the run before this handoff)
```
nw_socket_copy_info [C1:2] getsockopt TCP_INFO failed [102: Operation not supported on socket]
Type: Error | Timestamp: 2026-01-12 21:27:56.482798-05:00 | Process: ElementalWarrior | Library: Network | Subsystem: com.apple.network | Category: connection | TID: 0xb1f10
nw_socket_copy_info getsockopt TCP_INFO failed [102: Operation not supported on socket]
Type: Error | Timestamp: 2026-01-12 21:27:56.482825-05:00 | Process: ElementalWarrior | Library: Network | Subsystem: com.apple.network | Category:  | TID: 0xb1f10
<<<< FigAudioSession(AV) >>>> signalled err=-19224 at <>:612
Type: Error | Timestamp: 2026-01-12 21:28:06.173520-05:00 | Process: ElementalWarrior | Library: MediaToolbox | Subsystem: com.apple.coremedia | Category:  | TID: 0xb1f0d
Fireball template created programmatically
Explosion template created programmatically
Flamethrower template created programmatically
Combined flamethrower template created programmatically
[Thunderdome] Detected user height: 1.13 m (start Y: -0.13)
Type: stdio
TBB Global TLS count is not == 1, instead it is: 2
Type: Error | Timestamp: 2026-01-12 21:28:07.258652-05:00 | Process: ElementalWarrior | Library: libusd_ms.dylib | Subsystem: com.apple.usdlib | Category: tbbmain | TID: 0xb1f0f
IOSurface creation failed: e00002c2 parentID: 00000000 properties: {
    IOSurfaceAddress = 14071720064;
    IOSurfaceAllocSize = 10748540;
    IOSurfaceCacheMode = 0;
    IOSurfaceMapCacheAttribute = 1;
    IOSurfaceName = CMPhoto;
    IOSurfacePixelFormat = 1246774599;
}
Type: Error | Timestamp: 2026-01-12 21:28:18.622449-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfaceCacheMode
Type: Error | Timestamp: 2026-01-12 21:28:18.622478-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfacePixelFormat
Type: Error | Timestamp: 2026-01-12 21:28:18.622483-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfaceMapCacheAttribute
Type: Error | Timestamp: 2026-01-12 21:28:18.622487-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfaceAddress
Type: Error | Timestamp: 2026-01-12 21:28:18.622623-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfaceAllocSize
Type: Error | Timestamp: 2026-01-12 21:28:18.622630-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfaceName
Type: Error | Timestamp: 2026-01-12 21:28:18.622633-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
getImageCount:85: *** axr_data_create failed: axr_error_unsupported_EXR_type (-3)
Type: Error | Timestamp: 2026-01-12 21:28:25.620413-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
createImageAtIndex:2185: *** ERROR: createImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:25.620497-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
CGImageSourceCreateImageAtIndex:5179: *** ERROR: CGImageSourceCreateImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:25.620526-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
createImageAtIndex:2185: *** ERROR: createImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:25.620556-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
CGImageSourceCreateImageAtIndex:5179: *** ERROR: CGImageSourceCreateImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:25.620572-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
Failed to create an image from a CGImageSource during texture creation
Type: Error | Timestamp: 2026-01-12 21:28:25.620917-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create buffer from image due to invalid image
Type: Error | Timestamp: 2026-01-12 21:28:25.621334-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create buffer from image due to invalid image
Type: Error | Timestamp: 2026-01-12 21:28:25.621354-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create a texture because it is not backed by an image or data provider
Type: Error | Timestamp: 2026-01-12 21:28:25.621369-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create buffer from image during texture creation
Type: Error | Timestamp: 2026-01-12 21:28:25.621383-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create image buffer during texture creation
Type: Error | Timestamp: 2026-01-12 21:28:25.621437-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
getImageCount:85: *** axr_data_create failed: axr_error_unsupported_EXR_type (-3)
Type: Error | Timestamp: 2026-01-12 21:28:25.627667-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
createImageAtIndex:2185: *** ERROR: createImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:25.627738-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
CGImageSourceCreateImageAtIndex:5179: *** ERROR: CGImageSourceCreateImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:25.627759-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
createImageAtIndex:2185: *** ERROR: createImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:25.627780-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
CGImageSourceCreateImageAtIndex:5179: *** ERROR: CGImageSourceCreateImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:25.627794-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
Failed to create an image from a CGImageSource during texture creation
Type: Error | Timestamp: 2026-01-12 21:28:25.627806-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create buffer from image due to invalid image
Type: Error | Timestamp: 2026-01-12 21:28:25.627960-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create buffer from image due to invalid image
Type: Error | Timestamp: 2026-01-12 21:28:25.627984-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create a texture because it is not backed by an image or data provider
Type: Error | Timestamp: 2026-01-12 21:28:25.628000-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create buffer from image during texture creation
Type: Error | Timestamp: 2026-01-12 21:28:25.628018-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create image buffer during texture creation
Type: Error | Timestamp: 2026-01-12 21:28:25.628033-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 properties: {
    IOSurfaceAddress = 15092711296;
    IOSurfaceAllocSize = 13486775;
    IOSurfaceCacheMode = 0;
    IOSurfaceMapCacheAttribute = 1;
    IOSurfaceName = CMPhoto;
    IOSurfacePixelFormat = 1246774599;
}
Type: Error | Timestamp: 2026-01-12 21:28:30.828260-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfaceCacheMode
Type: Error | Timestamp: 2026-01-12 21:28:30.828282-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfacePixelFormat
Type: Error | Timestamp: 2026-01-12 21:28:30.828287-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfaceMapCacheAttribute
Type: Error | Timestamp: 2026-01-12 21:28:30.828290-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfaceAddress
Type: Error | Timestamp: 2026-01-12 21:28:30.828351-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfaceAllocSize
Type: Error | Timestamp: 2026-01-12 21:28:30.828360-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
IOSurface creation failed: e00002c2 parentID: 00000000 property: IOSurfaceName
Type: Error | Timestamp: 2026-01-12 21:28:30.828364-05:00 | Process: ElementalWarrior | Library: IOSurface | TID: 0xb1ecd
getImageCount:85: *** axr_data_create failed: axr_error_unsupported_EXR_type (-3)
Type: Error | Timestamp: 2026-01-12 21:28:30.964049-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
createImageAtIndex:2185: *** ERROR: createImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:30.964073-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
CGImageSourceCreateImageAtIndex:5179: *** ERROR: CGImageSourceCreateImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:30.964079-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
createImageAtIndex:2185: *** ERROR: createImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:30.964084-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
CGImageSourceCreateImageAtIndex:5179: *** ERROR: CGImageSourceCreateImageAtIndex[0] - 'EXR ' - failed to create image [-58]
Type: Error | Timestamp: 2026-01-12 21:28:30.964088-05:00 | Process: ElementalWarrior | Library: ImageIO | Subsystem: com.apple.imageio | Category: ElementalWarrior | TID: 0xb1ecd
Failed to create an image from a CGImageSource during texture creation
Type: Error | Timestamp: 2026-01-12 21:28:30.964150-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create buffer from image due to invalid image
Type: Error | Timestamp: 2026-01-12 21:28:30.964202-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create buffer from image due to invalid image
Type: Error | Timestamp: 2026-01-12 21:28:30.964208-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create a texture because it is not backed by an image or data provider
Type: Error | Timestamp: 2026-01-12 21:28:30.964212-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create buffer from image during texture creation
Type: Error | Timestamp: 2026-01-12 21:28:30.964216-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
Failed to create image buffer during texture creation
Type: Error | Timestamp: 2026-01-12 21:28:30.964221-05:00 | Process: ElementalWarrior | Library: CoreRE | Subsystem: com.apple.re | Category: Pipeline | TID: 0xb1ecd
```

## Notes about logs
The console had repeated EXR/IOSurface errors (likely unrelated to collisions, possibly texture format support). These were in `docs/errors.md` before this handoff.
