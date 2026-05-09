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
    static let close = localized(english: "Close", korean: "닫기")
    static let pause = localized(english: "Pause", korean: "일시정지")
    static let resume = localized(english: "Resume", korean: "재개")
    static let languages = localized(english: "Languages", korean: "언어")
    static let from = localized(english: "From", korean: "원문")
    static let to = localized(english: "To", korean: "번역")
    static let model = localized(english: "Model", korean: "모델")
    static let output = localized(english: "Output", korean: "출력")
    static let session = localized(english: "Session", korean: "세션")
    static let transcript = localized(english: "Transcript", korean: "기록")
    static let liveOutput = localized(english: "Live Output", korean: "실시간 출력")
    static let library = localized(english: "Library", korean: "저장소")
    static let dubbing = localized(english: "Dubbing", korean: "더빙")
    static let voiceOutput = localized(english: "Voice Output", korean: "음성 출력")
    static let menuBarTitle = localized(english: "Captions", korean: "자막")
    static let menuBarRunningTitle = localized(english: "Live", korean: "기록 중")
    static let menuBarPausedTitle = localized(english: "Paused", korean: "일시정지")
    static let floatingCaptions = localized(english: "Floating Captions", korean: "플로팅 자막")
    static let showFloatingCaptions = localized(english: "Show Floating Captions", korean: "플로팅 자막 보기")
    static let floatingCaptionPowerOn = localized(english: "ON", korean: "켜짐")
    static let floatingCaptionPowerOff = localized(english: "OFF", korean: "꺼짐")
    static let captionsWindow = localized(english: "Caption Window", korean: "자막 창")
    static let hideFloatingCaptions = localized(english: "Hide Floating Captions", korean: "플로팅 자막 숨기기")
    static let openMainWindow = localized(english: "Open Main Window", korean: "메인 창 열기")
    static let floatingDisplay = localized(english: "Floating Display", korean: "플로팅 표시")
    static let floatingDisplayDescription = localized(
        english: "Choose what appears in the detachable floating caption window.",
        korean: "따로 띄우는 플로팅 자막 창에 표시할 내용을 선택합니다."
    )
    static let floatingTextSize = localized(english: "Floating Text Size", korean: "플로팅 글자 크기")
    static let floatingLineCount = localized(english: "Floating Lines", korean: "플로팅 표시 줄 수")
    static let originalOnly = localized(english: "Original", korean: "원문")
    static let originalAndTranslation = localized(english: "Original + Translation", korean: "원문 + 번역")
    static let translationOnly = localized(english: "Translation", korean: "번역")
    static let textSizeSmall = localized(english: "Small", korean: "작게")
    static let textSizeMedium = localized(english: "Medium", korean: "보통")
    static let textSizeLarge = localized(english: "Large", korean: "크게")
    static let textSizeExtraLarge = localized(english: "Extra Large", korean: "아주 크게")
    static let noFloatingCaptionsYet = localized(
        english: "Live captions will appear here.",
        korean: "실시간 자막이 여기에 표시됩니다."
    )
    static let transcriptLint = localized(english: "Transcript Word Lint", korean: "기록 단어 다듬기")
    static let transcriptPolish = localized(english: "Transcript Polish", korean: "기록 다듬기")
    static let transcriptLintDescription = localized(
        english: "During silence, conservatively fixes transcription words when macOS spelling suggestions are confident. It does not remove repeated sentences or transcript content.",
        korean: "침묵 시간에 macOS 맞춤법 후보가 확실한 기록 단어만 보수적으로 고칩니다. 반복 문장이나 기록 내용은 제거하지 않습니다."
    )
    static let paragraphBreakSilenceInterval = localized(
        english: "Paragraph Break Silence",
        korean: "문단 개행 숨고르기"
    )
    static let paragraphBreakSilenceDescription = localized(
        english: "When speech resumes after this much silence, the transcript starts a new paragraph.",
        korean: "이 시간만큼 말이 멈춘 뒤 다시 시작되면 기록을 새 문단으로 나눕니다."
    )
    static let savedTranscripts = localized(english: "Saved Transcripts", korean: "저장된 기록")
    static let autoSave = localized(english: "Auto-save", korean: "자동 저장")
    static let autoSaveDescription = localized(
        english: "Transcript text is kept in memory while listening, then saved as a dated plain .txt file with a short content title when capture stops or the app quits.",
        korean: "기록 중에는 메모리에 유지하고, 캡처 중지 또는 앱 종료 직전에 날짜와 짧은 내용 제목이 들어간 일반 .txt 파일로 저장됩니다."
    )
    static let openSaveFolder = localized(
        english: "Open Save Folder",
        korean: "저장 폴더 열기"
    )
    static let openLibrary = localized(
        english: "Open Library",
        korean: "저장소 열기"
    )
    static let savedEmpty = localized(
        english: "Auto-saved transcripts will appear here.",
        korean: "자동 저장된 기록이 여기에 표시됩니다."
    )
    static let editSaved = localized(english: "Edit Saved", korean: "저장본 편집")
    static let title = localized(english: "Title", korean: "제목")
    static let original = localized(english: "Original", korean: "원문")
    static let originalDescription = localized(
        english: "Incoming speech with live paragraph cleanup.",
        korean: "들어오는 음성을 실시간 문단 정리와 함께 보여줍니다."
    )
    static let transcriptText = localized(english: "Transcript Text", korean: "기록 텍스트")
    static let deleteSavedTranscript = localized(english: "Delete Transcript", korean: "기록 삭제")
    static let translation = localized(english: "Translation", korean: "번역")
    static let translationDescription = localized(
        english: "Translated output aligned to the same transcript flow.",
        korean: "같은 기록 흐름에 맞춰 번역 결과를 정렬해 보여줍니다."
    )
    static let saveEdits = localized(english: "Save Edits", korean: "수정 저장")
    static let liveCaptions = localized(english: "Live Captions", korean: "실시간 기록")
    static let transcriptWorkspace = localized(english: "Transcript Workspace", korean: "실시간 기록")
    static let listening = localized(english: "Listening", korean: "듣는 중")
    static let idle = localized(english: "Idle", korean: "대기")
    static let noCaptionsYet = localized(english: "No captions yet", korean: "아직 기록 없음")
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
    static let untitledTranscript = localized(english: "Untitled Transcript", korean: "제목 없는 기록")

    static func languageSummary(source: String, target: String) -> String {
        localized(english: "\(source) to \(target)", korean: "\(source) → \(target)")
    }

    static func lineCount(_ count: Int) -> String {
        localized(english: "\(count) lines", korean: "\(count)줄")
    }

    static func seconds(_ seconds: Double) -> String {
        let value = seconds.rounded(.toNearestOrAwayFromZero) == seconds
            ? String(Int(seconds))
            : String(format: "%.1f", seconds)
        return localized(english: "\(value) sec", korean: "\(value)초")
    }

    static func startFailed(_ message: String) -> String {
        localized(english: "Start failed: \(message)", korean: "시작 실패: \(message)")
    }

    static func saveLibraryFailed(_ message: String) -> String {
        localized(
            english: "Could not save transcript library: \(message)",
            korean: "기록 저장소를 저장할 수 없습니다: \(message)"
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
            korean: "Mac 오디오 수신 중(\(sampleCount) 샘플, \(level) dB), 실시간 기록 중..."
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
