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
