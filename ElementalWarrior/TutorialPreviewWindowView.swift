//
//  TutorialPreviewWindowView.swift
//  ElementalWarrior
//

import SwiftUI
import RealityKit

struct TutorialPreviewWindowView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let size = appModel.tutorialPlaybackManager.previewSize

        RealityView { content in
            content.add(appModel.tutorialPlaybackManager.rootEntity)
        }
        .frame(width: CGFloat(size.x), height: CGFloat(size.y))
        .overlay {
            if !appModel.tutorialPlaybackManager.isPlaying {
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
