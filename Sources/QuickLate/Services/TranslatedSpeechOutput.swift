import AudioToolbox
import AVFAudio
import CoreAudio
import Foundation

final class TranslatedSpeechOutput: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private let ducker = SystemOutputDucker()
    private var queuedSpeechKeys: Set<String> = []

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: LanguageOption) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        let speechKey = normalizedSpeechKey(trimmedText, language: language)
        guard !queuedSpeechKeys.contains(speechKey) else { return }

        queuedSpeechKeys.insert(speechKey)
        ducker.beginDucking()

        let utterance = AVSpeechUtterance(string: trimmedText)
        utterance.voice = AVSpeechSynthesisVoice(language: language.id)
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        queuedSpeechKeys.removeAll()
        ducker.cancelDucking()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        removeQueuedSpeechKey(for: utterance)
        ducker.endDucking()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        removeQueuedSpeechKey(for: utterance)
        ducker.endDucking()
    }

    private func removeQueuedSpeechKey(for utterance: AVSpeechUtterance) {
        let languageID = utterance.voice?.language ?? Locale.current.identifier
        let language = LanguageOption(id: languageID, title: languageID, locale: Locale(identifier: languageID))
        queuedSpeechKeys.remove(normalizedSpeechKey(utterance.speechString, language: language))
    }

    private func normalizedSpeechKey(_ text: String, language: LanguageOption) -> String {
        let foldedText = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: language.locale)
        let allowedCharacters = CharacterSet.letters
            .union(.decimalDigits)
            .union(.whitespacesAndNewlines)
        let filteredText = String(foldedText.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : " "
        })

        return filteredText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class SystemOutputDucker: @unchecked Sendable {
    private let duckingFactor: Float32 = 0.28
    private let minimumDuckedVolume: Float32 = 0.08
    private var duckingDepth = 0
    private var originalVolume: Float32?
    private var duckedVolume: Float32?
    private var duckedDeviceID: AudioDeviceID?

    func beginDucking() {
        duckingDepth += 1
        guard duckingDepth == 1 else { return }
        guard let deviceID = defaultOutputDeviceID(),
              isVolumeSettable(deviceID),
              let currentVolume = readVolume(deviceID)
        else {
            return
        }

        let targetVolume = min(currentVolume, max(minimumDuckedVolume, currentVolume * duckingFactor))
        guard targetVolume < currentVolume else { return }

        if setVolume(targetVolume, deviceID: deviceID) {
            originalVolume = currentVolume
            duckedVolume = targetVolume
            duckedDeviceID = deviceID
        }
    }

    func endDucking() {
        guard duckingDepth > 0 else { return }

        duckingDepth -= 1
        guard duckingDepth == 0 else { return }

        restoreVolumeIfNeeded()
    }

    func cancelDucking() {
        duckingDepth = 0
        restoreVolumeIfNeeded()
    }

    private func restoreVolumeIfNeeded() {
        guard let deviceID = duckedDeviceID,
              let originalVolume
        else {
            clearDuckingState()
            return
        }

        if shouldRestoreVolume(deviceID: deviceID) {
            _ = setVolume(originalVolume, deviceID: deviceID)
        }

        clearDuckingState()
    }

    private func shouldRestoreVolume(deviceID: AudioDeviceID) -> Bool {
        guard let duckedVolume,
              let currentVolume = readVolume(deviceID)
        else {
            return true
        }

        return abs(currentVolume - duckedVolume) <= 0.08
    }

    private func clearDuckingState() {
        originalVolume = nil
        duckedVolume = nil
        duckedDeviceID = nil
    }

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else {
            return nil
        }

        return deviceID
    }

    private func isVolumeSettable(_ deviceID: AudioDeviceID) -> Bool {
        var address = volumeAddress()
        guard AudioObjectHasProperty(deviceID, &address) else {
            return false
        }

        var isSettable = DarwinBoolean(false)
        let status = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
        return status == noErr && isSettable.boolValue
    }

    private func readVolume(_ deviceID: AudioDeviceID) -> Float32? {
        var address = volumeAddress()
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &volume
        )

        guard status == noErr else {
            return nil
        }

        return min(max(volume, 0), 1)
    }

    private func setVolume(_ volume: Float32, deviceID: AudioDeviceID) -> Bool {
        var address = volumeAddress()
        var clampedVolume = min(max(volume, 0), 1)
        let size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            size,
            &clampedVolume
        )

        return status == noErr
    }

    private func volumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
