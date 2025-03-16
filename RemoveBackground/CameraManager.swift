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
    
    // 撮影した写真を保存する配列（ImageDataモデルを使用）
    @Published var savedImages: [ImageData] = []
    
    // カメラセットアップ完了フラグ
    private var isSetup = false
    
    // カメラ設定
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
            
            // デバイス設定
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                handleError(message: "カメラデバイスが見つかりません")
                return
            }
            
            // 入力設定
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // 出力設定
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            // 写真出力の設定
            if let photoConnection = output.connection(with: .video) {
                if photoConnection.isVideoOrientationSupported {
                    photoConnection.videoOrientation = .portrait
                }
            }
            
            // 3:4のアスペクト比に設定
            session.sessionPreset = .photo
            
            session.commitConfiguration()
            
            // セッション開始（プレビューレイヤーの設定前に開始）
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
                
                // フラッシュ効果を一時的に表示
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
    
    // 写真撮影完了時の処理
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
                
                // 画像を保存
                let newImageData = ImageData(originalImage: image)
                self.savedImages.append(newImageData)
                
                // 画面更新を通知
                self.objectWillChange.send()
                
                // 少し遅延させて再度通知（UI更新を確実にするため）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.objectWillChange.send()
                    print("保存された画像数: \(self.savedImages.count)")
                }
            }
        }
    }
} 