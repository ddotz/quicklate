import AVFoundation
import Speech

protocol SpeechCaptionerDelegate: AnyObject {
    func speechCaptioner(_ captioner: SpeechCaptioner, didRecognize text: String, isFinal: Bool)
    func speechCaptioner(_ captioner: SpeechCaptioner, didFail error: Error)
}

final class SpeechCaptioner: @unchecked Sendable {
    weak var delegate: SpeechCaptionerDelegate?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var currentLocale: Locale?

    func start(locale: Locale) async throws {
        let authorized = await requestAuthorization()
        guard authorized else { throw SpeechError.notAuthorized }

        stop()
        currentLocale = locale

        let recognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        self.recognizer = recognizer
        self.request = request
        self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                delegate?.speechCaptioner(
                    self,
                    didRecognize: result.bestTranscription.formattedString,
                    isFinal: result.isFinal
                )
            }

            if let error {
                delegate?.speechCaptioner(self, didFail: error)
            }
        }
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        request?.appendAudioSampleBuffer(sampleBuffer)
    }

    func restart() async throws {
        guard let currentLocale else { return }
        try await start(locale: currentLocale)
    }

    func stop() {
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            AppText.speechPermissionDenied
        case .recognizerUnavailable:
            AppText.recognizerUnavailable
        }
    }
}
