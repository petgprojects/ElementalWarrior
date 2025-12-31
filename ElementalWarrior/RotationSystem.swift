//
//  RotationSystem.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import RealityKit

struct RotationComponent: Component {
    var speed: Float
}

final class RotationSystem: System {
    static var _registered = false
    
    static func ensureRegistered() {
        guard !_registered else { return }
        RotationComponent.registerComponent()
        RotationSystem.registerSystem()
        _registered = true
    }
    
    required init(scene: Scene) {}
    
    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        context.scene.performQuery( EntityQuery(where: .has(RotationComponent.self)) ).forEach { entity in
            guard let c = entity.components[RotationComponent.self] else { return }
            entity.transform.rotation *= simd_quatf(angle: c.speed * dt, axis: [0, 1, 0])
        }
    }
}
