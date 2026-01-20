//
//  AppModel.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    enum ImmersiveSpaceKind: String {
        case arena = "arena"
        case thunderdome = "thunderdome"
    }

    var immersiveSpaceState = ImmersiveSpaceState.closed
    var activeImmersiveSpace: ImmersiveSpaceKind?
    var thunderdomeImmersionStyle: ImmersionStyle = .mixed
    
    // Shared hand tracking manager for debug visibility
    let handTrackingManager = HandTrackingManager()
    let thunderdomeManager = ThunderdomeManager()
    let enemyManager = EnemyManager()

    let gestureSettings = GestureSettings()
    let tutorialPlaybackManager = TutorialPlaybackManager()
    var isTutorialPreviewOpen = false

    init() {
        handTrackingManager.teleportHandler = { [weak self] targetPosition, deviceTransform in
            self?.thunderdomeManager.teleport(to: targetPosition, deviceTransform: deviceTransform)
        }
    }
}
