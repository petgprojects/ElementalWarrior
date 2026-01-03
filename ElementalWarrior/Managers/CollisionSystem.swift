//
//  CollisionSystem.swift
//  ElementalWarrior
//
//  Raycast collision detection against persistent mesh geometry.
//  Uses Möller–Trumbore algorithm for ray-triangle intersection.
//

import ARKit
import simd

// MARK: - Collision System

/// Handles raycast-based collision detection against cached mesh geometry
enum CollisionSystem {

    /// Hit result containing position and surface normal
    struct HitResult {
        let position: SIMD3<Float>
        let normal: SIMD3<Float>
    }

    // MARK: - Projectile Collision

    /// Check collision using ray-triangle intersection against persistent mesh cache.
    /// This allows collision with surfaces even when they're no longer in LiDAR range.
    static func checkProjectileCollision(
        projectilePosition: SIMD3<Float>,
        direction: SIMD3<Float>,
        previousPosition: SIMD3<Float>,
        meshCache: [UUID: CachedMeshGeometry]
    ) -> HitResult? {
        // Calculate ray from previous position to current position
        let rayOrigin = previousPosition
        let rayDirection = projectilePosition - previousPosition
        let rayLength = simd_length(rayDirection)

        // Skip if no movement
        guard rayLength > 0.001 else { return nil }

        let normalizedDirection = rayDirection / rayLength
        var closestHit: HitResult? = nil
        var closestDistance: Float = rayLength

        // Check against persistent mesh cache
        for (_, cachedMesh) in meshCache {
            if let hit = raycastAgainstCachedMesh(
                rayOrigin: rayOrigin,
                rayDirection: normalizedDirection,
                maxDistance: closestDistance,
                cached: cachedMesh
            ) {
                let hitDistance = simd_distance(rayOrigin, hit.position)
                if hitDistance < closestDistance {
                    closestDistance = hitDistance
                    closestHit = hit
                }
            }
        }

        return closestHit
    }

    // MARK: - Mesh Raycasting

    /// Perform raycast against cached mesh geometry (works even when ARKit anchor is gone)
    static func raycastAgainstCachedMesh(
        rayOrigin: SIMD3<Float>,
        rayDirection: SIMD3<Float>,
        maxDistance: Float,
        cached: CachedMeshGeometry
    ) -> HitResult? {
        let transform = cached.transform

        var closestHit: HitResult? = nil
        var closestT: Float = maxDistance

        // Iterate through all triangles in the cached mesh
        for (i0, i1, i2) in cached.triangleIndices {
            // Get vertex positions (in local space)
            guard Int(i0) < cached.vertices.count,
                  Int(i1) < cached.vertices.count,
                  Int(i2) < cached.vertices.count else { continue }

            let v0Local = cached.vertices[Int(i0)]
            let v1Local = cached.vertices[Int(i1)]
            let v2Local = cached.vertices[Int(i2)]

            // Transform to world space
            let v0 = transformPoint(v0Local, by: transform)
            let v1 = transformPoint(v1Local, by: transform)
            let v2 = transformPoint(v2Local, by: transform)

            // Ray-triangle intersection (Möller–Trumbore algorithm)
            if let t = rayTriangleIntersection(
                rayOrigin: rayOrigin,
                rayDirection: rayDirection,
                v0: v0, v1: v1, v2: v2
            ) {
                if t > 0.001 && t < closestT {
                    closestT = t
                    let hitPos = rayOrigin + rayDirection * t

                    // Calculate normal and flip to face the incoming ray
                    let edge1 = v1 - v0
                    let edge2 = v2 - v0
                    var normal = normalize(simd_cross(edge1, edge2))
                    if simd_dot(normal, rayDirection) > 0 {
                        normal = -normal
                    }

                    closestHit = HitResult(position: hitPos, normal: normal)
                }
            }
        }

        return closestHit
    }

    /// Perform raycast against a live mesh anchor's geometry
    static func raycastAgainstMesh(
        rayOrigin: SIMD3<Float>,
        rayDirection: SIMD3<Float>,
        maxDistance: Float,
        meshAnchor: MeshAnchor
    ) -> SIMD3<Float>? {
        let geometry = meshAnchor.geometry
        let transform = meshAnchor.originFromAnchorTransform

        let vertexBuffer = geometry.vertices
        let faceBuffer = geometry.faces
        let faceCount = faceBuffer.count
        let indicesPerFace = faceBuffer.primitive.indexCount

        // Only support triangles (3 vertices per face)
        guard indicesPerFace == 3 else { return nil }

        var closestHit: SIMD3<Float>? = nil
        var closestT: Float = maxDistance

        let vertexPointer = vertexBuffer.buffer.contents()
        let vertexStride = vertexBuffer.stride

        let indexPointer = faceBuffer.buffer.contents()
        let bytesPerIndex = faceBuffer.bytesPerIndex

        // Iterate through all triangles
        for faceIndex in 0..<faceCount {
            let i0: UInt32
            let i1: UInt32
            let i2: UInt32

            if bytesPerIndex == 2 {
                let indexPtr = indexPointer.advanced(by: faceIndex * 3 * bytesPerIndex)
                    .bindMemory(to: UInt16.self, capacity: 3)
                i0 = UInt32(indexPtr[0])
                i1 = UInt32(indexPtr[1])
                i2 = UInt32(indexPtr[2])
            } else {
                let indexPtr = indexPointer.advanced(by: faceIndex * 3 * bytesPerIndex)
                    .bindMemory(to: UInt32.self, capacity: 3)
                i0 = indexPtr[0]
                i1 = indexPtr[1]
                i2 = indexPtr[2]
            }

            let v0Local = getVertex(at: Int(i0), pointer: vertexPointer, stride: vertexStride)
            let v1Local = getVertex(at: Int(i1), pointer: vertexPointer, stride: vertexStride)
            let v2Local = getVertex(at: Int(i2), pointer: vertexPointer, stride: vertexStride)

            let v0 = transformPoint(v0Local, by: transform)
            let v1 = transformPoint(v1Local, by: transform)
            let v2 = transformPoint(v2Local, by: transform)

            if let t = rayTriangleIntersection(
                rayOrigin: rayOrigin,
                rayDirection: rayDirection,
                v0: v0, v1: v1, v2: v2
            ) {
                if t > 0.001 && t < closestT {
                    closestT = t
                    closestHit = rayOrigin + rayDirection * t
                }
            }
        }

        return closestHit
    }

