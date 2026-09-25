import CoreTransferable
import MueCore
import UniformTypeIdentifiers

/// The EQ'd mix as a .wav file, encoded only when the share sheet asks for
/// it. Effects (reverb, delay) are live-only for now and are not baked in.
struct WAVExport: Transferable, Sendable {
    let stems: [RenderedAudio]
    let gains: [Float]
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .wav) { export in
            WAVEncoder.encode(RenderedAudio.mix(export.stems, gains: export.gains))
        }
        .suggestedFileName { $0.fileName }
    }
}
