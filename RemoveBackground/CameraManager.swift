import Foundation
import AVFoundation
import UIKit
import SwiftUI
import Photos

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer?
    @Published var isTaken = false
    @Published var capturedImage: UIImage?
    @Published var isError = false
    @Published var errorMessage = ""
    
    @Published var savedImages: [ImageData] = []
    
    private var isSetup = false
    private var photoData: Data?
    
    override init() {
        super.init()
        checkPermission()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("カメラアクセス許可済み")
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.handleError(message: "カメラへのアクセスが拒否されました")
                    }
                }
            }
        case .denied, .restricted:
            handleError(message: "カメラへのアクセスが拒否されています。設定アプリから許可してください。")
        @unknown default:
            handleError(message: "不明なエラーが発生しました")
        }
    }
    
    private func handleError(message: String) {
        DispatchQueue.main.async {
            self.isError = true
            self.errorMessage = message
            print("エラー: \(message)")
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
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            if let photoConnection = output.connection(with: .video) {
                if photoConnection.isVideoOrientationSupported {
                    photoConnection.videoOrientation = .portrait
                }
            }
            
            session.sessionPreset = .photo
            
            session.commitConfiguration()
            
            startSession()
            
            print("カメラセットアップ完了")
            isSetup = true
        } catch {
            handleError(message: "カメラのセットアップに失敗しました: \(error.localizedDescription)")
        }
    }
    
    func takePicture() {
        DispatchQueue.global(qos: .background).async {
            let settings = AVCapturePhotoSettings()
            self.output.capturePhoto(with: settings, delegate: self)
            
            DispatchQueue.main.async {
                withAnimation {
                    self.isTaken = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        self.isTaken = false
                    }
                }
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
        DispatchQueue.global(qos: .background).async {
            if !self.session.isRunning {
                print("カメラセッション開始")
                self.session.startRunning()
            } else {
                print("カメラセッションは既に実行中です")
            }
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .background).async {
            if self.session.isRunning {
                print("カメラセッション停止")
                self.session.stopRunning()
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("写真撮影エラー: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("画像データの取得に失敗しました")
            return
        }
        
        self.photoData = imageData
        
        if let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.capturedImage = image
                print("写真撮影成功: サイズ \(image.size)")
                
                let newImageData = ImageData(originalImage: image)
                self.savedImages.append(newImageData)
                
                self.objectWillChange.send()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.objectWillChange.send()
                    print("保存された画像数: \(self.savedImages.count)")
                }
            }
        }
    }
} 