    // MARK: - Ray-Triangle Intersection

    /// Möller–Trumbore ray-triangle intersection algorithm.
    /// Returns the parametric t value if intersection occurs, nil otherwise.
    static func rayTriangleIntersection(
        rayOrigin: SIMD3<Float>,
        rayDirection: SIMD3<Float>,
        v0: SIMD3<Float>,
        v1: SIMD3<Float>,
        v2: SIMD3<Float>
    ) -> Float? {
        let epsilon: Float = 0.0000001

        let edge1 = v1 - v0
        let edge2 = v2 - v0

        let h = simd_cross(rayDirection, edge2)
        let a = simd_dot(edge1, h)

        // Ray is parallel to triangle
        if a > -epsilon && a < epsilon {
            return nil
        }

        let f = 1.0 / a
        let s = rayOrigin - v0
        let u = f * simd_dot(s, h)

        if u < 0.0 || u > 1.0 {
            return nil
        }

        let q = simd_cross(s, edge1)
        let v = f * simd_dot(rayDirection, q)

        if v < 0.0 || u + v > 1.0 {
            return nil
        }

        // Compute t to find intersection point
        let t = f * simd_dot(edge2, q)

        if t > epsilon {
            return t
        }

        return nil
    }

    // MARK: - Helper Functions

    /// Extract vertex position from buffer
    static func getVertex(at index: Int, pointer: UnsafeMutableRawPointer, stride: Int) -> SIMD3<Float> {
        let vertexPtr = pointer.advanced(by: index * stride)
            .bindMemory(to: SIMD3<Float>.self, capacity: 1)
        return vertexPtr.pointee
    }

    /// Transform a point by a 4x4 matrix
    static func transformPoint(_ point: SIMD3<Float>, by matrix: simd_float4x4) -> SIMD3<Float> {
        let p4 = SIMD4<Float>(point.x, point.y, point.z, 1.0)
        let transformed = matrix * p4
        return SIMD3<Float>(transformed.x, transformed.y, transformed.z)
    }
}

// MARK: - CachedMeshGeometry Initializer

extension CachedMeshGeometry {
    /// Create cached geometry from a MeshAnchor
    init(from anchor: MeshAnchor) {
        self.id = anchor.id
        self.transform = anchor.originFromAnchorTransform
        self.lastUpdated = Date()

        let geometry = anchor.geometry
        let vertexBuffer = geometry.vertices
        let faceBuffer = geometry.faces

        // Extract vertices
        var extractedVertices: [SIMD3<Float>] = []
        let vertexPointer = vertexBuffer.buffer.contents()
        let vertexStride = vertexBuffer.stride

        for i in 0..<vertexBuffer.count {
            let vertexPtr = vertexPointer.advanced(by: i * vertexStride)
                .bindMemory(to: SIMD3<Float>.self, capacity: 1)
            extractedVertices.append(vertexPtr.pointee)
        }
        self.vertices = extractedVertices

        // Extract triangle indices
        var extractedTriangles: [(UInt32, UInt32, UInt32)] = []
        let indexPointer = faceBuffer.buffer.contents()
        let bytesPerIndex = faceBuffer.bytesPerIndex
        let faceCount = faceBuffer.count

        for faceIndex in 0..<faceCount {
            let i0: UInt32
            let i1: UInt32
            let i2: UInt32

            if bytesPerIndex == 2 {
                let indexPtr = indexPointer.advanced(by: faceIndex * 3 * bytesPerIndex)
                    .bindMemory(to: UInt16.self, capacity: 3)
                i0 = UInt32(indexPtr[0])
                i1 = UInt32(indexPtr[1])
                i2 = UInt32(indexPtr[2])
            } else {
                let indexPtr = indexPointer.advanced(by: faceIndex * 3 * bytesPerIndex)
                    .bindMemory(to: UInt32.self, capacity: 3)
                i0 = indexPtr[0]
                i1 = indexPtr[1]
                i2 = indexPtr[2]
            }
            extractedTriangles.append((i0, i1, i2))
        }
        self.triangleIndices = extractedTriangles
    }
}
