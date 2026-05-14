![QuickLate 로고](docs/assets/quicklate-logo.png)

# QuickLate

QuickLate는 macOS 메뉴바에서 실행되는 실시간 시스템 오디오 전사·번역·플로팅 자막 앱입니다.

**언어:** [English](README.md) | 한국어

## QuickLate가 하는 일

- ScreenCaptureKit으로 Mac 시스템 오디오를 직접 캡처합니다.
- Apple Speech로 재생 오디오를 실시간 자막으로 바꿉니다.
- Apple Translation을 기본 번역 경로로 사용합니다.
- 필요한 Apple 번역 언어팩을 라이브 작업 화면 안에서 바로 내려받게 합니다.
- QuickLate가 앞에 없어도 다른 앱 위에 플로팅 자막을 표시합니다.
- 사용자가 OpenAI API 키를 제공하면 선택적으로 GPT realtime 전사/번역을 사용할 수 있습니다.
- 저장된 기록은 Mac 안의 일반 텍스트 파일로 남깁니다.

## 제품 방향

QuickLate는 AirTranslate 오픈소스 기반에서 출발하지만, 새로운 서비스명·아이콘·로고·사용 흐름으로 다시 만드는 제품입니다.

목표 흐름은 다음과 같습니다.

1. macOS 메뉴바에서 QuickLate를 엽니다.
2. 원문/번역 언어를 선택합니다.
3. Apple 언어팩이 없으면 **Download & Start**로 내려받고 바로 시작합니다.
4. 라이브 작업 화면 또는 다른 앱 위의 플로팅 자막으로 번역을 봅니다.

## 요구 사항

- macOS 26.0 이상
- Swift 6.2 이상
- 시스템 오디오 캡처를 지원하는 Mac
- Apple Speech 및 Apple Translation 프레임워크 사용 가능 환경
- 선택 사항: GPT 모드용 OpenAI API 키

## 소스에서 빌드

앱 번들 실행:

```bash
./script/build_and_run.sh
```

빌드 후 실행 확인:

```bash
./script/build_and_run.sh --verify
```

SwiftPM 확인:

```bash
swift build
swift test
```

## 저장된 기록

저장된 기록은 다음 위치에 일반 텍스트 파일로 저장됩니다.

```text
~/Library/Application Support/QuickLate/Transcripts/*.txt
```

## 프로젝트 구조

```text
Package.swift
Resources/
  AppIcon.png
  AppIcon.icns
  QuickLateLogo.png
Sources/QuickLate/
Sources/QuickLateCore/
Tests/QuickLateCoreTests/
docs/superpowers/specs/
```

## 라이선스와 출처

QuickLate는 himomohi의 Apache-2.0 AirTranslate 기반에서 파생되었습니다. 자세한 내용은 `LICENSE`와 `NOTICE`를 확인하세요.
