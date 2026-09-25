import Foundation

/// How rows map onto frequencies.
public enum FrequencyScale: String, Codable, CaseIterable, Sendable {
    /// Evenly spaced in Hz. Matches what most spectrogram apps display.
    case linear
    /// Evenly spaced in octaves. Sounds more musical, looks stretched on a
    /// linear spectrogram.
    case logarithmic
}

/// The user-facing parameters of an encoding. Plain data; validation is the
/// caller's job (see `clamped()`).
public struct EncodingSettings: Codable, Equatable, Hashable, Sendable {
    /// Length of the sound in seconds.
    public var duration: Double
    /// Number of image rows, i.e. number of oscillators.
    public var bands: Int
    /// Frequency of the bottom row, Hz.
    public var minFrequency: Double
    /// Frequency of the top row, Hz.
    public var maxFrequency: Double
    public var scale: FrequencyScale
    /// Horizontal resolution: image columns per second of audio.
    public var columnsPerSecond: Double
    /// Contrast curve applied to brightness. > 1 darkens midtones.
    public var gamma: Double
    /// Brightness (0…1) below which a pixel is silent.
    public var floor: Double
    /// When true, dark pixels are loud (for black-on-white drawings).
    public var invert: Bool
    /// Musical quantisation of row frequencies.
    public var tuning: Tuning
    /// Timbre of every row's oscillator.
    public var waveform: Waveform

    public init(
        duration: Double = 6,
        bands: Int = 128,
        minFrequency: Double = 400,
        maxFrequency: Double = 8000,
        scale: FrequencyScale = .linear,
        columnsPerSecond: Double = 40,
        gamma: Double = 1.6,
        floor: Double = 0.05,
        invert: Bool = false,
        tuning: Tuning = .free,
        waveform: Waveform = .sine
    ) {
        self.duration = duration
        self.bands = bands
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.scale = scale
        self.columnsPerSecond = columnsPerSecond
        self.gamma = gamma
        self.floor = floor
        self.invert = invert
        self.tuning = tuning
        self.waveform = waveform
    }

    /// Number of time columns the image is resampled to.
    public var columns: Int {
        max(2, Int((duration * columnsPerSecond).rounded()))
    }

    /// A copy with every field forced into a sane range.
    public func clamped() -> EncodingSettings {
        var s = self
        s.duration = min(60, max(0.5, s.duration))
        s.bands = min(1024, max(8, s.bands))
        s.minFrequency = min(20_000, max(20, s.minFrequency))
        s.maxFrequency = min(20_000, max(20, s.maxFrequency))
        if s.maxFrequency <= s.minFrequency { s.maxFrequency = s.minFrequency + 100 }
        s.columnsPerSecond = min(200, max(4, s.columnsPerSecond))
        s.gamma = min(8, max(0.1, s.gamma))
        s.floor = min(1, max(0, s.floor))
        return s
    }
}
