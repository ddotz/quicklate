# AirTranslate

AirTranslate는 Mac에서 재생되는 시스템 오디오를 실시간으로 전사하고 번역하는 macOS 앱입니다. AirPods 같은 출력 장치로 들리는 Mac 재생음을 대상으로 하며, 외부 마이크 입력만 번역하는 방식이 아니라 ScreenCaptureKit의 시스템 오디오 캡처를 사용합니다.

## 주요 기능

- Mac 시스템 오디오 실시간 캡처
- Apple Speech 기반 실시간 전사
- Apple Translation 기반 실시간 번역
- 캡처 세션을 유지한 상태의 전사 일시정지/재개
- 사용자가 직접 선택하는 원문/번역 언어
- 원문과 번역을 좌우 두 패널로 계속 누적 표시
- 긴 침묵이나 숨 고르기 구간에서 문맥을 유지한 문단 정리
- 선택 시 숨 고르기 구간에서 macOS 맞춤법 후보 기반으로 존재하지 않는 전사 단어를 보수적으로 교정하는 전사 단어 린트
- 문단 전환 시 빈 줄이 보이는 2중 개행 처리
- 전사 중에는 원문 텍스트를 메모리에 유지하고, 캡처 중지/앱 종료 직전에 날짜와 내용 기반 파일명으로 저장
- 저장된 전사 텍스트 확인, 수정, 삭제
- macOS 선호 언어에 따라 한국어/영어 UI 자동 표시
- 마지막으로 선택한 원문/번역 언어, 모델, 더빙 설정 재실행 시 복원
- 선택 모델 구조 준비: Apple System, Apple On-Device, Speech Captions
- 선택적 번역 음성 더빙 토글

## 현재 동작 요약

앱을 시작하면 선택한 원문 언어로 Mac 시스템 오디오를 듣고, 전사 결과를 왼쪽 원문 패널에 계속 이어 붙입니다. 번역 결과는 오른쪽 번역 패널에 표시됩니다.

짧은 실시간 업데이트는 같은 문장 안에서 갱신되고, 긴 침묵 뒤 새 발화가 들어오면 새 채팅이나 새 카드로 넘어가지 않고 같은 기록 안에서 문단만 분리됩니다. 이때 원문과 번역 모두 문단 사이에 빈 줄이 들어가 읽기 편하게 정리됩니다.

전사 결과는 실시간 처리 중에는 메모리에 유지됩니다. 캡처를 중지하거나 앱이 종료되기 직전에 일반 텍스트 파일로 저장되므로, 전사 중 잦은 파일 쓰기가 레이턴시 병목이 되지 않도록 했습니다. 파일명은 `날짜_짧은내용제목.txt` 형식으로 생성됩니다. 저장된 항목은 왼쪽 아래 `저장된 전사` 영역에 표시되며, 선택 후 전사 텍스트를 직접 수정하고 다시 저장하거나 삭제할 수 있습니다. `저장 폴더 열기` 버튼으로 Finder에서 저장 위치를 바로 열 수 있습니다.

## 요구 사항

- macOS 26.0 이상
- Swift 6.2 이상
- 시스템 오디오 캡처가 가능한 Mac
- Apple Speech 및 Translation 프레임워크 사용 가능 환경

이 프로젝트는 Swift Package Manager 기반 macOS 앱입니다.

## 필요한 권한

AirTranslate는 다음 권한이 필요합니다.

- 화면 기록
- 시스템 오디오 녹음
- 음성 인식

권한을 처음 허용한 뒤에는 앱을 종료하고 다시 실행해야 macOS 개인정보 보호 설정이 안정적으로 반영됩니다.

권한 상태가 꼬였을 때는 다음 명령으로 AirTranslate 권한을 초기화할 수 있습니다.

```bash
./script/build_and_run.sh --reset-permissions
```

## 실행 방법

일반 실행:

```bash
./script/build_and_run.sh
```

빌드 후 실행 확인:

```bash
./script/build_and_run.sh --verify
```

로그 확인:

```bash
./script/build_and_run.sh --logs
```

SwiftPM 빌드 검증:

```bash
swift build -Xswiftc -warnings-as-errors
```

Codex 앱에서는 `.codex/environments/environment.toml`의 `Run` 액션이 `./script/build_and_run.sh`에 연결되어 있습니다.

## 사용 방법

