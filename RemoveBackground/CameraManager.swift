import Foundation
import AVFoundation
import UIKit

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published var isTaken = false
    @Published var capturedImage: UIImage?
    @Published var isError = false
    @Published var errorMessage = ""
    
    // 撮影した写真を保存する配列
    @Published var savedImages: [UIImage] = []
    
    // カメラセットアップ完了フラグ
    private var isSetup = false
    
    override init() {
        super.init()
        checkPermission()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // メインスレッドでの初期化を避ける
            DispatchQueue.global(qos: .userInitiated).async {
                self.setupCamera()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status {
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.setupCamera()
                    }
                } else {
                    self.handleError(message: "カメラへのアクセスが許可されていません")
                }
            }
        case .denied, .restricted:
            handleError(message: "カメラへのアクセスが許可されていません。設定アプリから許可してください。")
        @unknown default:
            handleError(message: "カメラの権限状態が不明です")
        }
    }
    
    private func handleError(message: String) {
        DispatchQueue.main.async {
            self.isError = true
            self.errorMessage = message
            print("カメラエラー: \(message)")
        }
    }
    
    func setupCamera() {
        guard !isSetup else { return }
        
        do {
            session.beginConfiguration()
            
            // 解像度の設定（高品質）
            if session.canSetSessionPreset(.photo) {
                session.sessionPreset = .photo
            }
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                handleError(message: "カメラデバイスが見つかりません")
                return
            }
            
            // カメラの設定
            try device.lockForConfiguration()
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            device.unlockForConfiguration()
            
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                handleError(message: "カメラ入力を追加できません")
                return
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
                
                // ビデオ安定化の設定
                if let connection = output.connection(with: .video) {
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                }
                
                // 写真出力の設定
                output.isHighResolutionCaptureEnabled = true
                output.maxPhotoQualityPrioritization = .quality
            } else {
                handleError(message: "カメラ出力を追加できません")
                return
            }
            
            session.commitConfiguration()
            isSetup = true
            
            print("カメラセットアップ完了")
            startSession()
        } catch {
            handleError(message: "カメラのセットアップに失敗しました: \(error.localizedDescription)")
        }
    }
    
    func takePicture() {
        guard session.isRunning else {
            handleError(message: "カメラセッションが実行されていません")
            return
        }
        
        // 写真設定
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        // 高解像度設定を無効化して処理を高速化
        settings.isHighResolutionPhotoEnabled = false
        
        // 写真撮影
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func retake() {
        DispatchQueue.main.async {
            self.isTaken = false
            self.capturedImage = nil
        }
    }
    
    func saveCurrentImage() {
        if let image = capturedImage {
            DispatchQueue.main.async {
                self.savedImages.append(image)
                self.retake()
            }
        }
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.startRunning()
                print("カメラセッション開始")
            }
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
                print("カメラセッション停止")
            }
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            handleError(message: "写真の撮影に失敗しました: \(error.localizedDescription)")
            return
        }
        
        if let imageData = photo.fileDataRepresentation() {
            let image = UIImage(data: imageData)
            
            DispatchQueue.main.async {
                // 撮影した写真を保存
                if let capturedImage = image {
                    self.savedImages.append(capturedImage)
                    
                    // 撮影成功のフィードバックを表示（フラッシュ効果）
                    self.capturedImage = capturedImage
                    self.isTaken = true
                    
                    // 0.1秒後にカメラビューに戻る（待機時間を最小化）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isTaken = false
                        self.capturedImage = nil
                    }
                } else {
                    self.handleError(message: "画像の処理に失敗しました")
                }
            }
        } else {
            handleError(message: "画像データの取得に失敗しました")
        }
    }
} 