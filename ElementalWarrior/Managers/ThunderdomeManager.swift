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
    static let defaultPosition = SIMD3<Float>(0, 2, 0)

    let rootEntity = Entity()
    var position: SIMD3<Float> = ThunderdomeManager.defaultPosition {
        didSet {
            rootEntity.position = position
        }
    }
    var isEnvironmentReady = false

    private var hasLoaded = false

    init() {
        rootEntity.name = "ThunderdomeRoot"
        rootEntity.position = position
    }

    func loadEnvironment() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isEnvironmentReady = false

        guard let url = thunderdomeResourceURL() else {
            hasLoaded = false
            print("[Thunderdome] Missing thunderdome_final.usdz in bundle.")
            return
        }

        do {
            let entity = try await Entity(contentsOf: url)
            entity.name = "ThunderdomeEnvironment"
            entity.position = .zero
            entity.generateCollisionShapes(recursive: true, static: true)
            applyCollisionFilter(to: entity)
            rootEntity.addChild(entity)
            isEnvironmentReady = true
        } catch {
            hasLoaded = false
            print("[Thunderdome] Failed to load thunderdome: \(error.localizedDescription)")
        }
    }

    func resetPosition() {
        position = ThunderdomeManager.defaultPosition
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
}
