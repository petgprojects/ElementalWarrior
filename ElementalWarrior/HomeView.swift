//
//  HomeView.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI
import RealityKit

struct HomeView: View {

    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStackLayout().depthAlignment(.front) {
            RealityView { content in
                let fireball = await createFireball()
                content.add(fireball)
            }
            .frame(height: 400)
            .frame(depth: 0.001, alignment: .front)
            .padding(.top, 24)
            .allowsHitTesting(false)

            Color.clear.frame(height: 12)

            VStack(spacing: 16) {
                Text("Welcome to Elemental Warrior")
                    .font(.largeTitle)
                    .bold()

                Text("Master the elements. Enter the arena.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Start") {
                        Task {
                            _ = await openImmersiveSpace(id: "arena")
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Quit Immersion") {
                        Task {
                            await dismissImmersiveSpace()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(32)
        }
    }

    private func createFireball() async -> Entity {
        let fireball = await MainActor.run {
            let entity = createRealisticFireball(scale: 1.5)
            return entity
        }
        return fireball
    }
}

