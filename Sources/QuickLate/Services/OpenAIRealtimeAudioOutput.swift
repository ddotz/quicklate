import AVFAudio
import Foundation

final class OpenAIRealtimeAudioOutput: @unchecked Sendable {
    private let queue = DispatchQueue(label: "QuickLate.OpenAIRealtimeAudioOutput")
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let translatedVoiceGain: Float = 1.6
    private var format: AVAudioFormat?
    private var isConfigured = false

    func playPCM16Base64(_ audio: String, sampleRate: Double) {
        guard let data = Data(base64Encoded: audio), !data.isEmpty else { return }

        queue.async { [weak self] in
            self?.playPCM16Data(data, sampleRate: sampleRate)
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            player.stop()
            engine.stop()
        }
    }

    private func playPCM16Data(_ data: Data, sampleRate: Double) {
        let sampleCount = data.count / MemoryLayout<Int16>.size
        guard sampleCount > 0,
              let format = configuredFormat(sampleRate: sampleRate),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(sampleCount)
              ),
              let channel = buffer.floatChannelData?.pointee
        else {
            return
        }

        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            let samples = baseAddress.assumingMemoryBound(to: Int16.self)
            for index in 0..<sampleCount {
                let sample = Int16(littleEndian: samples[index])
                let normalizedSample = Float(sample) / Float(Int16.max)
                channel[index] = min(1, max(-1, normalizedSample * translatedVoiceGain))
            }
        }
        buffer.frameLength = AVAudioFrameCount(sampleCount)

        do {
            if !engine.isRunning {
                try engine.start()
            }
            player.scheduleBuffer(buffer, completionHandler: nil)
            if !player.isPlaying {
                player.play()
            }
        } catch {
            engine.stop()
        }
    }

    private func configuredFormat(sampleRate: Double) -> AVAudioFormat? {
        if let format, format.sampleRate == sampleRate {
            return format
        }

        if isConfigured {
            player.stop()
            engine.stop()
            engine.disconnectNodeOutput(player)
        } else {
            engine.attach(player)
            isConfigured = true
        }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            return nil
        }

        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.volume = 1
        engine.mainMixerNode.outputVolume = 1
        engine.prepare()
        self.format = format
        return format
    }
}
