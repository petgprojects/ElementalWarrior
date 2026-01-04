# Floating Hand Tutorial Research for VisionOS

## Overview

This document provides comprehensive research on implementing floating hand animations to teach users how to activate various features in Elemental Warrior. The goal is to display an animated 3D hand demonstrating gestures like "open palm facing up" (spawn fireball), "punch" (throw fireball), "stop gesture" (flamethrower), etc.

## Executive Summary

There is **no built-in Apple API** for displaying pre-recorded hand gesture tutorials. However, there are **four viable approaches** to implement this feature, ranging from simple joint-based visualization to using third-party frameworks or pre-animated 3D hand models.

**Recommended Approach**: A hybrid solution using **Approach 2 (Programmatic Joint Skeleton)** with **Approach 3 (Pre-Animated USDZ Hand Models)** provides the best balance of flexibility and visual quality.

---

## Available Approaches

### Approach 1: Joint Sphere Visualization (Simplest)

Create simple geometric shapes (spheres) at each hand joint position and animate their transforms programmatically.

#### How It Works

1. Create 27 sphere entities per hand (one per joint from `HandSkeleton.JointName.allCases`)
2. Position spheres in the target gesture pose
3. Animate sphere positions using `FromToByAnimation` or `SampledAnimation`
4. Optionally connect spheres with cylinder "bones" for skeletal appearance

#### Implementation

```swift
import RealityKit
import ARKit

class TutorialHandVisualization {
    private var jointEntities: [HandSkeleton.JointName: Entity] = [:]
    private let rootEntity = Entity()

    func createHandSkeleton() -> Entity {
        // Create spheres for each joint
        for jointName in HandSkeleton.JointName.allCases {
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.006),
                materials: [SimpleMaterial(color: .cyan, isMetallic: false)]
            )
            sphere.name = jointName.description
            jointEntities[jointName] = sphere
            rootEntity.addChild(sphere)
        }

        // Optionally add bone connections between joints
        addBoneConnections()

        return rootEntity
    }

    func animateToGesture(pose: [HandSkeleton.JointName: simd_float4x4], duration: TimeInterval) {
        for (jointName, targetTransform) in pose {
            guard let entity = jointEntities[jointName] else { continue }

            let animation = FromToByAnimation(
                to: Transform(matrix: targetTransform),
                duration: duration,
                bindTarget: .transform
            )

            if let resource = try? AnimationResource.generate(with: animation) {
                entity.playAnimation(resource)
            }
        }
    }

    private func addBoneConnections() {
        // Create cylinder connections between parent-child joints
        // Use HandSkeleton's parent relationships
    }
}
```

#### Predefined Gesture Poses

You'll need to define the joint transforms for each gesture you want to demonstrate:

```swift
enum TutorialGesturePose {
    case openPalmUp      // Spawn fireball gesture
    case closedFist      // Part of punch gesture
    case punchMotion     // Animated punch sequence
    case stopGesture     // Flamethrower activation
    case zombiePose      // Fire wall placement

    var jointTransforms: [HandSkeleton.JointName: simd_float4x4] {
        switch self {
        case .openPalmUp:
            return Self.createOpenPalmUpPose()
        case .closedFist:
            return Self.createClosedFistPose()
        // ... etc
        }
    }

    private static func createOpenPalmUpPose() -> [HandSkeleton.JointName: simd_float4x4] {
        // Define transforms for each joint in open palm position
        // Palm facing up, fingers extended
        var poses: [HandSkeleton.JointName: simd_float4x4] = [:]

        // Wrist at origin, palm facing up (Y-axis pointing up)
        poses[.wrist] = matrix_identity_float4x4

        // Fingers extended outward
        // Each finger has: knuckle -> intermediate -> tip
        // Calculate transforms based on natural hand proportions

        return poses
    }
}
```

#### Pros
- Lightweight and fast to implement
- No external assets required
- Full programmatic control over all joint positions
- Easy to synchronize with audio/text instructions

