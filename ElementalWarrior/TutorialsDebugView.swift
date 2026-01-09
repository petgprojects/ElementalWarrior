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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(category.title)
                .font(.title2)
                .bold()

            HStack(alignment: .top, spacing: 16) {
                List(tutorials, selection: $selectedTutorial) { tutorial in
                    TutorialRow(
                        tutorial: tutorial,
                        isPlaying: appModel.tutorialPlaybackManager.isPlaying &&
                            appModel.tutorialPlaybackManager.currentTutorial == tutorial
                    )
                    .tag(tutorial)
                }
                .listStyle(.inset)
                .frame(minWidth: 220, maxWidth: 280)

                VStack(alignment: .leading, spacing: 12) {
                    if let selectedTutorial {
                        HStack(spacing: 12) {
                            if appModel.tutorialPlaybackManager.isPlaying &&
                                appModel.tutorialPlaybackManager.currentTutorial == selectedTutorial {
                                Button("Stop") {
                                    appModel.tutorialPlaybackManager.stop()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                            } else {
                                Button("Play") {
                                    if !appModel.isTutorialPreviewOpen {
                                        openWindow(id: "tutorialPreview")
                                    }
                                    Task {
                                        await appModel.tutorialPlaybackManager.play(tutorial: selectedTutorial)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }

                            Text("Looping")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if appModel.tutorialPlaybackManager.isPlaying &&
                            appModel.tutorialPlaybackManager.currentTutorial == selectedTutorial {
                            Text(selectedTutorial.description)
                                .font(.callout)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        } else {
                            Text("Preview appears in the Tutorials Preview window.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }

                    } else {
                        Text("Select a tutorial to preview the hand animation.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    if let error = appModel.tutorialPlaybackManager.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()
                }
            }

            Spacer()
        }
        .padding(24)
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
