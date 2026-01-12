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
            let entity = try await Entity(contentsOf: url)
            entity.name = "ThunderdomeEnvironment"
            entity.position = .zero
            entity.generateCollisionShapes(recursive: true, static: true)
            applyCollisionFilter(to: entity)
            addSunLight(to: entity)
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
}
