//
//  TutorialsDebugView.swift
//  ElementalWarrior
//

import SwiftUI
import RealityKit

struct TutorialsDebugView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selection: TutorialCategory? = .fireball
    @State private var selectedTutorial: HandTutorial?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(TutorialCategory.allCases, id: \.self) { category in
                    Label(category.title, systemImage: category.systemImage)
                        .tag(category)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Tutorials")
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
        } detail: {
            if let selection {
                TutorialsDetailView(
                    category: selection,
                    selectedTutorial: $selectedTutorial
                )
            } else {
                TutorialsDetailView(
                    category: .fireball,
                    selectedTutorial: $selectedTutorial
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if selectedTutorial == nil, let category = selection {
                selectedTutorial = HandTutorial.tutorials(in: category).first
            }
        }
        .onChange(of: selection) { _, newValue in
            guard let newValue else { return }
            selectedTutorial = HandTutorial.tutorials(in: newValue).first
            appModel.tutorialPlaybackManager.stop(resetTutorial: true)
        }
        .onChange(of: selectedTutorial) { _, newValue in
            if appModel.tutorialPlaybackManager.isPlaying,
               appModel.tutorialPlaybackManager.currentTutorial != newValue {
                appModel.tutorialPlaybackManager.stop()
            }
        }
    }
}

private struct TutorialsDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    let category: TutorialCategory
    @Binding var selectedTutorial: HandTutorial?

    private var tutorials: [HandTutorial] {
        HandTutorial.tutorials(in: category)
    }

    private var isPlayingSelected: Bool {
        guard let selectedTutorial else { return false }
        return appModel.tutorialPlaybackManager.isPlaying &&
            appModel.tutorialPlaybackManager.currentTutorial == selectedTutorial
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left side: Tutorial list
            VStack(alignment: .leading, spacing: 0) {
                Text(category.title)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                List(tutorials, selection: $selectedTutorial) { tutorial in
                    TutorialRow(
                        tutorial: tutorial,
                        isPlaying: appModel.tutorialPlaybackManager.isPlaying &&
                            appModel.tutorialPlaybackManager.currentTutorial == tutorial
                    )
                    .tag(tutorial)
                }
                .listStyle(.inset)
            }
            .frame(width: 260)
            .background(Color(white: 0.05))

            Divider()

            // Right side: Tutorial details panel
            if let selectedTutorial {
                TutorialDetailPanel(
                    tutorial: selectedTutorial,
                    isPlaying: isPlayingSelected,
                    isLoading: appModel.tutorialPlaybackManager.isLoading,
                    error: appModel.tutorialPlaybackManager.lastError,
                    onPlay: {
                        if !appModel.isTutorialPreviewOpen {
                            openWindow(id: "tutorialPreview")
                        }
                        Task {
                            await appModel.tutorialPlaybackManager.play(tutorial: selectedTutorial)
                        }
                    },
                    onStop: {
                        appModel.tutorialPlaybackManager.stop()
                    }
                )
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "hand.raised")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a Tutorial")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Text("Choose a tutorial from the list to see details and preview the animation.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct TutorialDetailPanel: View {
    let tutorial: HandTutorial
    let isPlaying: Bool
    let isLoading: Bool
    let error: String?
    let onPlay: () -> Void
    let onStop: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(tutorial.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Duration: \(String(format: "%.1f", tutorial.loopDuration))s loop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Play controls
                HStack(spacing: 12) {
                    if isPlaying {
                        Button(action: onStop) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button(action: onPlay) {
                            Label(isLoading ? "Loading..." : "Play", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(isLoading)
                    }

                    if isPlaying {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Playing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Label("How to Perform", systemImage: "hand.point.up.left")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(tutorial.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Error display
                if let error {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Error", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.red)

                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                Divider()

                // Tips section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Preview Tips", systemImage: "lightbulb")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 6) {
                        TipRow(icon: "hand.pinch", text: "Pinch to zoom in or out")
                        TipRow(icon: "hand.draw", text: "Drag to reposition the animation")
                        TipRow(icon: "arrow.counterclockwise", text: "Animation loops automatically")
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(8)

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TutorialRow: View {
    let tutorial: HandTutorial
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(tutorial.title)
                .font(.body)
            Spacer()
            if isPlaying {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}
