//
//  TutorialPreviewWindowView.swift
//  ElementalWarrior
//

import SwiftUI
import RealityKit

struct TutorialPreviewWindowView: View {
    @Environment(AppModel.self) private var appModel

    // Gesture state
    @State private var baseScale: Float = 1.0
    @State private var currentScale: Float = 1.0
    @State private var baseOffset: SIMD3<Float> = .zero
    @State private var currentOffset: SIMD3<Float> = .zero

    private var isPlaying: Bool {
        appModel.tutorialPlaybackManager.isPlaying
    }

    private var isLoading: Bool {
        appModel.tutorialPlaybackManager.isLoading
    }

    var body: some View {
        RealityView { content in
            content.add(appModel.tutorialPlaybackManager.rootEntity)
        } update: { content in
            // RealityView update is called when @Observable properties change
            // This ensures the view updates when tutorial playback state changes
        }
        // Pinch to scale
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    let newScale = baseScale * Float(value.magnification)
                    currentScale = max(0.3, min(3.0, newScale))
                    appModel.tutorialPlaybackManager.setUserScale(currentScale)
                }
                .onEnded { _ in
                    baseScale = currentScale
                }
        )
        // Drag to move
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Convert 2D drag to 3D offset (X and Z movement)
                    let dragScale: Float = 0.001  // Adjust sensitivity
                    let xOffset = Float(value.translation.width) * dragScale
                    let zOffset = Float(value.translation.height) * dragScale
                    currentOffset = baseOffset + SIMD3<Float>(xOffset, 0, zOffset)
                    appModel.tutorialPlaybackManager.setUserOffset(currentOffset)
                }
                .onEnded { _ in
                    baseOffset = currentOffset
                }
        )
        .overlay(alignment: .center) {
            if isLoading {
                // Loading indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading animation...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            } else if !isPlaying {
                Text("Press Play in the Tutorials debug panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
        .onAppear {
            appModel.isTutorialPreviewOpen = true
            // Reset gesture state
            baseScale = 1.0
            currentScale = 1.0
            baseOffset = .zero
            currentOffset = .zero
        }
        .onDisappear {
            appModel.isTutorialPreviewOpen = false
            appModel.tutorialPlaybackManager.stop()
            appModel.tutorialPlaybackManager.resetUserTransform()
        }
    }
}
