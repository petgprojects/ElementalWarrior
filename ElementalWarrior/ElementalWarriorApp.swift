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
        }
        .windowStyle(.plain)
        .defaultSize(width: 1000, height: 1000)

        ImmersiveSpace(id: "arena") {
            ArenaImmersiveView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