#### Cons
- Visually abstract (spheres don't look like a hand)
- Requires manually defining all joint positions for each gesture
- No skin/mesh for realistic appearance

---

### Approach 2: Programmatic Skeletal Hand Model

Use a rigged 3D hand mesh with skeleton and animate joints programmatically using RealityKit's `SkeletalPosesComponent`.

#### How It Works

1. Import a rigged USDZ hand model with skeleton matching ARKit's hand joint structure
2. Access the `SkeletalPosesComponent` attached to the model entity
3. Update joint transforms programmatically each frame
4. Use `SampledAnimation` for keyframe-based gesture animations

#### Implementation

```swift
import RealityKit

class SkeletalTutorialHand {
    private var handEntity: Entity?
    private var skeletalPoses: SkeletalPosesComponent?

    func loadHandModel() async throws -> Entity {
        // Load rigged hand model from USDZ
        let hand = try await Entity.load(named: "TutorialHand")
        self.handEntity = hand

        // Get the skeletal poses component (automatically attached to skinned meshes)
        if let modelEntity = hand.findEntity(named: "HandMesh") as? ModelEntity {
            self.skeletalPoses = modelEntity.components[SkeletalPosesComponent.self]
        }

        return hand
    }

    func updateJointPose(jointName: String, rotation: simd_quatf, translation: SIMD3<Float>) {
        guard var poses = skeletalPoses else { return }

        // Query for specific joint and update transform
        if var jointPose = poses.poses["default"]?.jointTransform(named: jointName) {
            jointPose.rotation = rotation
            jointPose.translation = translation
            // Apply updated pose
        }
    }

    func playGestureAnimation(keyframes: [GestureKeyframe]) {
        // Create SampledAnimation from keyframes
        let samples = keyframes.map { keyframe in
            JointTransforms(/* joint transforms at this keyframe */)
        }

        let animation = SampledAnimation(
            frames: samples,
            frameInterval: 1.0 / 30.0, // 30 FPS
            bindTarget: .jointTransforms
        )

        if let resource = try? AnimationResource.generate(with: animation),
           let entity = handEntity {
            entity.playAnimation(resource)
        }
    }
}

struct GestureKeyframe {
    let time: TimeInterval
    let jointTransforms: [String: (rotation: simd_quatf, translation: SIMD3<Float>)]
}
```

#### Creating a Compatible Hand Model

The hand model skeleton must match the joint names used by ARKit. You can create this in Blender:

1. **Model the hand mesh** with proper topology for deformation
2. **Create an armature** with bones matching `HandSkeleton.JointName`:
   - `wrist`, `thumbKnuckle`, `thumbIntermediateBase`, `thumbIntermediateTip`, `thumbTip`
   - `indexFingerMetacarpal`, `indexFingerKnuckle`, `indexFingerIntermediateBase`, `indexFingerIntermediateTip`, `indexFingerTip`
   - Similar for middle, ring, and little fingers
   - `forearmWrist`, `forearmArm`
3. **Skin the mesh** to the armature with proper weight painting
4. **Export as USDZ** via FBX → Reality Converter pipeline

#### Pros
- Realistic hand appearance with proper mesh and skin
- Full control over animation timing and transitions
- Can match your app's visual style (cartoon, realistic, ghostly, etc.)
- Skeletal animation is efficient

#### Cons
- Requires creating or sourcing a rigged hand model
- Skeleton bone names must match exactly
- More complex implementation than sphere approach
- Need to manually define all keyframe poses

---

### Approach 3: Pre-Animated USDZ Hand Models

Create complete gesture animations in Blender or Maya and export as self-contained USDZ files with baked animations.

#### How It Works

1. Create animated hand sequences in Blender/Maya for each gesture
2. Export each gesture as a separate USDZ file with embedded animation
3. Load and play animations using `Entity.load()` and `playAnimation()`

#### Implementation

```swift
import RealityKit

class PreAnimatedTutorialHand {

    enum GestureAnimation: String, CaseIterable {
        case spawnFireball = "TutorialHand_SpawnFireball"
        case punchThrow = "TutorialHand_Punch"
        case flamethrower = "TutorialHand_Flamethrower"
        case zombiePose = "TutorialHand_ZombiePose"
        case megaCombine = "TutorialHand_MegaCombine"

        var filename: String { "\(rawValue).usdz" }
    }

    private var cachedAnimations: [GestureAnimation: Entity] = [:]

    func preloadAnimations() async {
        for gesture in GestureAnimation.allCases {
            do {
                // Use Entity.load() to include animations (not loadModel)
                let entity = try await Entity.load(named: gesture.rawValue)
                cachedAnimations[gesture] = entity
            } catch {
                print("Failed to load \(gesture): \(error)")
            }
        }
    }

    func showGestureTutorial(gesture: GestureAnimation, at position: SIMD3<Float>) -> Entity? {
        guard let template = cachedAnimations[gesture] else { return nil }

        // Clone the template
        let tutorialHand = template.clone(recursive: true)
        tutorialHand.position = position

        // Position in front of user, facing them
        tutorialHand.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])

        // Play the animation
        if let animation = tutorialHand.availableAnimations.first {
            tutorialHand.playAnimation(animation.repeat())
        }

        return tutorialHand
    }

    func showAnimationWithInstructions(
        gesture: GestureAnimation,
        instructions: String,
        at position: SIMD3<Float>,
        parent: Entity
    ) {
        guard let handEntity = showGestureTutorial(gesture: gesture, at: position) else { return }

        // Add floating text label
        let textMesh = MeshResource.generateText(
            instructions,
            extrusionDepth: 0.002,
            font: .systemFont(ofSize: 0.05),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let textEntity = ModelEntity(mesh: textMesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
        textEntity.position = [0, 0.15, 0] // Above the hand
        handEntity.addChild(textEntity)

        parent.addChild(handEntity)
    }
}
```

#### Animation Workflow in Blender

```
1. Open Blender with rigged hand model
2. Set keyframes for gesture sequence:
   - Frame 1-30: Start pose (relaxed hand)
   - Frame 31-60: Transition to gesture
   - Frame 61-90: Hold gesture pose
   - Frame 91-120: Return to relaxed (optional)
3. Export:
   - File → Export → FBX
   - Check "Bake Animation"
   - Import FBX into Reality Converter
   - Export as USDZ
```

#### Pros
- Highest visual quality with professional animations
- Animations are self-contained and easy to use
- Can be created by artists without code changes
- Smooth, natural-looking motion

#### Cons
- Requires 3D animation skills or outsourcing
- Less flexible at runtime (can't modify poses dynamically)
- Asset file size increases with each animation
- Need to create new assets for each gesture

---

### Approach 4: GestureKit Framework (Third-Party)

Use the [GestureKit](https://github.com/nthState/GestureKit) framework which provides USDZ animated gesture tutorials out of the box.

#### How It Works

GestureKit is a VisionOS framework that:
1. Packages gesture definitions with USDZ tutorial animations
2. Provides gesture detection from ARKit hand data
3. Includes virtual hand visualization for debugging

#### Implementation

```swift
import GestureKit

// Configure gesture detection with tutorial animations
let configuration = GestureDetectorConfiguration(packages: [
    Bundle.main.url(forResource: "OpenPalmUp", withExtension: "gesturecomposer")!,
    Bundle.main.url(forResource: "Punch", withExtension: "gesturecomposer")!
])

let detector = GestureDetector(configuration: configuration)

// Display tutorial animation for a gesture
if let tutorialEntity = detector.tutorialAnimation(for: "OpenPalmUp") {
    tutorialEntity.position = [0, 1.5, -1]
    rootEntity.addChild(tutorialEntity)
    tutorialEntity.playAnimation(tutorialEntity.availableAnimations.first!)
}

// Detect when user performs gesture
for await gesture in detector.detectedGestures {
    print("User performed: \(gesture.name)")
    // Advance tutorial, show success feedback
}
```

#### GestureComposer Package Format

The `.gesturecomposer` packages contain:
- Gesture definition (joint relationships, thresholds)
- USDZ animated 3D files showing the gesture
- Metadata (name, description, difficulty)

You can create custom packages using the Gesture Composer app (available on VisionOS App Store) or the web tool at gesturecomposer.com.

#### Virtual Hands Visualization

GestureKit includes a `VirtualHands` class for debugging:

```swift
let config = VirtualHandsConfiguration(
    leftHand: HandConfiguration(
        color: .cyan,
        modelURL: Bundle.main.url(forResource: "LeftHand", withExtension: "usdz"),
        renderModel: true,
        renderJoints: true,
        renderBones: true
    ),
    rightHand: HandConfiguration(
        color: .orange,
        renderJoints: true
    )
)

let virtualHands = VirtualHands(configuration: config)
// Virtual hands update automatically from hand tracking data
```

#### Pros
- Ready-made solution with minimal code
- Professional gesture tutorial animations included
- Built-in gesture detection
- Active community creating gesture packages

#### Cons
- Third-party dependency
- May not match your app's visual style exactly
- Need to create custom packages for unique gestures (fire wall, mega combine)
- Additional package management overhead

---

## Recommended Implementation Strategy

For Elemental Warrior, I recommend a **hybrid approach** combining Approaches 2 and 3:

### Phase 1: Quick Prototype with Sphere Skeleton
1. Implement joint sphere visualization (Approach 1)
2. Define target poses for each gesture by capturing real hand data
3. Test animation timing and transitions
4. Validate with users that the tutorial concept works

### Phase 2: Production Implementation
1. **Create or acquire a stylized hand model** that matches the fire theme
   - Semi-transparent with ember/flame effects
   - Ghostly blue glow (distinct from fireballs)
   - Rigged with ARKit-compatible skeleton
2. **Pre-animate core gestures in Blender** (Approach 3):
   - Open palm spawn animation
   - Punch throw sequence
   - Stop gesture for flamethrower
   - Two-handed zombie pose for fire wall
3. **Add programmatic control** (Approach 2) for:
   - Positioning tutorials relative to user
   - Looping/pausing animations
   - Syncing with audio instructions
   - Transitioning between gestures

### Phase 3: Polish
1. Add floating text labels with gesture names
2. Implement progress indicators (gesture detection confidence)
3. Add success animations when user replicates gesture
4. Create intro/outro transitions

---

## Implementation Details

### Positioning the Tutorial Hand

Position the tutorial hand in a comfortable viewing location:

```swift
func positionTutorialHand(for gesture: GestureAnimation, rootEntity: Entity) async {
    guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return }

    let deviceTransform = deviceAnchor.originFromAnchorTransform
    let devicePosition = simd_make_float3(deviceTransform.columns.3)
    let deviceForward = -simd_make_float3(deviceTransform.columns.2)

    // Position 0.8m in front and 0.3m below eye level
    let tutorialPosition = devicePosition + deviceForward * 0.8 + SIMD3<Float>(0, -0.3, 0)

    if let handEntity = showGestureTutorial(gesture: gesture, at: tutorialPosition) {
        // Face the user
        let lookAtUser = simd_quatf(from: [0, 0, 1], to: normalize(devicePosition - tutorialPosition))
        handEntity.orientation = lookAtUser

        rootEntity.addChild(handEntity)
    }
}
```

### Recording Gesture Poses from Live Hand Tracking

To create accurate target poses, record from actual hand tracking data:

```swift
class GesturePoseRecorder {
    private var recordedPoses: [[HandSkeleton.JointName: simd_float4x4]] = []
    private var isRecording = false

    func startRecording() {
        recordedPoses = []
        isRecording = true
    }

    func recordFrame(from anchor: HandAnchor) {
        guard isRecording, let skeleton = anchor.handSkeleton else { return }

        var pose: [HandSkeleton.JointName: simd_float4x4] = [:]
        for jointName in HandSkeleton.JointName.allCases {
            let joint = skeleton.joint(jointName)
            // Store local transform (relative to parent joint)
            pose[jointName] = joint.anchorFromJointTransform
        }
        recordedPoses.append(pose)
    }

    func stopRecording() -> [[HandSkeleton.JointName: simd_float4x4]] {
        isRecording = false
        return recordedPoses
    }

    func exportToKeyframes() -> [GestureKeyframe] {
        let frameInterval: TimeInterval = 1.0 / 30.0
        return recordedPoses.enumerated().map { index, pose in
            GestureKeyframe(
                time: TimeInterval(index) * frameInterval,
                jointTransforms: pose.mapValues { matrix in
                    let transform = Transform(matrix: matrix)
                    return (rotation: transform.rotation, translation: transform.translation)
                }
            )
        }
    }
}
```

### Tutorial State Machine

Manage the tutorial flow with a state machine:

```swift
enum TutorialState {
    case idle
    case showingGesture(GestureAnimation)
    case waitingForUser
    case userPerforming
    case success
    case failed
}

class GestureTutorialManager {
    @Published var currentState: TutorialState = .idle
    @Published var currentGesture: GestureAnimation?

    private var tutorialHandEntity: Entity?
    private let gestureDetection = GestureDetection()

    func startTutorial(for gesture: GestureAnimation, in parent: Entity) async {
        currentGesture = gesture
        currentState = .showingGesture(gesture)

        // Show animated hand
        tutorialHandEntity = await showTutorialHand(gesture, parent: parent)

        // Wait for animation to complete once
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

        // Switch to waiting for user
        currentState = .waitingForUser
        showInstructionText("Now you try!")

        // Start gesture detection
        startDetecting(gesture: gesture)
    }

    private func startDetecting(gesture: GestureAnimation) {
        Task {
            while currentState == .waitingForUser || currentState == .userPerforming {
                // Check if user is performing the gesture
                let confidence = await detectGestureConfidence(gesture)

                if confidence > 0.8 {
                    currentState = .success
                    await showSuccessFeedback()
                    break
                } else if confidence > 0.3 {
                    currentState = .userPerforming
                }

                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }
}
```

---

## Asset Requirements

### Hand Model Specifications

For a custom tutorial hand model:

| Property | Specification |
|----------|--------------|
| Polygon Count | 5,000 - 15,000 tris |
| Skeleton | 27 bones matching ARKit HandSkeleton |
| Materials | Semi-transparent, emissive for glow |
| Texture Resolution | 1024x1024 or 2048x2048 |
| File Format | USDZ |
| Animation FPS | 30 |

### Bone Naming Convention

The skeleton bones must match ARKit's `HandSkeleton.JointName`:

```
wrist
├── thumbKnuckle
│   └── thumbIntermediateBase
│       └── thumbIntermediateTip
│           └── thumbTip
├── indexFingerMetacarpal
│   └── indexFingerKnuckle
│       └── indexFingerIntermediateBase
│           └── indexFingerIntermediateTip
│               └── indexFingerTip
├── middleFingerMetacarpal
│   └── middleFingerKnuckle
│       └── middleFingerIntermediateBase
│           └── middleFingerIntermediateTip
│               └── middleFingerTip
├── ringFingerMetacarpal
│   └── ringFingerKnuckle
│       └── ringFingerIntermediateBase
│           └── ringFingerIntermediateTip
│               └── ringFingerTip
└── littleFingerMetacarpal
    └── littleFingerKnuckle
        └── littleFingerIntermediateBase
            └── littleFingerIntermediateTip
                └── littleFingerTip
```

Plus optional `forearmWrist` and `forearmArm` for arm visualization.

---

## Gestures to Tutorial

Based on Elemental Warrior's current feature set:

| Gesture | Description | Animation Duration |
|---------|-------------|-------------------|
| Open Palm Up | Palm facing up, fingers extended | 2s (transition from neutral) |
| Punch | Close fist, forward motion | 1.5s (includes wind-up) |
| Stop Gesture | Palm forward, fingers up | 2s |
| Zombie Pose | Both hands, palms down | 3s (two-hand sequence) |
| Mega Combine | Two hands coming together | 2.5s (shows both hands) |
| Fist Clench | Open to closed fist | 1s |

---

## Resources and References

### Apple Documentation
- [Tracking and Visualizing Hand Movement](https://developer.apple.com/documentation/visionOS/tracking-and-visualizing-hand-movement)
- [HandSkeleton.JointName](https://developer.apple.com/documentation/arkit/handskeleton/jointname)
- [SkeletalPosesComponent](https://developer.apple.com/documentation/realitykit/skeletalposescomponent)
- [FromToByAnimation](https://developer.apple.com/documentation/realitykit/fromtobyanimation)
- [Human Interface Guidelines - visionOS](https://developer.apple.com/design/human-interface-guidelines/)

### WWDC Sessions
- [WWDC23: Meet ARKit for Spatial Computing](https://developer.apple.com/videos/play/wwdc2023/10082/)
- [WWDC23: Build Spatial Experiences with RealityKit](https://developer.apple.com/videos/play/wwdc2023/10080/)
- [WWDC24: Compose Interactive 3D Content in Reality Composer Pro](https://developer.apple.com/videos/play/wwdc2024/10102/)
- [WWDC21: Dive into RealityKit 2](https://developer.apple.com/videos/play/wwdc2021/10074/)

### Sample Code
- [Happy Beam](https://developer.apple.com/documentation/visionos/happybeam) - Apple's gesture detection sample
- [Vision Pro Head Hand Tracking Demo](https://github.com/kongmunist/Vision-Pro-Head-Hand-Tracking-Demo) - Joint visualization starter
- [VisionGesture](https://github.com/AlohaYos/VisionGesture) - Custom gesture implementation
- [HandVector](https://github.com/XanderXu/HandVector) - Gesture similarity detection

### Third-Party Tools
- [GestureKit](https://github.com/nthState/GestureKit) - Gesture detection framework with USDZ tutorials
- [Gesture Composer](https://www.gesturecomposer.com) - Tool for creating gesture packages
- [Reality Converter](https://developer.apple.com/augmented-reality/tools/) - Apple's USDZ conversion tool

### 3D Assets
- [Sketchfab - Rigged Hand Models](https://sketchfab.com/3d-models/hand-rig-a348cf6087eb4fd98a83b026593823ad)
- [BlendSwap - Rigged Hands](https://www.blendswap.com/blend/7894)
- [Apple Quick Look Gallery](https://developer.apple.com/augmented-reality/quick-look/) - Sample USDZ models

### Blender Pipeline
- [Blender to RealityKit](https://github.com/radcli14/blender-to-realitykit) - Export workflow guide
- [Animation Export Tips](https://www.daveyknific.com/journal/blender-to-realitykit.html) - FBX to USDZ pipeline

---

## Implementation Checklist

- [ ] Choose visual style for tutorial hand (realistic, stylized, ghostly)
- [ ] Create or acquire rigged hand model with ARKit-compatible skeleton
- [ ] Implement basic joint sphere prototype to validate positions
- [ ] Record live gesture poses using GesturePoseRecorder
- [ ] Create pre-animated USDZ files for each gesture in Blender
- [ ] Implement TutorialHandVisualization class
- [ ] Add GestureTutorialManager state machine
- [ ] Create UI for starting/skipping tutorials
- [ ] Add audio instructions synchronized with animations
- [ ] Implement success/failure feedback
- [ ] Test on device (simulator doesn't support hand tracking)
- [ ] Add tutorial prompts for first-time users

---

## Conclusion

Implementing floating hand tutorials for VisionOS requires custom development since there's no built-in API. The recommended approach combines:

1. **Pre-animated USDZ hand models** for smooth, professional gesture demonstrations
2. **Programmatic control** for positioning, timing, and user interaction
3. **State machine management** for tutorial flow and progress tracking

The initial prototype can use simple sphere visualization, then upgrade to a stylized hand model that matches Elemental Warrior's fire theme (semi-transparent with ember glow effects).

Estimated development effort:
- Prototype (sphere skeleton): 1-2 days
- Full implementation with custom model: 1-2 weeks
- Polish and testing: 1 week

This feature will significantly improve the onboarding experience and help users discover advanced gestures like mega fireball combining and fire wall placement.
