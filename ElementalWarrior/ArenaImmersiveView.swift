//
//  ArenaImmersiveView.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI
import RealityKit

struct ArenaImmersiveView: View {
    var body: some View {
        RealityView { content in
            let floor = ModelEntity(mesh: .generatePlane(width: 4, depth: 4),
                                    materials: [SimpleMaterial(color: .gray, isMetallic: false)])
            floor.position = [0, -1.2, 0]
            content.add(floor)
        }
    }
}