1. `원문` 언어와 `번역` 언어를 선택합니다.
2. `시작`을 눌러 Mac 시스템 오디오 캡처를 시작합니다.
3. Mac에서 영상, 회의, 강의, 음악 외 음성 콘텐츠 등을 재생합니다.
4. 왼쪽 `원문` 패널에서 전사 내용을 확인합니다.
5. 오른쪽 `번역` 패널에서 번역 내용을 확인합니다.
6. 전사 내용은 캡처 중지 또는 앱 종료 직전에 자동 저장됩니다.
7. `저장 폴더 열기`를 눌러 Finder에서 저장 파일을 확인합니다.
8. 저장된 항목을 선택해 전사 텍스트를 수정하거나 삭제합니다.

## 저장 위치

저장된 전사는 사용자 Application Support 폴더에 일반 텍스트 파일로 보관됩니다. JSON 메타데이터가 아니라 전사된 원문 텍스트가 그대로 저장됩니다.

```text
~/Library/Application Support/AirTranslate/Transcripts/*.txt
```

새 자동 저장 파일은 `2026-05-09_내용과-관련된-짧은-제목.txt`처럼 날짜와 전사 내용에서 뽑은 짧은 제목을 함께 사용합니다. 같은 이름이 이미 있으면 뒤에 `-2`, `-3`을 붙입니다. 앱은 이 폴더의 `.txt` 파일을 스캔해 저장된 전사 목록을 구성합니다.

## 프로젝트 구조

```text
Package.swift
Sources/AirTranslate/
  App/
    AirTranslateApp.swift
  Models/
    AppText.swift
    CaptionLine.swift
    IntelligenceModel.swift
    LanguageOption.swift
    SavedTranscript.swift
  Services/
    AppleTranslationService.swift
    LiveSpeechTranscriber.swift
    SpeechCaptioner.swift
    SystemAudioCapture.swift
    TranslationSessionStore.swift
  Views/
    CaptionBoardView.swift
    ContentView.swift
    SettingsView.swift
    SidebarView.swift
script/
  build_and_run.sh
```

## 핵심 구현

- `SystemAudioCapture`: ScreenCaptureKit으로 Mac 시스템 오디오를 캡처합니다.
- `LiveSpeechTranscriber`: Apple Speech의 `SpeechAnalyzer`와 `SpeechTranscriber`로 실시간 전사를 수행합니다.
- `AppleTranslationService`: Apple Translation 프레임워크로 문장 단위 번역을 수행합니다.
- `TranslationSessionStore`: 캡처, 전사, 번역, 문단 정리, 저장본 관리를 조율합니다.
- `CaptionBoardView`: 원문/번역 두 패널을 표시합니다.
- `SidebarView`: 캡처 제어, 언어 선택, 모델 선택, 더빙, 자동 저장된 전사 편집 UI를 제공합니다.
- `AppText`: 현재 macOS 선호 언어에 따라 한국어/영어 UI 문자열을 선택합니다.

## 문단 정리 방식

실시간 전사는 부분 결과가 계속 갱신되기 때문에 기존 내용을 덮어쓰지 않도록 누적 버퍼를 사용합니다.

- 현재 말하고 있는 부분은 임시 부분 전사로 유지합니다.
- 긴 침묵이 감지되면 현재 부분 전사를 확정합니다.
- 침묵 뒤 새 발화는 같은 기록 안에서 새 문단으로 붙입니다.
- 문장 내부는 1회 개행, 문단 전환은 2회 개행으로 정리합니다.
- 번역은 원문의 문단 구조를 따라갑니다.

## 알려진 한계

- Apple Speech/Translation 지원 언어와 설치된 언어 자산 상태에 따라 동작이 달라질 수 있습니다.
- macOS 개인정보 보호 권한은 서명 상태와 번들 식별자에 민감하므로, 빌드 방식이 바뀌면 권한을 다시 허용해야 할 수 있습니다.
- 시스템 오디오에 다른 앱 음성, 알림음, TTS가 섞이면 전사 결과에도 섞일 수 있습니다.
- 현재 번역 품질과 문장 분리는 Apple 프레임워크 결과에 의존합니다.

## 개발 메모

이 앱은 로컬 SwiftPM macOS 앱으로 관리합니다. GUI 앱 실행은 raw executable이 아니라 `script/build_and_run.sh`가 만든 `.app` 번들을 통해 수행합니다.

빌드 산출물인 `.build/`와 `dist/`는 git에 포함하지 않습니다.
