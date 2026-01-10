# Building a Themed Arena Environment for VisionOS

This guide walks you through creating an immersive arena environment for Elemental Warrior. By the end, you'll have a fully themed 3D arena where players can firebend and eventually battle AI enemies.

---

## Table of Contents

1. [Understanding Immersion Styles](#1-understanding-immersion-styles)
2. [Tools You'll Need](#2-tools-youll-need)
3. [Option A: Full Virtual Arena](#3-option-a-full-virtual-arena)
4. [Option B: Mixed Reality Arena Elements](#4-option-b-mixed-reality-arena-elements)
5. [Creating Arena Assets](#5-creating-arena-assets)
6. [Loading Environments in Code](#6-loading-environments-in-code)
7. [Lighting Your Arena](#7-lighting-your-arena)
8. [Adding Spatial Audio](#8-adding-spatial-audio)
9. [Performance Optimization](#9-performance-optimization)
10. [Integration with Hand Tracking](#10-integration-with-hand-tracking)
11. [Example: Fire Nation Arena](#11-example-fire-nation-arena)

---

## 1. Understanding Immersion Styles

VisionOS offers three immersion styles. Your choice determines how the arena appears:

| Style | What You See | Best For |
|-------|--------------|----------|
| `.mixed` | Real room + virtual objects | AR overlays, objects in your space |
| `.full` | Complete virtual world | Fully themed environments |
| `.progressive` | Gradual blend (user controls) | Flexible experiences |

**Current Setup**: Your app uses `.mixed` (passthrough with fireballs).

**Recommendation for Arena**: Use `.full` immersion for a complete themed experience, or `.progressive` to let users choose.

### Changing Immersion Style

In `ElementalWarriorApp.swift`, change:

```swift
// Current (mixed reality)
.immersionStyle(selection: .constant(.mixed), in: .mixed)

// For full virtual arena
.immersionStyle(selection: .constant(.full), in: .full)

// For user-controlled (progressive)
@State private var immersionStyle: ImmersionStyle = .progressive
// ...
.immersionStyle(selection: $immersionStyle, in: .mixed, .progressive, .full)
```

---

## 2. Tools You'll Need

### Required (Free with Xcode)
- **Reality Composer Pro** - Create and compose 3D scenes, materials, and particle effects
- **Xcode** - Build and run your app

### For Creating Custom 3D Assets
- **Blender** (Free) - Create 3D models, export as USDZ
- **Reality Converter** (Free, Apple) - Convert FBX/OBJ/GLTF to USDZ

### Asset Sources (Optional)
- **Sketchfab** - Free and paid 3D models
- **TurboSquid** - Professional 3D assets
- **Apple's Sample Assets** - Reality Composer Pro includes starter content

---

## 3. Option A: Full Virtual Arena

This approach replaces the real world entirely with a virtual arena.

### Step 1: Create a Reality Composer Pro Project

1. In Xcode, go to **File → New → File**
2. Choose **Reality Composer Pro Project**
3. Name it `ArenaEnvironment`
4. This creates a `.rkassets` bundle in your project

### Step 2: Build the Arena Scene

1. Open the `.rkassets` file (double-click opens Reality Composer Pro)
2. Create a new scene called `FireArena.usda`
3. Add these core elements:

#### Ground/Floor
```
Right-click → Add → Primitive → Plane
- Scale: 50m x 50m
- Material: Create a stone/volcanic texture
- Position: Y = 0 (ground level)
```

#### Arena Walls
```
Add → Primitive → Cylinder (for circular arena)
- Or use Box primitives for rectangular arena
- Scale appropriately (e.g., 30m diameter, 5m height)
- Apply stone/metal material
- Make hollow (inner cylinder or boolean subtract)
```

#### Skybox/Environment
```
Add → Environment → Skybox
- Use HDR image for realistic lighting
- Options: volcanic sky, night sky with fire glow, stormy clouds
```

### Step 3: Export and Reference

Reality Composer Pro automatically compiles assets. Reference them in code:

```swift
// Load the arena scene
let arenaScene = try await Entity.load(named: "FireArena", in: arenaEnvironmentBundle)
content.add(arenaScene)
```

---

## 4. Option B: Mixed Reality Arena Elements

Keep the real world visible but add virtual arena elements around the player.

### What to Add
- Floating torches with fire effects
- Virtual pillars/columns
- Floating platforms
- Magical barriers/boundaries
- Ambient particle effects (floating embers, smoke)

### Advantages
- Players stay aware of real surroundings (safer)
- Lighter performance requirements
- Works in any room size

### Implementation Approach

```swift
struct ArenaImmersiveView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        RealityView { content in
            // Add hand tracking root
            content.add(appModel.handTrackingManager.rootEntity)

            // Add arena decorations around the player
            await addArenaTorches(to: content)
            await addFloatingEmbers(to: content)
            await addArenaBoundary(to: content)
        }
        .task {
            await appModel.handTrackingManager.startHandTracking()
        }
    }
}
```

---

## 5. Creating Arena Assets

### Method 1: Reality Composer Pro (Easiest)

Best for: Simple geometry, combining existing assets, materials, lighting

1. Open your `.rkassets` project
2. Use built-in primitives (cubes, spheres, cylinders)
3. Apply materials from the library
4. Add lights and particle effects
5. Group into reusable prefabs

### Method 2: Blender → USDZ (Most Flexible)

Best for: Custom detailed models, complex geometry

#### Blender Workflow:

1. **Model your asset** in Blender
   - Keep polygon count reasonable (< 100k for large objects)
   - Use quads, avoid n-gons

2. **UV Unwrap** for textures
   - Select all faces → U → Smart UV Project

3. **Apply Materials**
   - Use Principled BSDF shader
   - Supported: Base Color, Metallic, Roughness, Normal, Emission

4. **Export as GLTF/GLB**
   ```
   File → Export → glTF 2.0
   - Format: GLB (binary)
   - Include: Selected Objects
   - Transform: +Y Up
   - Geometry: Apply Modifiers, UVs, Normals
   - Materials: Export
   ```

5. **Convert to USDZ**
   - Open Reality Converter (or use command line)
   - Drag in your .glb file
   - Export as .usdz
   - Add to Xcode project

#### Command Line Conversion:
```bash
# Using Apple's usdzconvert tool (comes with Xcode command line tools)
xcrun usdz_converter input.glb output.usdz
```

### Method 3: Download Pre-made Assets

1. Find USDZ-compatible models on Sketchfab, TurboSquid, etc.
2. Download in GLTF/FBX/OBJ format
3. Convert to USDZ using Reality Converter
4. Import into Reality Composer Pro or directly into Xcode

---

## 6. Loading Environments in Code

### Loading from Reality Composer Pro Bundle

```swift
import RealityKit

struct ArenaImmersiveView: View {
    var body: some View {
        RealityView { content in
            do {
                // Load entire scene from Reality Composer Pro
                let arena = try await Entity.load(named: "FireArena",
                                                   in: realityKitContentBundle)
                content.add(arena)
            } catch {
                print("Failed to load arena: \(error)")
            }
        }
    }
}
```

### Loading Individual USDZ Files

```swift
// Load a single USDZ asset from bundle
let torch = try await Entity.load(named: "Torch") // Torch.usdz in bundle
torch.position = [2, 0, -3] // 2m right, 3m forward
content.add(torch)
```

### Loading from URL (Remote Assets)

```swift
let url = URL(string: "https://example.com/arena.usdz")!
let arena = try await Entity.load(contentsOf: url)
content.add(arena)
```

### Programmatic Entity Creation

For simple shapes, create them in code:

```swift
func createArenaFloor() -> Entity {
    let floor = Entity()

    // Create mesh
    let mesh = MeshResource.generatePlane(width: 50, depth: 50)

    // Create material
    var material = PhysicallyBasedMaterial()
    material.baseColor = .init(tint: .gray)
    material.roughness = 0.8
    material.metallic = 0.2

    // Combine into model
    let modelComponent = ModelComponent(mesh: mesh, materials: [material])
    floor.components.set(modelComponent)

    // Add collision for fireballs
    let collision = CollisionComponent(shapes: [.generateBox(width: 50, height: 0.1, depth: 50)])
    floor.components.set(collision)

    return floor
}
```

---

## 7. Lighting Your Arena

Proper lighting is critical for immersion. VisionOS supports several light types.

### Image-Based Lighting (IBL) - Recommended

Uses an HDR environment map for realistic, natural lighting:

```swift
// In Reality Composer Pro:
// 1. Add → Environment → Image Based Light
// 2. Assign an HDR image (volcanic_sky.hdr, dungeon.hdr, etc.)

// Or in code:
let iblResource = try await EnvironmentResource.load(named: "fire_arena_lighting")
let iblComponent = ImageBasedLightComponent(source: .single(iblResource),
                                             intensityExponent: 1.0)
arenaEntity.components.set(iblComponent)
arenaEntity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: arenaEntity))
```

### Point Lights

Good for torches, fireballs, localized light sources:

```swift
func createTorchLight() -> Entity {
    let light = Entity()

    var pointLight = PointLightComponent()
    pointLight.color = .orange
    pointLight.intensity = 5000 // lumens
    pointLight.attenuationRadius = 5.0 // meters

    light.components.set(pointLight)
    return light
}
```

### Spot Lights

Good for dramatic directional lighting:

```swift
var spotlight = SpotLightComponent()
spotlight.color = .red
spotlight.intensity = 10000
spotlight.innerAngleInDegrees = 30
spotlight.outerAngleInDegrees = 45
spotlight.attenuationRadius = 20

entity.components.set(spotlight)
```

### Directional Lights

Sun/moon lighting for outdoor arenas:

```swift
var directionalLight = DirectionalLightComponent()
directionalLight.color = .init(red: 1.0, green: 0.9, blue: 0.8, alpha: 1.0)
directionalLight.intensity = 2000
directionalLight.isRealWorldProxy = false // false for virtual environments

sunEntity.components.set(directionalLight)
sunEntity.orientation = simd_quatf(angle: -.pi/4, axis: [1, 0, 0]) // 45° down
```

### Dynamic Lighting from Fireballs

Your fireballs already have PointLight components. They'll naturally illuminate the arena as they move!

---

## 8. Adding Spatial Audio

Spatial audio makes the arena feel alive. VisionOS positions sound in 3D space.

### Ambient Arena Sounds

```swift
func addAmbientAudio(to entity: Entity) async {
    guard let audioResource = try? await AudioFileResource.load(
        named: "arena_ambience", // arena_ambience.mp3 or .wav in bundle
        configuration: .init(
            loadingStrategy: .preload,
            shouldLoop: true
        )
    ) else { return }

    let audioController = entity.prepareAudio(audioResource)
    audioController.gain = -10 // dB, quieter background
    audioController.play()
}
```

### Positional Sound Sources

```swift
// Torch crackling sound positioned at torch location
func addTorchAudio(to torch: Entity) async {
    guard let crackle = try? await AudioFileResource.load(
        named: "fire_crackle",
        configuration: .init(shouldLoop: true)
    ) else { return }

    // SpatialAudioComponent makes sound come from entity's position
    var spatialAudio = SpatialAudioComponent()
    spatialAudio.reverbLevel = 0.3
    spatialAudio.directivity = .beam(focus: 0.5)
    torch.components.set(spatialAudio)

    let controller = torch.prepareAudio(crackle)
    controller.gain = -5
    controller.play()
}
```

### Reverb and Environment

```swift
// Add reverb zone for arena acoustics
var reverb = ReverbComponent()
reverb.reverbPreset = .largeRoom // or .mediumHall for bigger arenas
arenaEntity.components.set(reverb)
```

---

## 9. Performance Optimization

VisionOS renders at 90fps for each eye. Keep performance tight.

### Polygon Budget Guidelines

| Element | Target Poly Count |
|---------|-------------------|
| Arena floor | 2-10 polygons |
| Walls/structures | 1,000-10,000 |
| Props (torches, etc.) | 100-1,000 each |
| Total scene | < 500,000 |

### Level of Detail (LOD)

For large arenas, use distance-based LOD:

```swift
// In Reality Composer Pro, set up LOD variants
// Or manually swap models based on distance:
func updateLOD(for entity: Entity, cameraPosition: SIMD3<Float>) {
    let distance = simd_distance(entity.position, cameraPosition)

    if distance > 20 {
        // Use low-poly version
        entity.isEnabled = false
        lowPolyVersion.isEnabled = true
    } else {
        entity.isEnabled = true
        lowPolyVersion.isEnabled = false
    }
}
```

### Occlusion Culling

RealityKit handles this automatically, but help it by:
- Breaking large meshes into smaller chunks
- Using opaque materials when possible
- Avoiding excessive transparency

### Texture Optimization

- Use compressed textures (ASTC format)
- Resolution: 1024x1024 for most surfaces, 2048x2048 for hero elements
- Reality Composer Pro compresses automatically

### Reduce Draw Calls

- Combine meshes that share materials
- Use texture atlases for multiple props
- Minimize unique materials

---

## 10. Integration with Hand Tracking

Your arena needs to work with the existing hand tracking system.

### Updated ArenaImmersiveView Structure

```swift
import SwiftUI
import RealityKit

struct ArenaImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var arenaRoot: Entity?

    var body: some View {
        RealityView { content in
            // 1. Load arena environment
            do {
                let arena = try await Entity.load(named: "FireArena",
                                                   in: realityKitContentBundle)
                arena.name = "ArenaEnvironment"
                content.add(arena)
                arenaRoot = arena

                // 2. Add ambient audio
                await addAmbientAudio(to: arena)

            } catch {
                print("Failed to load arena: \(error)")
                // Fallback: create simple floor
                let floor = createSimpleFloor()
                content.add(floor)
            }

            // 3. Add hand tracking (your existing system)
            content.add(appModel.handTrackingManager.rootEntity)

        } update: { content in
            // Update arena elements if needed (e.g., dynamic lighting)
        }
        .task {
            // Start hand tracking
            await appModel.handTrackingManager.startHandTracking()
        }
    }

    func createSimpleFloor() -> Entity {
        let floor = Entity()
        let mesh = MeshResource.generatePlane(width: 30, depth: 30)
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(red: 0.2, green: 0.1, blue: 0.1, alpha: 1))
        material.roughness = 0.9
        floor.components.set(ModelComponent(mesh: mesh, materials: [material]))
        floor.position.y = -1.5 // Below player
        return floor
    }

    func addAmbientAudio(to entity: Entity) async {
        // Add looping ambient sound
    }
}
```

### Collision with Arena Geometry

Your collision system uses mesh scanning. For virtual arenas, add explicit collision:

```swift
// In Reality Composer Pro:
// Select mesh → Add Component → Collision
// Choose "Mesh" shape type for accurate collision

// Or in code:
func addArenaCollision(to arena: Entity) {
    arena.enumerateHierarchy { entity in
        // Add collision to all meshes with "wall" in name
        if entity.name.contains("wall") || entity.name.contains("floor") {
            if let model = entity.components[ModelComponent.self] {
                let shape = ShapeResource.generateConvex(from: model.mesh)
                entity.components.set(CollisionComponent(shapes: [shape]))
            }
        }
    }
}
```

---

## 11. Example: Fire Nation Arena

Here's a complete example of a themed fire arena.

### Asset List

Create or acquire these assets:
1. **Arena floor** - Circular stone platform with cracks and lava veins
2. **Pillars** (8x) - Stone columns with fire braziers on top
3. **Arena walls** - Low walls with dragon motifs
4. **Skybox** - Volcanic sky with smoke and red glow
5. **Torches** (16x) - Wall-mounted fire torches
6. **Central platform** - Raised fighting area

### Reality Composer Pro Scene Structure

```
FireArena.usda
├── Environment
│   ├── Skybox (volcanic_sky.hdr)
│   └── ImageBasedLight (fire_arena_ibl.hdr)
├── ArenaStructure
│   ├── Floor (CircularPlatform.usdz)
│   ├── Walls (ArenaWalls.usdz)
│   ├── Pillars (group of 8 PillarWithBrazier.usdz)
│   └── CentralPlatform (FightingRing.usdz)
├── Decorations
│   ├── Torches (group of 16 WallTorch.usdz)
│   ├── Banners (FireNationBanner.usdz)
│   └── DragonStatues (2x DragonStatue.usdz)
├── Effects
│   ├── AmbientEmbers (ParticleEmitter)
│   ├── LavaGlow (PointLights)
│   └── TorchFlames (ParticleEmitters)
└── Audio
    ├── AmbientLava (looping)
    ├── DistantDrums (looping, quiet)
    └── WindHowl (looping)
```

### Loading Code

```swift
struct ArenaImmersiveView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        RealityView { content in
            // Load the complete Fire Nation arena
            do {
                let arena = try await Entity.load(named: "FireArena",
                                                   in: realityKitContentBundle)

                // Position arena so player stands at center
                // Player is at origin (0, 0, 0), floor at Y = -1.5m (typical floor)
                arena.position = SIMD3(0, -1.5, 0)

                content.add(arena)

                // Start ambient effects
                await activateArenaEffects(arena)

                // Add collision for fireballs
                addArenaCollision(to: arena)

            } catch {
                print("Failed to load arena: \(error)")
            }

            // Add hand tracking
            content.add(appModel.handTrackingManager.rootEntity)
        }
        .task {
            await appModel.handTrackingManager.startHandTracking()
        }
    }

    func activateArenaEffects(_ arena: Entity) async {
        // Find and start particle emitters
        arena.enumerateHierarchy { entity in
            if let particles = entity.components[ParticleEmitterComponent.self] {
                var emitter = particles
                emitter.isEmitting = true
                entity.components.set(emitter)
            }
        }

        // Start ambient audio
        if let audioEntity = arena.findEntity(named: "AmbientLava") {
            if let resource = try? await AudioFileResource.load(named: "lava_ambience") {
                let controller = audioEntity.prepareAudio(resource)
                controller.gain = -15
                controller.play()
            }
        }
    }

    func addArenaCollision(to arena: Entity) {
        arena.enumerateHierarchy { entity in
            // Add collision to structural elements
            guard let model = entity.components[ModelComponent.self] else { return }

            let structuralNames = ["floor", "wall", "pillar", "platform"]
            let isStructural = structuralNames.contains {
                entity.name.lowercased().contains($0)
            }

            if isStructural {
                do {
                    let shape = try ShapeResource.generateConvex(from: model.mesh)
                    entity.components.set(CollisionComponent(shapes: [shape]))
                } catch {
                    // Fallback to bounding box
                    let bounds = entity.visualBounds(relativeTo: nil)
                    let box = ShapeResource.generateBox(size: bounds.extents)
                    entity.components.set(CollisionComponent(shapes: [box]))
                }
            }
        }
    }
}
```

---

## Quick Start Checklist

1. [ ] Decide: Full virtual (`.full`) or mixed reality (`.mixed`) arena?
2. [ ] Create Reality Composer Pro project in Xcode
3. [ ] Design arena layout (floor, walls, decorations)
4. [ ] Create or download 3D assets (USDZ format)
5. [ ] Set up lighting (IBL + point lights for torches)
6. [ ] Add spatial audio (ambient + positional sounds)
7. [ ] Load arena in ArenaImmersiveView
8. [ ] Add collision components for fireball interaction
9. [ ] Test and optimize performance
10. [ ] Iterate on theme and atmosphere

---

## Resources

### Apple Documentation
- [Creating Immersive Spaces](https://developer.apple.com/documentation/visionos/creating-immersive-spaces)
- [Reality Composer Pro](https://developer.apple.com/documentation/realitykit/reality-composer-pro)
- [RealityKit Lighting](https://developer.apple.com/documentation/realitykit/lighting)

### Sample Code
- [Happy Beam](https://developer.apple.com/documentation/visionos/happybeam) - VisionOS game sample
- [Destination Video](https://developer.apple.com/documentation/visionos/destination-video) - Immersive environments
- [Diorama](https://developer.apple.com/documentation/visionos/diorama) - 3D scene composition

### Asset Resources
- [Apple AR Quick Look Gallery](https://developer.apple.com/augmented-reality/quick-look/)
- [Sketchfab](https://sketchfab.com) - 3D model marketplace
- [Poly Haven](https://polyhaven.com) - Free HDRIs for lighting

---

## Next Steps

After completing your arena:
1. Add AI enemies that spawn in the arena
2. Implement health/damage system
3. Create multiple arena variants (Water Tribe, Earth Kingdom, Air Temple)
4. Add arena hazards (lava pits, falling rocks, etc.)
