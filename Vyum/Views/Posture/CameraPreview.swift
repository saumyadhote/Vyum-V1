import AVFoundation
import SwiftUI
import UIKit

/// Live camera feed, filling its frame.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer?.session = session
        view.previewLayer?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
    }
}

/// A captured photo, decoded once at screen size rather than on every redraw.
struct CapturedPhoto: View {
    let data: Data
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.vyumSurface
            }
        }
        .task(id: data) {
            image = await UIImage(data: data)?.byPreparingThumbnail(ofSize: CGSize(width: 1200, height: 1600))
        }
    }
}
