//
//  TutorialPreviewWindowView.swift
//  ElementalWarrior
//

import SwiftUI
import RealityKit

struct TutorialPreviewWindowView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ZStack {
            RealityView { content in
                content.add(appModel.tutorialPlaybackManager.rootEntity)
            }

            if !appModel.tutorialPlaybackManager.isPlaying {
                Text("Press Play in the Tutorials debug panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
