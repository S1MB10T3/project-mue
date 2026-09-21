import AVFoundation
import SwiftUI
import UIKit

/// The live camera feed, filling its frame the same way the photo does.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

/// A view backed directly by `AVCaptureVideoPreviewLayer`, so the layer
/// resizes with the view instead of needing manual frame bookkeeping.
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // Safe by construction: `layerClass` above guarantees the type.
        layer as! AVCaptureVideoPreviewLayer
    }
}
