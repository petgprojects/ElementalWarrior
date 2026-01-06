//
//  TutorialPreviewWindowView.swift
//  ElementalWarrior
//

import SwiftUI
import RealityKit

struct TutorialPreviewWindowView: View {
    @Environment(AppModel.self) private var appModel

    private var isPlaying: Bool {
        appModel.tutorialPlaybackManager.isPlaying
    }

    var body: some View {
        RealityView { content in
            content.add(appModel.tutorialPlaybackManager.rootEntity)
        } update: { content in
            // RealityView update is called when @Observable properties change
            // This ensures the view updates when tutorial playback state changes
        }
        .overlay(alignment: .center) {
            if !isPlaying {
                Text("Press Play in the Tutorials debug panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
    }
}
