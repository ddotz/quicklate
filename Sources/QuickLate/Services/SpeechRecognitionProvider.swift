import CoreMedia
import Foundation

protocol SpeechRecognitionProvider: AnyObject, Sendable {
    var delegate: LiveSpeechTranscriberDelegate? { get set }
    var id: SpeechRecognitionProviderID { get }
    func start(language: LanguageOption) async throws
    func append(_ sampleBuffer: CMSampleBuffer)
    func setPaused(_ isPaused: Bool)
    func stop()
}

enum SpeechRecognitionProviderID: String, CaseIterable, Identifiable, Sendable {
    case appleSpeech
    case openAIRealtime
    case whisperKit
    case sherpaOnnx
    case senseVoice

    var id: String { rawValue }
}

final class AppleSpeechRecognitionProvider: SpeechRecognitionProvider, @unchecked Sendable {
    let id = SpeechRecognitionProviderID.appleSpeech
    private let transcriber: LiveSpeechTranscriber

    init(transcriber: LiveSpeechTranscriber = LiveSpeechTranscriber()) {
        self.transcriber = transcriber
    }

    var delegate: LiveSpeechTranscriberDelegate? {
        get { transcriber.delegate }
        set { transcriber.delegate = newValue }
    }

    func start(language: LanguageOption) async throws {
        try await transcriber.start(languages: [language])
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        transcriber.append(sampleBuffer)
    }

    func setPaused(_ isPaused: Bool) {
        transcriber.setPaused(isPaused)
    }

    func stop() {
        transcriber.stop()
    }
}

final class OpenAIRealtimeSpeechRecognitionProvider: SpeechRecognitionProvider, @unchecked Sendable {
    let id = SpeechRecognitionProviderID.openAIRealtime
    private let transcriber: OpenAIRealtimeTranscriber
    var transcriptionModel: OpenAIRealtimeTranscriptionModel

    init(
        transcriber: OpenAIRealtimeTranscriber = OpenAIRealtimeTranscriber(),
        transcriptionModel: OpenAIRealtimeTranscriptionModel = .off
    ) {
        self.transcriber = transcriber
        self.transcriptionModel = transcriptionModel
    }

    var delegate: LiveSpeechTranscriberDelegate? {
        get { transcriber.delegate }
        set { transcriber.delegate = newValue }
    }

    func start(language: LanguageOption) async throws {
        try await transcriber.start(language: language, model: transcriptionModel)
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        transcriber.append(sampleBuffer)
    }

    func setPaused(_ isPaused: Bool) {
        transcriber.setPaused(isPaused)
    }

    func stop() {
        transcriber.stop()
    }
}
