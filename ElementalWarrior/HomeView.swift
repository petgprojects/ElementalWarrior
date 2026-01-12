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

    private var isArenaOpen: Bool {
        appModel.immersiveSpaceState == .open && appModel.activeImmersiveSpace == .arena
    }

    private var isThunderdomeOpen: Bool {
        appModel.immersiveSpaceState == .open && appModel.activeImmersiveSpace == .thunderdome
    }

    var body: some View {
        VStackLayout().depthAlignment(.front) {
            VStack(spacing: 16) {
                Text("Welcome to Elemental Warrior")
                    .font(.largeTitle)
                    .bold()

                Text("Master the elements. Enter the arena.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button(isArenaOpen ? "Quit Arena" : "Start") {
                    Task {
                        await toggleImmersiveSpace(.arena)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appModel.immersiveSpaceState == .inTransition)

                Button(isThunderdomeOpen ? "Exit Thunderdome" : "Enter Thunderdome") {
                    Task {
                        await toggleImmersiveSpace(.thunderdome)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(appModel.immersiveSpaceState == .inTransition)

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
    private func toggleImmersiveSpace(_ kind: AppModel.ImmersiveSpaceKind) async {
        switch appModel.immersiveSpaceState {
        case .open:
            if appModel.activeImmersiveSpace == kind {
                await closeImmersiveSpace()
            } else {
                await closeImmersiveSpace()
                await openTargetImmersiveSpace(kind)
            }
        case .closed:
            await openTargetImmersiveSpace(kind)
        case .inTransition:
            break
        }
    }

    private func openTargetImmersiveSpace(_ kind: AppModel.ImmersiveSpaceKind) async {
        appModel.immersiveSpaceState = .inTransition
        if kind == .thunderdome {
            appModel.thunderdomeImmersionStyle = .mixed
        }
        let result = await openImmersiveSpace(id: kind.rawValue)
        if result == .opened {
            appModel.immersiveSpaceState = .open
            appModel.activeImmersiveSpace = kind
            if kind == .thunderdome {
                openWindow(id: "thunderdomePosition")
            }
        } else {
            appModel.immersiveSpaceState = .closed
            appModel.activeImmersiveSpace = nil
        }
    }

    private func closeImmersiveSpace() async {
        appModel.immersiveSpaceState = .inTransition
        await dismissImmersiveSpace()
        appModel.immersiveSpaceState = .closed
        appModel.activeImmersiveSpace = nil
    }
}
