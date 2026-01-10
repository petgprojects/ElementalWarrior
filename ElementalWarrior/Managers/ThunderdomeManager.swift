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
    let rootEntity = Entity()
    var position: SIMD3<Float> = .zero {
        didSet {
            rootEntity.position = position
        }
    }

    private var hasLoaded = false

    init() {
        rootEntity.name = "ThunderdomeRoot"
        rootEntity.position = position
    }

    func loadEnvironment() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard let url = thunderdomeResourceURL() else {
            hasLoaded = false
            print("[Thunderdome] Missing thunderdome_final.usdz in bundle.")
            return
        }

        do {
            let entity = try await Entity(contentsOf: url)
            entity.name = "ThunderdomeEnvironment"
            entity.position = .zero
            rootEntity.addChild(entity)
        } catch {
            hasLoaded = false
            print("[Thunderdome] Failed to load thunderdome: \(error.localizedDescription)")
        }
    }

    func resetPosition() {
        position = .zero
    }

    private func thunderdomeResourceURL() -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "thunderdome_final", withExtension: "usdz") {
            return url
        }
        return bundle.url(forResource: "thunderdome_final", withExtension: "usdz", subdirectory: "Resources")
    }
}
