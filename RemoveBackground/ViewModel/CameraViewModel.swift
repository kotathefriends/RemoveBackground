import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import Combine

class CameraViewModel: ObservableObject {
    // カメラマネージャー
    @Published var cameraManager = CameraManager()
    
    // UI状態
    @Published var selectedImageData: ImageData?
    @Published var isImageViewerPresented = false
    @Published var isAutoRemoveBackground = false
    
    // 初期化
    init() {
        // カメラマネージャーの写真撮影通知を監視
        setupSubscriptions()
    }
    
    // 通知の購読設定
    private func setupSubscriptions() {
        // カメラマネージャーの変更を監視
        cameraManager.objectWillChange.sink { [weak self] _ in
            // 新しい写真が撮影されたかチェック
            if let lastImage = self?.cameraManager.savedImages.last,
               lastImage.processedImage == nil,
               self?.isAutoRemoveBackground == true {
                // 少し遅延させて背景削除処理を実行（UIの更新を待つため）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.processLastImage()
                    
                    // 処理後に明示的にUI更新を通知
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.objectWillChange.send()
                    }
                }
            }
            
            // 明示的にUI更新を通知
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }.store(in: &cancellables)
    }
    
    // 購読解除用
    private var cancellables = Set<AnyCancellable>()
    
    // カメラセッション開始
    func startCameraSession() {
        cameraManager.checkPermission()
    }
    
    // カメラセッション停止
    func stopCameraSession() {
        cameraManager.stopSession()
    }
    
    // 写真撮影処理
    func takePicture() {
        cameraManager.takePicture()
    }
    
    // 最後に撮影した画像を処理
    private func processLastImage() {
        guard let lastImage = cameraManager.savedImages.last else {
            print("処理する画像がありません")
            return
        }
        
        print("背景削除処理開始: 画像サイズ \(lastImage.originalImage.size)")
        
        // 背景削除処理を実行
        if let processedImage = processImageWithBackgroundRemoval(lastImage.originalImage) {
            // 処理済み画像を設定
            cameraManager.updateLastCapturedImage(with: processedImage)
        }
    }
    
    // サムネイル画像タップ処理
    func onTapImage(imageData: ImageData) {
        print("画像タップ: \(imageData.originalImage.size)")
        self.selectedImageData = imageData
        self.isImageViewerPresented = true
    }
    
    // 背景削除処理を行う関数
    func processImageWithBackgroundRemoval(_ image: UIImage) -> UIImage? {
        // 画像サイズが大きすぎる場合はリサイズ
        let maxDimension: CGFloat = 2048.0
        var processedImage = image
        
        if image.size.width > maxDimension || image.size.height > maxDimension {
            print("画像リサイズ: 元のサイズ \(image.size)")
            processedImage = resizeImage(image, targetSize: CGSize(width: maxDimension, height: maxDimension))
            print("リサイズ後: \(processedImage.size)")
        }
        
        // 背景削除処理
        let result = removeBackground(from: processedImage)
        
        if let resultImage = result {
            print("背景削除成功: サイズ \(resultImage.size)")
            return resultImage
        } else {
            print("背景削除失敗")
            return nil
        }
    }
    
    // 背景削除処理
    private func removeBackground(from image: UIImage) -> UIImage? {
        return BackgroundRemoval.removeBackground(from: image)
    }
    
    // 画像をリサイズする関数
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // アスペクト比を維持するために、小さい方の比率を使用
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
} 