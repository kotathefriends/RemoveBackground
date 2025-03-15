import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        DispatchQueue.main.async {
            cameraManager.preview = AVCaptureVideoPreviewLayer(session: cameraManager.session)
            cameraManager.preview.frame = view.frame
            
            // アスペクト比を設定
            cameraManager.preview.videoGravity = .resizeAspect
            
            view.layer.addSublayer(cameraManager.preview)
            
            // セッションが既に設定されていれば開始
            if !cameraManager.session.inputs.isEmpty {
                cameraManager.startSession()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // フレームサイズが変わった場合に更新
        if let previewLayer = cameraManager.preview {
            previewLayer.frame = uiView.frame
        }
    }
} 