import Foundation

public enum RealtimeLatencyPolicy {
    public static let largeTranscriptPresentationIntervalSeconds: TimeInterval = 0.16
    public static let largeTranscriptTranslationDebounceMilliseconds = 260
    public static let veryLargeTranscriptTranslationDebounceMilliseconds = 650
    public static let defaultTranslationDebounceMilliseconds = 20
    public static let initialTranslationBurstDebounceMilliseconds = 35
    public static let maximumTranslationBurstHoldSeconds: TimeInterval = 0.25
    public static let floatingCaptionEarlyRevisionWindowSeconds: TimeInterval = 0.30
    public static let minimumFloatingCaptionDwellSeconds: TimeInterval = 0.75
    public static let maximumFloatingCaptionDwellSeconds: TimeInterval = 2.2
    public static let floatingCaptionBaseDwellSeconds: TimeInterval = 0.65
    public static let floatingCaptionCharactersPerSecond: Double = 48
}
