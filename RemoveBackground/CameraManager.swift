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
    
    override init() {
        super.init()
        // メインスレッドでの初期化を避ける
        DispatchQueue.global(qos: .userInitiated).async {
            self.checkPermission()
        }
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status {
                    self.setupCamera()
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
        do {
            session.beginConfiguration()
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                handleError(message: "カメラデバイスが見つかりません")
                return
            }
            
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                handleError(message: "カメラ入力を追加できません")
                return
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            } else {
                handleError(message: "カメラ出力を追加できません")
                return
            }
            
            session.commitConfiguration()
        } catch {
            handleError(message: "カメラのセットアップに失敗しました: \(error.localizedDescription)")
        }
    }
    
    func takePicture() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            DispatchQueue.main.async {
                self.isTaken = true
            }
        }
    }
    
    func retake() {
        DispatchQueue.main.async {
            self.isTaken = false
            self.capturedImage = nil
        }
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
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
            DispatchQueue.main.async {
                self.capturedImage = UIImage(data: imageData)
                if self.capturedImage == nil {
                    self.handleError(message: "画像の処理に失敗しました")
                }
            }
        } else {
            handleError(message: "画像データの取得に失敗しました")
        }
    }
} 