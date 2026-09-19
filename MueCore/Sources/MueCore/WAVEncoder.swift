import Foundation

/// Writes 16-bit little-endian PCM WAV files.
public enum WAVEncoder {
    /// Encode mono `RenderedAudio`.
    public static func encode(_ audio: RenderedAudio) -> Data {
        encode(channels: [audio.samples], sampleRate: audio.sampleRate)
    }

    /// Encode one or more equal-length channels, interleaved. Samples outside
    /// −1…1 are clipped.
    public static func encode(channels: [[Float]], sampleRate: Double) -> Data {
        precondition(!channels.isEmpty, "WAVEncoder needs at least one channel")
        let frames = channels[0].count
        precondition(channels.allSatisfy { $0.count == frames }, "all channels must have the same length")

        let channelCount = channels.count
        let bytesPerSample = 2
        let blockAlign = channelCount * bytesPerSample
        let dataSize = frames * blockAlign
        let rate = UInt32(sampleRate.rounded())

        var data = Data(capacity: 44 + dataSize)
        func append<T: FixedWidthInteger>(_ value: T) {
            var le = value.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func append(_ tag: String) {
            data.append(contentsOf: Array(tag.utf8))
        }

        append("RIFF")
        append(UInt32(36 + dataSize))
        append("WAVE")
        append("fmt ")
        append(UInt32(16))                 // fmt chunk size
        append(UInt16(1))                  // PCM
        append(UInt16(channelCount))
        append(rate)
        append(rate * UInt32(blockAlign))  // byte rate
        append(UInt16(blockAlign))
        append(UInt16(bytesPerSample * 8))
        append("data")
        append(UInt32(dataSize))

        for frame in 0..<frames {
            for channel in channels {
                let s = min(1, max(-1, channel[frame]))
                let v = s < 0 ? s * 32768 : s * 32767
                append(Int16(v))
            }
        }
        return data
    }
}
