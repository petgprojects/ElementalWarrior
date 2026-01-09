//
//  ElementalWarriorApp.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI

@main
struct ElementalWarriorApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup(id: "home") {
            HomeView()
                .environment(appModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 640, height: 520)

        WindowGroup(id: "debug") {
            DebugWindowView()
                .environment(appModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 900, height: 900)
        .defaultWindowPlacement { _, context in
            if let homeWindow = context.windows.first(where: { $0.id == "home" }) {
                return WindowPlacement(.trailing(homeWindow))
            }
            return WindowPlacement(.utilityPanel)
        }

        WindowGroup(id: "tutorialPreview") {
            TutorialPreviewWindowView()
                .environment(appModel)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.5, height: 1.5, depth: 1.5, in: .meters)

        ImmersiveSpace(id: "arena") {
            ArenaImmersiveView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
