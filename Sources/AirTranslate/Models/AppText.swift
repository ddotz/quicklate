import Foundation

enum AppText {
    static var usesKorean: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ko") == true
    }

    static func localized(english: String, korean: String) -> String {
        usesKorean ? korean : english
    }

    static let ready = localized(english: "Ready", korean: "준비됨")
    static let stopped = localized(english: "Stopped", korean: "중지됨")
    static let paused = localized(english: "Paused", korean: "일시정지됨")
    static let capture = localized(english: "Capture", korean: "캡처")
    static let start = localized(english: "Start", korean: "시작")
    static let stop = localized(english: "Stop", korean: "중지")
    static let pause = localized(english: "Pause", korean: "일시정지")
    static let resume = localized(english: "Resume", korean: "재개")
    static let languages = localized(english: "Languages", korean: "언어")
    static let from = localized(english: "From", korean: "원문")
    static let to = localized(english: "To", korean: "번역")
    static let model = localized(english: "Model", korean: "모델")
    static let output = localized(english: "Output", korean: "출력")
    static let dubbing = localized(english: "Dubbing", korean: "더빙")
    static let transcriptLint = localized(english: "Transcript Word Lint", korean: "전사 단어 린트")
    static let transcriptLintDescription = localized(
        english: "During silence, conservatively fixes transcription words when macOS spelling suggestions are confident. It does not remove repeated sentences or transcript content.",
        korean: "침묵 시간에 macOS 맞춤법 후보가 확실한 전사 단어만 보수적으로 고칩니다. 반복 문장이나 전사 내용은 제거하지 않습니다."
    )
    static let savedTranscripts = localized(english: "Saved Transcripts", korean: "저장된 전사")
    static let autoSave = localized(english: "Auto-save", korean: "자동 저장")
    static let autoSaveDescription = localized(
        english: "Transcript text is kept in memory while listening, then saved as a dated plain .txt file with a short content title when capture stops or the app quits.",
        korean: "전사 중에는 메모리에 유지하고, 캡처 중지 또는 앱 종료 직전에 날짜와 짧은 내용 제목이 들어간 일반 .txt 파일로 저장됩니다."
    )
    static let openSaveFolder = localized(
        english: "Open Save Folder",
        korean: "저장 폴더 열기"
    )
    static let savedEmpty = localized(
        english: "Auto-saved transcripts will appear here.",
        korean: "자동 저장된 전사가 여기에 표시됩니다."
    )
    static let editSaved = localized(english: "Edit Saved", korean: "저장본 편집")
    static let title = localized(english: "Title", korean: "제목")
    static let original = localized(english: "Original", korean: "원문")
    static let transcriptText = localized(english: "Transcript Text", korean: "전사 텍스트")
    static let translation = localized(english: "Translation", korean: "번역")
    static let saveEdits = localized(english: "Save Edits", korean: "수정 저장")
    static let liveCaptions = localized(english: "Live Captions", korean: "실시간 전사")
    static let listening = localized(english: "Listening", korean: "듣는 중")
    static let idle = localized(english: "Idle", korean: "대기")
    static let noCaptionsYet = localized(english: "No captions yet", korean: "아직 전사 없음")
    static let noCaptionsDescription = localized(
        english: "Start capture, play audio on this Mac, and grant Screen Recording, System Audio Recording, and Speech permissions.",
        korean: "캡처를 시작하고 이 Mac에서 오디오를 재생한 뒤 화면 기록, 시스템 오디오 녹음, 음성 인식 권한을 허용하세요."
    )
    static let openPrivacySettings = localized(
        english: "Open Privacy Settings",
        korean: "개인정보 보호 설정 열기"
    )
    static let permissions = localized(english: "Permissions", korean: "권한")
    static let permissionsHelp = localized(
        english: "AirTranslate needs Screen Recording, System Audio Recording, and Speech Recognition permission. After changing privacy settings, quit and relaunch the app.",
        korean: "AirTranslate에는 화면 기록, 시스템 오디오 녹음, 음성 인식 권한이 필요합니다. 개인정보 보호 설정을 변경한 뒤 앱을 종료하고 다시 실행하세요."
    )
    static let checkingScreenPermission = localized(
        english: "Checking screen recording permission...",
        korean: "화면 기록 권한 확인 중..."
    )
    static let checkingSpeechPermission = localized(
        english: "Checking speech recognition permission...",
        korean: "음성 인식 권한 확인 중..."
    )
    static let startingCapture = localized(
        english: "Starting Mac audio capture...",
        korean: "Mac 오디오 캡처 시작 중..."
    )
    static let listeningForSpeech = localized(
        english: "Listening to Mac audio, waiting for speech...",
        korean: "Mac 오디오를 듣는 중, 음성을 기다리는 중..."
    )
    static let translating = localized(english: "Translating...", korean: "번역 중...")
    static let untitledTranscript = localized(english: "Untitled Transcript", korean: "제목 없는 전사")

    static func languageSummary(source: String, target: String) -> String {
        localized(english: "\(source) to \(target)", korean: "\(source) → \(target)")
    }

    static func startFailed(_ message: String) -> String {
        localized(english: "Start failed: \(message)", korean: "시작 실패: \(message)")
    }

    static func saveLibraryFailed(_ message: String) -> String {
        localized(
            english: "Could not save transcript library: \(message)",
            korean: "전사 저장소를 저장할 수 없습니다: \(message)"
        )
    }

    static func receivingAudioWaiting(sampleCount: Int) -> String {
        localized(
            english: "Receiving Mac audio (\(sampleCount) samples), waiting for speech...",
            korean: "Mac 오디오 수신 중(\(sampleCount) 샘플), 음성을 기다리는 중..."
        )
    }

    static func receivingSilentAudio(sampleCount: Int, level: Int) -> String {
        localized(
            english: "Receiving silent audio (\(sampleCount) samples, \(level) dB). Check System Audio Recording.",
            korean: "무음 오디오 수신 중(\(sampleCount) 샘플, \(level) dB). 시스템 오디오 녹음 권한을 확인하세요."
        )
    }

    static func receivingAudioTranscribing(sampleCount: Int, level: Int) -> String {
        localized(
            english: "Receiving Mac audio (\(sampleCount) samples, \(level) dB), transcribing live...",
            korean: "Mac 오디오 수신 중(\(sampleCount) 샘플, \(level) dB), 실시간 전사 중..."
        )
    }

    static func unsupportedTranslation(source: String, target: String) -> String {
        localized(
            english: "Apple Translation does not support \(source) to \(target).",
            korean: "Apple Translation은 \(source) → \(target) 번역을 지원하지 않습니다."
        )
    }

    static let speechPermissionDenied = localized(
        english: "Speech recognition permission was not granted.",
        korean: "음성 인식 권한이 허용되지 않았습니다."
    )
    static let recognizerUnavailable = localized(
        english: "The selected speech recognizer is unavailable.",
        korean: "선택한 음성 인식기를 사용할 수 없습니다."
    )
    static let screenRecordingNotGranted = localized(
        english: "Screen Recording permission is not active for this signed AirTranslate app. Grant it once, then quit and relaunch AirTranslate.",
        korean: "서명된 AirTranslate 앱에 화면 기록 권한이 활성화되어 있지 않습니다. 한 번 허용한 뒤 AirTranslate를 종료하고 다시 실행하세요."
    )
    static let noActiveDisplay = localized(
        english: "No active display was available for system audio capture.",
        korean: "시스템 오디오 캡처에 사용할 수 있는 활성 디스플레이가 없습니다."
    )

    static func languageTitle(for id: String, fallback: String) -> String {
        switch id {
        case "en-US":
            localized(english: "English", korean: "영어")
        case "ko-KR":
            localized(english: "Korean", korean: "한국어")
        case "ja-JP":
            localized(english: "Japanese", korean: "일본어")
        case "zh-CN":
            localized(english: "Chinese Simplified", korean: "중국어 간체")
        case "es-ES":
            localized(english: "Spanish", korean: "스페인어")
        case "fr-FR":
            localized(english: "French", korean: "프랑스어")
        case "de-DE":
            localized(english: "German", korean: "독일어")
        default:
            fallback
        }
    }
}
