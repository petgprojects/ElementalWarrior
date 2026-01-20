//
//  EnemyManager.swift
//  ElementalWarrior
//
//  Basic thunderdome enemy animation + AI loop.
//

import SwiftUI
import RealityKit

@MainActor
@Observable
final class EnemyManager {
    enum State {
        case idle
        case walking
        case punching
    }

    private enum EnemyAnimation: String, CaseIterable {
        case idle = "idle"
        case idleToWalk = "idle_to_walk"
        case walk = "walk"
        case punch = "idle_fight_punch_idle"

        var isLooping: Bool {
            switch self {
            case .idle, .walk:
                return true
            case .idleToWalk, .punch:
                return false
            }
        }
    }

    let rootEntity = Entity()

    var state: State = .idle

    private let enemyContainer = Entity()
    private var prototypes: [EnemyAnimation: Entity] = [:]
    private var currentEntity: Entity?
    private var aiTask: Task<Void, Never>?
    private var isLoading = false
    private var isLoaded = false
    private var homePosition = SIMD3<Float>(0, 0, -2.0)
    private var position = SIMD3<Float>(0, 0, -2.0) {
        didSet {
            rootEntity.position = position
        }
    }

    private let roamRadius: Float = 1.6
    private let moveSpeed: Float = 0.45
    private let idleRange: ClosedRange<TimeInterval> = 1.4...3.2
    private let pauseRange: ClosedRange<TimeInterval> = 0.4...1.0

    init() {
        rootEntity.name = "EnemyRoot"
        enemyContainer.name = "EnemyContainer"
        rootEntity.addChild(enemyContainer)
        rootEntity.position = position
    }

    func attach(to parent: Entity) {
        guard rootEntity.parent == nil else { return }
        parent.addChild(rootEntity)
        rootEntity.position = position
    }

    func start() {
        guard aiTask == nil else { return }
        aiTask = Task { [weak self] in
            await self?.runAI()
        }
    }

    func stop() {
        aiTask?.cancel()
        aiTask = nil
        rootEntity.stopAllAnimations()
        currentEntity?.removeFromParent()
        currentEntity = nil
    }

    private func runAI() async {
        await ensureLoaded()
        guard isLoaded else { return }
        setAnimation(.idle)

        while !Task.isCancelled {
            let roll = Float.random(in: 0..<1)
            if roll < 0.65 {
                await idle(for: randomDuration(in: idleRange))
            } else if roll < 0.85 {
                await walkToRandomPoint()
            } else {
                await punch()
            }
        }
    }

    private func idle(for duration: TimeInterval) async {
        setAnimation(.idle)
        try? await Task.sleep(for: .seconds(duration))
    }

    private func walkToRandomPoint() async {
        state = .walking

        let target = randomTargetAroundHome()
        let distance = simd_distance(position, target)
        guard distance > 0.08 else {
            await idle(for: randomDuration(in: pauseRange))
            return
        }

        setAnimation(.idleToWalk)
        setAnimation(.walk)
        face(toward: target)

        let travelDuration = max(TimeInterval(distance / moveSpeed), 0.2)
        var transform = rootEntity.transform
        transform.translation = target
        rootEntity.move(to: transform, relativeTo: rootEntity.parent, duration: travelDuration, timingFunction: .linear)

        try? await Task.sleep(for: .seconds(travelDuration))
        position = target

        await idle(for: randomDuration(in: pauseRange))
    }

    private func punch() async {
        state = .punching
        if let controller = setAnimation(.punch) {
            let duration = max(controller.duration, 0.1)
            try? await Task.sleep(for: .seconds(duration))
        } else {
            try? await Task.sleep(for: .seconds(0.8))
        }
        await idle(for: randomDuration(in: pauseRange))
    }

    @discardableResult
    private func setAnimation(_ animation: EnemyAnimation) -> AnimationPlaybackController? {
        guard let prototype = prototypes[animation] else {
            return nil
        }

        currentEntity?.removeFromParent()

        let entity = prototype.clone(recursive: true)
        entity.name = "Enemy_\(animation.rawValue)"
        entity.position = .zero
        enemyContainer.addChild(entity)
        currentEntity = entity

        let animations = collectAnimations(from: entity)
        guard let animationResource = animations.first else {
            return nil
        }

        let resource = animation.isLooping ? animationResource.repeat() : animationResource
        let controller = entity.playAnimation(resource, transitionDuration: 0.15, startsPaused: false)
        state = {
            switch animation {
            case .idle:
                return .idle
            case .walk, .idleToWalk:
                return .walking
            case .punch:
                return .punching
            }
        }()

        return controller
    }

    private func ensureLoaded() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        for animation in EnemyAnimation.allCases {
            guard let url = enemyAnimationURL(for: animation) else {
                print("[EnemyManager] Missing enemy asset: \(animation.rawValue).usdz")
                continue
            }

            do {
                let entity = try await Entity(contentsOf: url)
                entity.name = "EnemyPrototype_\(animation.rawValue)"
                prototypes[animation] = entity
            } catch {
                print("[EnemyManager] Failed to load \(animation.rawValue): \(error.localizedDescription)")
            }
        }

        isLoaded = !prototypes.isEmpty
    }

    private func enemyAnimationURL(for animation: EnemyAnimation, bundle: Bundle = .main) -> URL? {
        let subdirectories = [
            "enemy",
            "Resources/enemy"
        ]

        for subdirectory in subdirectories {
            if let url = bundle.url(
                forResource: animation.rawValue,
                withExtension: "usdz",
                subdirectory: subdirectory
            ) {
                return url
            }
        }

        return bundle.url(forResource: animation.rawValue, withExtension: "usdz")
    }

    private func collectAnimations(from entity: Entity) -> [AnimationResource] {
        var animations: [AnimationResource] = []

        func addAnimations(_ newAnimations: [AnimationResource]) {
            for animation in newAnimations {
                let identifier = ObjectIdentifier(animation)
                if !animations.contains(where: { ObjectIdentifier($0) == identifier }) {
                    animations.append(animation)
                }
            }
        }

        addAnimations(entity.availableAnimations)
        for child in entity.children {
            addAnimations(collectAnimations(from: child))
        }

        return animations
    }

    private func face(toward target: SIMD3<Float>) {
        let direction = target - position
        guard simd_length(direction) > 0.001 else { return }
        let yaw = atan2(direction.x, direction.z)
        rootEntity.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
    }

    private func randomTargetAroundHome() -> SIMD3<Float> {
        let angle = Float.random(in: 0..<Float.pi * 2)
        let radius = Float.random(in: 0.4..<roamRadius)
        let offset = SIMD3<Float>(cos(angle) * radius, 0, sin(angle) * radius)
        return homePosition + offset
    }

    private func randomDuration(in range: ClosedRange<TimeInterval>) -> TimeInterval {
        let delta = range.upperBound - range.lowerBound
        return range.lowerBound + (TimeInterval.random(in: 0...1) * delta)
    }
}
