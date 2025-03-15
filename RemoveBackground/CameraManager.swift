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
    
    // 最後に撮影した画像を更新するメソッド
    func updateLastCapturedImage(with newImage: UIImage) {
        print("画像更新開始: 新しい画像サイズ \(newImage.size)")
        print("更新前の状態: savedImages.count = \(savedImages.count)")
        if !savedImages.isEmpty, let lastImage = savedImages.last {
            print("更新前の最後の画像サイズ: \(lastImage.size)")
        }
        
        DispatchQueue.main.async {
            // 最後に撮影した画像を更新
            self.capturedImage = newImage
            
            // 問題解決のため、最後の画像を置き換える代わりに新しい画像を追加する
            print("背景削除処理済み画像に更新します: サイズ \(newImage.size)")
            
            // 配列内の最後の画像を置き換える
            if !self.savedImages.isEmpty {
                // 新しい配列を作成
                var updatedImages = [UIImage]()
                
                // 最後の画像以外をコピー
                for i in 0..<self.savedImages.count-1 {
                    updatedImages.append(self.savedImages[i])
                }
                
                // 処理済みの新しい画像を追加
                updatedImages.append(newImage)
                
                print("画像配列を更新: 元の長さ=\(self.savedImages.count), 新しい長さ=\(updatedImages.count)")
                
                // 配列を更新
                self.savedImages = updatedImages
                
                // 更新後の確認
                if let finalImage = self.savedImages.last {
                    print("更新後の最後の画像サイズ: \(finalImage.size)")
                }
            } else {
                print("画像配列が空のため、新しい画像を追加します")
                self.savedImages = [newImage]
            }
            
            // 明示的に変更を通知
            self.objectWillChange.send()
            print("画像更新完了: 現在の保存画像数 \(self.savedImages.count)")
            
            // 少し遅延させて再度通知（UI更新を確実にするため）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // 遅延前の状態を確認
                print("遅延通知前の状態: savedImages.count = \(self.savedImages.count)")
                if let delayedImage = self.savedImages.last {
                    print("遅延通知前の最後の画像サイズ: \(delayedImage.size)")
                }
                
                // 再度変更を通知
                self.objectWillChange.send()
                print("遅延通知完了: 現在の保存画像数 \(self.savedImages.count)")
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
                    print("写真撮影成功: サイズ \(capturedImage.size)")
                    
                    // 先にcapturedImageを設定
                    self.capturedImage = capturedImage
                    
                    // 次に配列に追加（新しい配列を作成して代入）
                    let newImages = self.savedImages + [capturedImage]
                    print("画像を配列に追加: 追加前=\(self.savedImages.count)枚, 追加後=\(newImages.count)枚")
                    
                    // 配列全体を置き換えて変更を確実に通知
                    self.savedImages = newImages
                    
                    // 撮影成功のフィードバックを表示（フラッシュ効果）
                    self.isTaken = true
                    
                    // 明示的に変更を通知
                    self.objectWillChange.send()
                    
                    // 少し遅延させて再度通知
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        // 保存状態を確認
                        print("保存状態確認: savedImages.count = \(self.savedImages.count)")
                        if let lastImage = self.savedImages.last {
                            print("保存された最後の画像サイズ: \(lastImage.size)")
                        }
                        
                        self.objectWillChange.send()
                        
                        // 0.1秒後にフラッシュ効果を消す
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.isTaken = false
                            // capturedImageはnilにしない（背景削除処理で使用するため）
                            
                            // 再度変更を通知
                            self.objectWillChange.send()
                        }
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