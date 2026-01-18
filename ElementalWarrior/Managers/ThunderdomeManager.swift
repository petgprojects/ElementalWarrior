//
//  ThunderdomeManager.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI
import RealityKit

@MainActor
@Observable
final class ThunderdomeManager {
    private static let floorReferenceHeight: Float = 1.0 // Y=0 is 1m above the floor.
    private static let fallbackPosition = SIMD3<Float>(0, -0.5, 0)
    private static let collisionShellInset: Float = 0.5
    private static let collisionShellSegments = 48
    private static let collisionShellOutlierRatio: Float = 1.6
    private static let collisionShellNameOverrides = [
        "ThunderdomeEnvironment/ThunderdomeEnvironment/root/dome/Mesh",
        "dome/mesh",
        "dome"
    ]
    private static let collisionShellNameHints = ["dome", "wall"]
    private static var collisionShellLogCandidates = false

    let rootEntity = Entity()
    private(set) var defaultPosition = ThunderdomeManager.fallbackPosition
    var position: SIMD3<Float> = ThunderdomeManager.fallbackPosition {
        didSet {
            rootEntity.position = position
        }
    }
    var isEnvironmentReady = false
    var isEnvironmentLoading = false
    var isAwaitingFloorLook = false

    private var hasLoaded = false
    private var hasAppliedInitialHeight = false
    private var isCalibratingHeight = false
    private var teleportTask: Task<Void, Never>?

    init() {
        rootEntity.name = "ThunderdomeRoot"
        rootEntity.position = position
    }

    func loadEnvironment() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isEnvironmentReady = false
        isEnvironmentLoading = true
        defer { isEnvironmentLoading = false }

        guard let url = thunderdomeResourceURL() else {
            hasLoaded = false
            print("[Thunderdome] Missing thunderdome_final.usdz in bundle.")
            return
        }

