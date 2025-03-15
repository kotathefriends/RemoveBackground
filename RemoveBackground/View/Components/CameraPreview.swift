import SwiftUI
import AVFoundation

// カメラプレビュー表示用のUIViewRepresentable
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        // プレビューレイヤーをローカル変数として作成
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        previewLayer.frame = view.frame
        
        // プレビューレイヤーの設定
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // ビューの作成後にcameraManagerのプレビューを設定
        DispatchQueue.main.async {
            self.cameraManager.preview = previewLayer
        }
        
        // セッションが開始されていない場合は開始
        if !cameraManager.session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                cameraManager.session.startRunning()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // フレームサイズが変更された場合にプレビューレイヤーのサイズを更新
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
} 