import SwiftUI

struct CaptionBoardView: View {
    @Bindable var session: TranslationSessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppText.liveCaptions)
                        .font(.title2.weight(.semibold))

                    Text(session.languageSummary)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(
                    session.isPaused ? AppText.paused : (session.isRunning ? AppText.listening : AppText.idle),
                    systemImage: session.isPaused ? "pause.circle.fill" : (session.isRunning ? "waveform" : "pause.circle")
                )
                .foregroundStyle(session.isPaused ? .orange : (session.isRunning ? .green : .secondary))
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if session.lines.isEmpty {
                            ContentUnavailableView(
                                AppText.noCaptionsYet,
                                systemImage: "captions.bubble",
                                description: Text(AppText.noCaptionsDescription)
                            )
                            .frame(maxWidth: .infinity, minHeight: 320)
                        }

                        ForEach(session.lines) { line in
                            CaptionLineView(line: line)
                                .id(line.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.vertical, 4)
                    .animation(.spring(response: 0.32, dampingFraction: 0.86), value: session.lines.count)
                }
                .onChange(of: session.lines.last?.id) { _, id in
                    if let id {
                        withAnimation(.easeOut(duration: 0.22)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: session.lines.last?.revision) { _, _ in
                    if let id = session.lines.last?.id {
                        withAnimation(.easeOut(duration: 0.22)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(24)
    }
}

private struct CaptionLineView: View {
    let line: CaptionLine

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            TranscriptPane(title: AppText.original, text: line.sourceText, isPrimary: true)
            TranscriptPane(title: AppText.translation, text: line.translatedText, isPrimary: false)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct TranscriptPane: View {
    let title: String
    let text: String
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            StreamingTranscriptText(
                text: text,
                font: isPrimary ? .body : .body.weight(.medium)
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 420, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StreamingTranscriptText: View {
    let text: String
    let font: Font

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var settledText = ""
    @State private var appearingText = ""
    @State private var appearingOpacity = 1.0
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        Text(renderedText)
            .font(font)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .onAppear {
                stream(to: text)
            }
            .onChange(of: text) { _, newText in
                stream(to: newText)
            }
            .onDisappear {
                streamTask?.cancel()
            }
    }

    private var renderedText: AttributedString {
        var rendered = AttributedString(settledText)
        var appearing = AttributedString(appearingText)
        appearing.foregroundColor = .primary.opacity(appearingOpacity)
        rendered.append(appearing)
        return rendered
    }

    private var visibleText: String {
        settledText + appearingText
    }

    private func stream(to newText: String) {
        streamTask?.cancel()

        if !appearingText.isEmpty {
            settledText += appearingText
            appearingText = ""
            appearingOpacity = 1
        }

        guard !newText.isEmpty else {
            settledText = ""
            appearingText = ""
            return
        }

        guard !reduceMotion else {
            settledText = newText
            return
        }

        guard newText.hasPrefix(visibleText), newText.count > visibleText.count else {
            settledText = newText
            appearingText = ""
            appearingOpacity = 1
            return
        }

        let remainingText = String(newText.dropFirst(visibleText.count))
        let chunkSize = remainingText.count > 72 ? 4 : (remainingText.count > 28 ? 3 : 2)
        let delay = remainingText.count > 72 ? 18_000_000 : (remainingText.count > 28 ? 28_000_000 : 38_000_000)
        let fadeDuration = remainingText.count > 72 ? 0.12 : 0.18
        let chunks = remainingText.chunkedForTranscriptStreaming(maxCharacters: chunkSize)

        streamTask = Task { @MainActor in
            for chunk in chunks {
                if Task.isCancelled {
                    return
                }

                if !appearingText.isEmpty {
                    settledText += appearingText
                }

                appearingText = chunk
                appearingOpacity = 0.12

                withAnimation(.easeOut(duration: fadeDuration)) {
                    appearingOpacity = 1
                }

                try? await Task.sleep(nanoseconds: UInt64(delay))
            }

            if !appearingText.isEmpty {
                settledText += appearingText
                appearingText = ""
                appearingOpacity = 1
            }
        }
    }
}

private extension String {
    func chunkedForTranscriptStreaming(maxCharacters: Int) -> [String] {
        guard maxCharacters > 0 else { return [self] }

        var chunks: [String] = []
        var current = ""

        for character in self {
            current.append(character)
            if current.count >= maxCharacters || character.isWhitespace || character.isPunctuation {
                chunks.append(current)
                current = ""
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks
    }
}
