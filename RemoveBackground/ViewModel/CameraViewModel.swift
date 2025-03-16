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
    
    // 最後に撮影した写真のID
    private var lastCapturedImageID: UUID?
    // 背景削除が必要な写真のIDを保存
    private var needsBackgroundRemovalIDs: Set<UUID> = []
    
    // 初期化
    init() {
        // カメラマネージャーの写真撮影通知を監視
        setupSubscriptions()
    }
    
    // 通知の購読設定
    private func setupSubscriptions() {
        // カメラマネージャーの変更を監視
        cameraManager.objectWillChange.sink { [weak self] _ in
            guard let self = self else { return }
            
            // 新しい写真が撮影されたかチェック
            if let lastImage = self.cameraManager.savedImages.last,
               self.lastCapturedImageID != lastImage.id {
                
                // 最後に撮影した写真のIDを更新
                self.lastCapturedImageID = lastImage.id
                
                // 背景自動削除がオンの場合、この写真に背景削除が必要とマーク
                if self.isAutoRemoveBackground {
                    self.needsBackgroundRemovalIDs.insert(lastImage.id)
                    
                    // 少し遅延させて背景削除処理を実行（UIの更新を待つため）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.processMarkedImages()
                        
                        // 処理後に明示的にUI更新を通知
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.objectWillChange.send()
                        }
                    }
                }
            }
            
            // 明示的にUI更新を通知
            DispatchQueue.main.async {
                self.objectWillChange.send()
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
    
    // 背景削除が必要とマークされた画像を処理
    private func processMarkedImages() {
        // 処理が必要な画像がない場合は終了
        if needsBackgroundRemovalIDs.isEmpty {
            return
        }
        
        // 処理が必要な画像を探して処理
        for imageID in needsBackgroundRemovalIDs {
            if let index = cameraManager.savedImages.firstIndex(where: { $0.id == imageID }),
               cameraManager.savedImages[index].processedImage == nil {
                
                let imageData = cameraManager.savedImages[index]
                print("背景削除処理開始: ID \(imageData.id), 画像サイズ \(imageData.originalImage.size)")
                
                // 背景削除処理を実行
                if let processedImage = processImageWithBackgroundRemoval(imageData.originalImage) {
                    // 処理済み画像を設定
                    let updatedImageData = ImageData(
                        originalImage: imageData.originalImage,
                        processedImage: processedImage
                    )
                    
                    // 配列内の画像を更新
                    cameraManager.savedImages[index] = updatedImageData
                    
                    // 処理済みのIDを削除
                    needsBackgroundRemovalIDs.remove(imageID)
                }
            }
        }
        
        // UI更新を通知
        objectWillChange.send()
    }
    
    // サムネイル画像タップ処理
    func onTapImage(imageData: ImageData) {
        print("画像タップ: \(imageData.originalImage.size)")
        self.selectedImageData = imageData
        self.isImageViewerPresented = true
    }
    
    // 画像削除処理
    func deleteImage(_ imageData: ImageData) {
        // 配列から該当する画像を削除
        if let index = cameraManager.savedImages.firstIndex(where: { $0.id == imageData.id }) {
            cameraManager.savedImages.remove(at: index)
            print("画像削除: ID \(imageData.id)")
            
            // 処理待ちリストからも削除
            needsBackgroundRemovalIDs.remove(imageData.id)
            
            // UI更新を通知
            objectWillChange.send()
        }
    }
    
    // ライブラリから写真を追加
    func addImageFromLibrary(_ image: UIImage) {
        print("ライブラリから写真を追加: サイズ \(image.size)")
        
        // 画像を3:4の比率に調整
        let adjustedImage = adjustImageToAspectRatio(image, targetRatio: 3.0/4.0)
        print("調整後のサイズ: \(adjustedImage.size)")
        
        // 新しいImageDataを作成
        let newImageData = ImageData(originalImage: adjustedImage)
        
        // 配列に追加
        cameraManager.savedImages.append(newImageData)
        
        // 背景自動削除がオンの場合、この写真に背景削除が必要とマーク
        if isAutoRemoveBackground {
            needsBackgroundRemovalIDs.insert(newImageData.id)
            
            // 少し遅延させて背景削除処理を実行（UIの更新を待つため）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.processMarkedImages()
                
                // 処理後に明示的にUI更新を通知
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.objectWillChange.send()
                }
            }
        }
        
        // UI更新を通知
        objectWillChange.send()
    }
    
    // 画像を指定のアスペクト比に調整する関数
    private func adjustImageToAspectRatio(_ image: UIImage, targetRatio: CGFloat) -> UIImage {
        let imageRatio = image.size.width / image.size.height
        
        // 現在の比率が目標の比率と異なる場合のみ調整
        if abs(imageRatio - targetRatio) > 0.01 {
            var newSize: CGSize
            
            if imageRatio > targetRatio {
                // 画像が横長すぎる場合、幅を調整
                newSize = CGSize(width: image.size.height * targetRatio, height: image.size.height)
            } else {
                // 画像が縦長すぎる場合、高さを調整
                newSize = CGSize(width: image.size.width, height: image.size.width / targetRatio)
            }
            
            // 画像の中央部分を切り抜く
            let x = (image.size.width - newSize.width) / 2
            let y = (image.size.height - newSize.height) / 2
            let cropRect = CGRect(x: x, y: y, width: newSize.width, height: newSize.height)
            
            if let cgImage = image.cgImage?.cropping(to: cropRect) {
                return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            }
        }
        
        return image
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