import AVFoundation
import CoreGraphics
import ScreenCaptureKit

protocol SystemAudioCaptureDelegate: AnyObject {
    func systemAudioCapture(_ capture: SystemAudioCapture, didOutput sampleBuffer: CMSampleBuffer)
    func systemAudioCapture(_ capture: SystemAudioCapture, didReceiveAudioSampleCount count: Int, level: Float?)
}

final class SystemAudioCapture: NSObject, @unchecked Sendable {
    private static let audioLevelReportInterval = 8

    weak var delegate: SystemAudioCaptureDelegate?

    private var stream: SCStream?
    private var audioSampleCount = 0
    private let sampleQueue = DispatchQueue(label: "QuickLate.SystemAudioCapture.sampleQueue")

    @MainActor
    func requestScreenRecordingAccess() throws {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw CaptureError.screenRecordingNotGranted
        }
    }

    @MainActor
    func start(sampleRate: Int = 16_000) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = sampleRate
        configuration.channelCount = 1

        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        audioSampleCount = 0
        self.stream = stream
    }

    func stop() async {
        guard let stream else { return }
        try? stream.removeStreamOutput(self, type: .screen)
        try? stream.removeStreamOutput(self, type: .audio)
        try? await stream.stopCapture()
        self.stream = nil
    }
}

extension SystemAudioCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        audioSampleCount += 1
        delegate?.systemAudioCapture(self, didOutput: sampleBuffer)
        if audioSampleCount == 1 || audioSampleCount % Self.audioLevelReportInterval == 0 {
            delegate?.systemAudioCapture(
                self,
                didReceiveAudioSampleCount: audioSampleCount,
                level: audioLevel(from: sampleBuffer)
            )
        }
    }

    private func audioLevel(from sampleBuffer: CMSampleBuffer) -> Float? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        else {
            return nil
        }

        var listSize = 0
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &listSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: nil
        )

        guard listSize > 0 else { return nil }

        let rawList = UnsafeMutableRawPointer.allocate(
            byteCount: listSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawList.deallocate() }

        let audioBufferList = rawList.bindMemory(to: AudioBufferList.self, capacity: 1)
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList,
            bufferListSize: listSize,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else { return nil }

        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let isFloat = streamDescription.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0
        var squareSum: Double = 0
        var sampleCount = 0

        for buffer in buffers {
            guard let data = buffer.mData else { continue }

            if isFloat {
                let samples = data.bindMemory(to: Float.self, capacity: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size)
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                for index in 0..<count {
                    let sample = Double(samples[index])
                    squareSum += sample * sample
                }
                sampleCount += count
            } else {
                let samples = data.bindMemory(to: Int16.self, capacity: Int(buffer.mDataByteSize) / MemoryLayout<Int16>.size)
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Int16>.size
                for index in 0..<count {
                    let sample = Double(samples[index]) / Double(Int16.max)
                    squareSum += sample * sample
                }
                sampleCount += count
            }
        }

        guard sampleCount > 0 else { return nil }
        let rms = sqrt(squareSum / Double(sampleCount))
        let decibels = 20 * log10(max(rms, 0.000_001))
        return Float(decibels)
    }
}

enum CaptureError: LocalizedError {
    case screenRecordingNotGranted
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .screenRecordingNotGranted:
            AppText.screenRecordingNotGranted
        case .noDisplay:
            AppText.noActiveDisplay
        }
    }
}