        do {
            print("[Thunderdome] Loading entity from URL...")
            let entity = try await Entity(contentsOf: url)
            print("[Thunderdome] Entity loaded, setting up...")
            entity.name = "ThunderdomeEnvironment"
            entity.position = .zero
            print("[Thunderdome] Generating collision shapes...")
            entity.generateCollisionShapes(recursive: true, static: false)
            print("[Thunderdome] Applying collision filter...")
            applyCollisionFilter(to: entity)
            print("[Thunderdome] Adding collision shell...")
            await addCollisionShell(to: entity)
            print("[Thunderdome] Adding sun light...")
            addSunLight(to: entity)
            print("[Thunderdome] Adding entity to root...")
            rootEntity.addChild(entity)
            print("[Thunderdome] Environment ready!")
            isEnvironmentReady = true
        } catch {
            hasLoaded = false
            print("[Thunderdome] Failed to load thunderdome: \(error.localizedDescription)")
        }
    }

    func applyInitialUserHeight(using handTrackingManager: HandTrackingManager) async {
        guard !hasAppliedInitialHeight, !isCalibratingHeight else { return }
        isCalibratingHeight = true
        defer {
            isCalibratingHeight = false
            if Task.isCancelled {
                isAwaitingFloorLook = false
            }
        }

        var didShowPrompt = false
        while !Task.isCancelled {
            if let distance = handTrackingManager.estimateDistanceToFloor() {
                isAwaitingFloorLook = false
                var newPosition = position
                newPosition.y = ThunderdomeManager.floorReferenceHeight - distance
                print(String(format: "[Thunderdome] Detected user height: %.2f m (start Y: %.2f)", distance, newPosition.y))
                position = newPosition
                defaultPosition = newPosition
                hasAppliedInitialHeight = true
                return
            }
            if !didShowPrompt {
                isAwaitingFloorLook = true
                didShowPrompt = true
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    func resetPosition() {
        position = defaultPosition
    }

    func teleport(to targetPosition: SIMD3<Float>, deviceTransform: simd_float4x4?) {
        guard isEnvironmentReady, let deviceTransform else { return }

        let devicePosition = SIMD3<Float>(
            deviceTransform.columns.3.x,
            deviceTransform.columns.3.y,
            deviceTransform.columns.3.z
        )
        let delta = devicePosition - targetPosition

        var newPosition = rootEntity.position
        newPosition.x += delta.x
        newPosition.z += delta.z

        teleportTask?.cancel()
        rootEntity.stopAllAnimations()

        let duration = GestureConstants.teleportSlideDuration
        var transform = rootEntity.transform
        transform.translation = newPosition
        rootEntity.move(to: transform, relativeTo: rootEntity.parent, duration: duration, timingFunction: .easeInOut)

        teleportTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
            guard !Task.isCancelled else { return }
            position = newPosition
        }
    }

    private func thunderdomeResourceURL() -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "thunderdome_final", withExtension: "usdz") {
            return url
        }
        return bundle.url(forResource: "thunderdome_final", withExtension: "usdz", subdirectory: "Resources")
    }

    func snapToFloor(scene: RealityKit.Scene?, deviceTransform: simd_float4x4?) {
        guard isEnvironmentReady, let scene, let deviceTransform else { return }
        let origin = SIMD3<Float>(
            deviceTransform.columns.3.x,
            deviceTransform.columns.3.y,
            deviceTransform.columns.3.z
        )
        let down = SIMD3<Float>(0, -1, 0)
        guard let hit = CollisionSystem.raycastScene(
            scene: scene,
            origin: origin,
            direction: down,
            maxDistance: 10.0,
            mask: CollisionGroups.thunderdome,
            minDistance: 0.05
        ) else {
            return
        }

        var newPosition = position
        newPosition.y -= hit.position.y
        position = newPosition
    }

    private func applyCollisionFilter(to entity: Entity) {
        if var collision = entity.components[CollisionComponent.self] {
            collision.filter = CollisionFilter(group: CollisionGroups.thunderdome, mask: .all)
            entity.components.set(collision)
        }

        for child in entity.children {
            applyCollisionFilter(to: child)
        }
    }

    private func addSunLight(to entity: Entity) {
        let lightEntity = Entity()
        lightEntity.name = "ThunderdomeSunLight"

        // USDZ uses centimeters; RealityKit uses meters.
        let centimetersToMeters: Float = 0.01
        let lightPosition = SIMD3<Float>(
            7400.0 * centimetersToMeters,
            5000.0 * centimetersToMeters,
            -90.0 * centimetersToMeters
        )

        var lightComponent = DirectionalLightComponent()
        lightComponent.color = .white
        lightComponent.intensity = 10000
        lightEntity.components.set(lightComponent)
        lightEntity.look(at: .zero, from: lightPosition, relativeTo: entity)

        entity.addChild(lightEntity)
    }

    private func addCollisionShell(to entity: Entity) async {
        var candidates: [CollisionShellCandidate] = []
        collectBounds(from: entity, parentPath: entity.name, into: &candidates)
        guard !candidates.isEmpty else {
            print("[Thunderdome] Collision shell skipped (no candidates).")
            return
        }

        if await addDomeMeshCollision(from: candidates) {
            return
        }

        guard let chosen = pickCollisionShellCandidate(from: candidates) else {
            print("[Thunderdome] Collision shell skipped (no suitable bounds).")
            return
        }

        let radius = chosen.radius - ThunderdomeManager.collisionShellInset
        let height = chosen.height - ThunderdomeManager.collisionShellInset * 2

        guard radius > 0.2, height > 0.2 else {
            print("[Thunderdome] Collision shell skipped (bounds too small).")
            return
        }

        guard let mesh = createOpenCylinderMesh(
            radius: radius,
            height: height,
            segments: ThunderdomeManager.collisionShellSegments
        ) else {
            print("[Thunderdome] Failed to build collision shell mesh.")
            return
        }

        do {
            let shape = try await ShapeResource.generateStaticMesh(from: mesh)
            let shellEntity = Entity()
            shellEntity.name = "ThunderdomeCollisionShell"
            shellEntity.position = chosen.center

            var collision = CollisionComponent(shapes: [shape])
            collision.filter = CollisionFilter(group: CollisionGroups.thunderdome, mask: .all)
            shellEntity.components.set(collision)

            entity.addChild(shellEntity)
            print(String(format: "[Thunderdome] Collision shell: radius=%.2f height=%.2f center=(%.2f, %.2f, %.2f)",
                         radius, height, chosen.center.x, chosen.center.y, chosen.center.z))
        } catch {
            print("[Thunderdome] Failed to create collision shell: \(error.localizedDescription)")
        }
    }

    private struct CollisionShellCandidate {
        let center: SIMD3<Float>
        let radius: Float
        let height: Float
        let name: String
        let path: String
        let entity: Entity
    }

    private func pickCollisionShellCandidate(from candidates: [CollisionShellCandidate]) -> CollisionShellCandidate? {
        if ThunderdomeManager.collisionShellLogCandidates {
            ThunderdomeManager.collisionShellLogCandidates = false
            print("[Thunderdome] Collision shell candidates: \(candidates.count)")
            for candidate in candidates.sorted(by: { $0.radius > $1.radius }) {
                print(String(
                    format: "[Thunderdome] Candidate: %@ radius=%.2f height=%.2f center=(%.2f, %.2f, %.2f)",
                    candidate.path,
                    candidate.radius,
                    candidate.height,
                    candidate.center.x,
                    candidate.center.y,
                    candidate.center.z
                ))
            }
        }

        if let named = pickNamedCollisionShellCandidate(from: candidates) {
            print("[Thunderdome] Collision shell source: \(named.path) (name match)")
            return named
        }

        let sorted = candidates.sorted { $0.radius > $1.radius }
        let chosen: CollisionShellCandidate
        if sorted.count > 1,
           sorted[0].radius > sorted[1].radius * ThunderdomeManager.collisionShellOutlierRatio {
            chosen = sorted[1]
        } else {
            chosen = sorted[0]
        }

        print("[Thunderdome] Collision shell source: \(chosen.path)")
        return chosen
    }

    private func addDomeMeshCollision(from candidates: [CollisionShellCandidate]) async -> Bool {
        guard let candidate = pickNamedCollisionShellCandidate(from: candidates) else {
            print("[Thunderdome] Dome mesh collision skipped (no named candidate).")
            return false
        }
        guard let model = candidate.entity.components[ModelComponent.self] else {
            print("[Thunderdome] Dome mesh collision skipped (missing model component).")
            return false
        }

        applyDoubleSidedMaterials(to: candidate.entity)

        do {
            var shapes: [ShapeResource] = []
            let baseShape = try await ShapeResource.generateStaticMesh(from: model.mesh)
            shapes.append(baseShape)

            if let flippedMesh = createFlippedMesh(from: model.mesh),
               let flippedShape = try? await ShapeResource.generateStaticMesh(from: flippedMesh) {
                shapes.append(flippedShape)
            }

            var collision = candidate.entity.components[CollisionComponent.self]
                ?? CollisionComponent(shapes: [])
            collision.shapes = shapes
            collision.filter = CollisionFilter(group: CollisionGroups.thunderdome, mask: .all)
            candidate.entity.components.set(collision)

            print("[Thunderdome] Dome mesh collision enabled: \(candidate.path) shapes=\(shapes.count)")
            return true
        } catch {
            print("[Thunderdome] Dome mesh collision failed: \(error.localizedDescription)")
            return false
        }
    }

    private func createFlippedMesh(from mesh: MeshResource) -> MeshResource? {
        let contents = mesh.contents

        var newDescriptors: [MeshDescriptor] = []

        for model in contents.models {
            for part in model.parts {
                let positions = part.positions
                guard let triangleIndices = part.triangleIndices else { continue }

                // Convert MeshBuffer to Array
                let positionsArray = Array(positions.elements)
                let indicesArray = Array(triangleIndices.elements)

                // Reverse triangle winding: swap indices 1 and 2 of each triangle
                var flippedIndices: [UInt32] = []
                flippedIndices.reserveCapacity(indicesArray.count)

                for i in stride(from: 0, to: indicesArray.count, by: 3) {
                    guard i + 2 < indicesArray.count else { break }
                    flippedIndices.append(indicesArray[i])      // Keep first vertex
                    flippedIndices.append(indicesArray[i + 2])  // Swap second and third
                    flippedIndices.append(indicesArray[i + 1])
                }

                var descriptor = MeshDescriptor(name: "FlippedDomeCollision")
                descriptor.positions = MeshBuffer(positionsArray)
                descriptor.primitives = .triangles(flippedIndices)

                newDescriptors.append(descriptor)
            }
        }

        guard !newDescriptors.isEmpty else { return nil }

        do {
            return try MeshResource.generate(from: newDescriptors)
        } catch {
            print("[Thunderdome] Failed to generate flipped mesh: \(error.localizedDescription)")
            return nil
        }
    }

    private func applyDoubleSidedMaterials(to entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            var materials = model.materials
            for index in materials.indices {
                switch materials[index] {
                case var material as PhysicallyBasedMaterial:
                    material.faceCulling = .none
                    materials[index] = material
                case var material as SimpleMaterial:
                    material.faceCulling = .none
                    materials[index] = material
                case var material as UnlitMaterial:
                    material.faceCulling = .none
                    materials[index] = material
                default:
                    break
                }
            }
            model.materials = materials
            entity.components.set(model)
        }

        for child in entity.children {
            applyDoubleSidedMaterials(to: child)
        }
    }

    private func pickNamedCollisionShellCandidate(from candidates: [CollisionShellCandidate]) -> CollisionShellCandidate? {
        let overrides = ThunderdomeManager.collisionShellNameOverrides
            .map { $0.lowercased() }
        if !overrides.isEmpty {
            let exactMatches = candidates.filter { candidate in
                let name = candidate.name.lowercased()
                let path = candidate.path.lowercased()
                return overrides.contains(name) || overrides.contains(path)
            }
            if let best = exactMatches.max(by: { $0.radius < $1.radius }) {
                return best
            }
        }

        let hints = ThunderdomeManager.collisionShellNameHints
            .map { $0.lowercased() }
        let hintMatches = candidates.filter { candidate in
            let path = candidate.path.lowercased()
            return hints.contains { path.contains($0) }
        }
        return hintMatches.max(by: { $0.radius < $1.radius })
    }

    private func collectBounds(from entity: Entity, parentPath: String, into results: inout [CollisionShellCandidate]) {
        let name = entity.name.isEmpty ? "UnnamedModel" : entity.name
        let path = parentPath.isEmpty ? name : "\(parentPath)/\(name)"
        if entity.components[ModelComponent.self] != nil {
            let bounds = entity.visualBounds(relativeTo: entity)
            let size = bounds.max - bounds.min
            let radius = max(size.x, size.z) * 0.5
            let height = size.y

            if radius > 0.1, height > 0.1 {
                let center = (bounds.min + bounds.max) * 0.5
                results.append(CollisionShellCandidate(
                    center: center,
                    radius: radius,
                    height: height,
                    name: name,
                    path: path,
                    entity: entity
                ))
            }
        }

        for child in entity.children {
            collectBounds(from: child, parentPath: path, into: &results)
        }
    }


    private func createOpenCylinderMesh(
        radius: Float,
        height: Float,
        segments: Int
    ) -> MeshResource? {
        guard segments >= 3 else { return nil }

        // Create a dome shape: hemisphere on top + cylinder walls
        // All triangles are double-sided for inside-out raycasts

        let hemisphereRings = 12  // Latitude rings for the dome cap
        let cylinderHeight = height * 0.3  // Lower portion is cylindrical
        let domeHeight = height - cylinderHeight

        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        // --- Cylinder portion (bottom) ---
        let cylinderBottom: Float = 0
        let cylinderTop = cylinderHeight

        for i in 0..<segments {
            let angle = (Float(i) / Float(segments)) * 2.0 * .pi
            let x = cos(angle) * radius
            let z = sin(angle) * radius
            positions.append(SIMD3<Float>(x, cylinderBottom, z))
            positions.append(SIMD3<Float>(x, cylinderTop, z))
        }

        // Cylinder triangles (double-sided)
        for i in 0..<segments {
            let next = (i + 1) % segments
            let bottom0 = UInt32(i * 2)
            let top0 = bottom0 + 1
            let bottom1 = UInt32(next * 2)
            let top1 = bottom1 + 1

            // Front faces
            indices.append(bottom0)
            indices.append(top0)
            indices.append(bottom1)

            indices.append(top0)
            indices.append(top1)
            indices.append(bottom1)

            // Back faces (reversed winding)
            indices.append(bottom0)
            indices.append(bottom1)
            indices.append(top0)

            indices.append(top0)
            indices.append(bottom1)
            indices.append(top1)
        }

        // --- Hemisphere dome portion (top) ---
        let domeStartIndex = UInt32(positions.count)

        // Generate hemisphere vertices (rings from bottom to top)
        for ring in 0...hemisphereRings {
            let phi = (Float(ring) / Float(hemisphereRings)) * (.pi / 2)  // 0 to π/2
            let y = cylinderTop + sin(phi) * domeHeight
            let ringRadius = cos(phi) * radius

            for seg in 0..<segments {
                let theta = (Float(seg) / Float(segments)) * 2.0 * .pi
                let x = cos(theta) * ringRadius
                let z = sin(theta) * ringRadius
                positions.append(SIMD3<Float>(x, y, z))
            }
        }

        // Generate hemisphere triangles (double-sided)
        for ring in 0..<hemisphereRings {
            for seg in 0..<segments {
                let nextSeg = (seg + 1) % segments

                let current = domeStartIndex + UInt32(ring * segments + seg)
                let nextInRing = domeStartIndex + UInt32(ring * segments + nextSeg)
                let above = domeStartIndex + UInt32((ring + 1) * segments + seg)
                let aboveNext = domeStartIndex + UInt32((ring + 1) * segments + nextSeg)

                // Front faces
                indices.append(current)
                indices.append(above)
                indices.append(nextInRing)

                indices.append(nextInRing)
                indices.append(above)
                indices.append(aboveNext)

                // Back faces (reversed winding)
                indices.append(current)
                indices.append(nextInRing)
                indices.append(above)

                indices.append(nextInRing)
                indices.append(aboveNext)
                indices.append(above)
            }
        }

        // Connect cylinder top to dome bottom
        let cylinderTopRingStart = UInt32(0)
        let domeBottomRingStart = domeStartIndex

        for seg in 0..<segments {
            let nextSeg = (seg + 1) % segments

            let cylTop = cylinderTopRingStart + UInt32(seg * 2 + 1)
            let cylTopNext = cylinderTopRingStart + UInt32(nextSeg * 2 + 1)
            let domeBot = domeBottomRingStart + UInt32(seg)
            let domeBotNext = domeBottomRingStart + UInt32(nextSeg)

            // Front faces
            indices.append(cylTop)
            indices.append(domeBot)
            indices.append(cylTopNext)

            indices.append(cylTopNext)
            indices.append(domeBot)
            indices.append(domeBotNext)

            // Back faces
            indices.append(cylTop)
            indices.append(cylTopNext)
            indices.append(domeBot)

            indices.append(cylTopNext)
            indices.append(domeBotNext)
            indices.append(domeBot)
        }

        var descriptor = MeshDescriptor(name: "ThunderdomeCollisionShell")
        descriptor.positions = MeshBuffer(positions)
        descriptor.primitives = .triangles(indices)

        do {
            return try MeshResource.generate(from: [descriptor])
        } catch {
            print("[Thunderdome] Failed to generate collision shell mesh: \(error.localizedDescription)")
            return nil
        }
    }
}
