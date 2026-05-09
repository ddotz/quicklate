import SwiftUI

struct SidebarView: View {
    @Bindable var session: TranslationSessionStore

    var body: some View {
        Form {
            Section(AppText.capture) {
                Button {
                    session.isRunning ? session.stop() : session.start()
                } label: {
                    Label(session.isRunning ? AppText.stop : AppText.start, systemImage: session.isRunning ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)

                if session.isRunning {
                    Button {
                        session.isPaused ? session.resume() : session.pause()
                    } label: {
                        Label(
                            session.isPaused ? AppText.resume : AppText.pause,
                            systemImage: session.isPaused ? "play.fill" : "pause.fill"
                        )
                    }
                }

                Text(session.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if session.statusMessage.localizedCaseInsensitiveContains("permission")
                    || session.statusMessage.localizedCaseInsensitiveContains("권한") {
                    Button {
                        session.openPrivacySettings()
                    } label: {
                        Label(AppText.openPrivacySettings, systemImage: "gear")
                    }
                }
            }

            Section(AppText.languages) {
                Picker(AppText.from, selection: $session.sourceLanguage) {
                    ForEach(LanguageOption.supported) { language in
                        Text(language.localizedTitle).tag(language)
                    }
                }

                Picker(AppText.to, selection: $session.targetLanguage) {
                    ForEach(LanguageOption.supported) { language in
                        Text(language.localizedTitle).tag(language)
                    }
                }
            }

            Section(AppText.model) {
                Picker(AppText.model, selection: $session.selectedModel) {
                    ForEach(IntelligenceModel.allCases) { model in
                        Text(model.title).tag(model)
                    }
                }

                Text(session.selectedModel.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(AppText.output) {
                Toggle(AppText.dubbing, isOn: $session.isDubbingEnabled)

                Toggle(AppText.transcriptLint, isOn: $session.isTranscriptLintEnabled)

                Text(AppText.transcriptLintDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(AppText.savedTranscripts) {
                Label(AppText.autoSave, systemImage: "checkmark.circle")

                Text(AppText.autoSaveDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    session.openTranscriptsFolder()
                } label: {
                    Label(AppText.openSaveFolder, systemImage: "folder")
                }

                if session.savedTranscripts.isEmpty {
                    Text(AppText.savedEmpty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.savedTranscripts) { transcript in
                        Button {
                            session.selectSavedTranscript(transcript.id)
                        } label: {
                            SavedTranscriptRow(
                                transcript: transcript,
                                isSelected: session.selectedSavedTranscriptID == transcript.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if session.selectedSavedTranscriptID != nil {
                Section(AppText.editSaved) {
                    Text(AppText.transcriptText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $session.savedDraftSourceText)
                        .font(.caption)
                        .frame(minHeight: 160)

                    HStack {
                        Button {
                            session.saveSelectedTranscriptEdits()
                        } label: {
                            Label(AppText.saveEdits, systemImage: "checkmark")
                        }

                        Button(role: .destructive) {
                            session.deleteSelectedTranscript()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("AirTranslate")
    }
}

private struct SavedTranscriptRow: View {
    let transcript: SavedTranscript
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isSelected ? "doc.text.fill" : "doc.text")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(transcript.title)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(transcript.updatedAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
