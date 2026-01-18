//
//  HomeView.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI

struct HomeView: View {

    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStackLayout().depthAlignment(.front) {
            VStack(spacing: 16) {
                Text("Welcome to Elemental Warrior")
                    .font(.largeTitle)
                    .bold()

                Text("Master the elements. Enter the arena.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if appModel.immersiveSpaceState == .open {
                    Button("Quit Immersion") {
                        Task {
                            await toggleImmersiveSpace()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(appModel.immersiveSpaceState == .inTransition)
                } else {
                    Button("Start") {
                        Task {
                            await toggleImmersiveSpace()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appModel.immersiveSpaceState == .inTransition)
                }

                Button("Debug") {
                    openWindow(id: "debug")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .glassBackgroundEffect()
    }

    @MainActor
    private func toggleImmersiveSpace() async {
        switch appModel.immersiveSpaceState {
        case .open:
            appModel.immersiveSpaceState = .inTransition
            await dismissImmersiveSpace()
            appModel.immersiveSpaceState = .closed
        case .closed:
            appModel.immersiveSpaceState = .inTransition
            let result = await openImmersiveSpace(id: "arena")
            if result == .opened {
                appModel.immersiveSpaceState = .open
            } else {
                appModel.immersiveSpaceState = .closed
            }
        case .inTransition:
            break
        }
    }
}
