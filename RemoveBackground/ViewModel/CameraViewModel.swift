import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import Combine

class CameraViewModel: ObservableObject {
    // カメラマネージャー
    @Published var cameraManager = CameraManager()
    
    // UI状態
    @Published var selectedImageData: ImageData? = nil
    @Published var isImageViewerPresented = false
    @Published var isAutoRemoveBackground = true // 背景自動削除フラグ
    
    // 初期化
    init() {
        // 必要な初期化処理があればここに追加
    }
    
    // カメラセッション開始
    func startCameraSession() {
        if !cameraManager.session.isRunning {
            cameraManager.startSession()
        }
    }
    
    // カメラセッション停止
    func stopCameraSession() {
        cameraManager.stopSession()
    }
    
    // 写真撮影処理
    func takePicture() {
        // 撮影前に変数を用意して、撮影後の処理を確実に実行できるようにする
        let shouldProcessImage = isAutoRemoveBackground
        
        // 撮影処理
        cameraManager.takePicture()
        
        // 背景自動削除が有効な場合、撮影後に処理を行う
        if shouldProcessImage {
            // 撮影後の処理を行うタイミングを調整
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                // capturedImageを使用して処理
                if let capturedImage = self.cameraManager.capturedImage {
                    print("撮影後の画像処理を開始: サイズ \(capturedImage.size)")
                    print("現在の保存画像数: \(self.cameraManager.savedImages.count)")
                    
                    // 最新の画像を処理
                    if self.cameraManager.savedImages.count > 0 {
                        // 最新の画像を取得
                        let lastImage = self.cameraManager.savedImages.last!
                        print("最新の保存画像を処理: サイズ \(lastImage.size)")
                        self.processImageWithBackgroundRemoval(lastImage)
                    } else {
                        // savedImagesが空の場合はcapturedImageを使用
                        print("savedImagesが空のため、capturedImageを使用")
                        self.processImageWithBackgroundRemoval(capturedImage)
                    }
                } else {
                    print("処理する画像が見つかりません: capturedImageがnil")
                }
            }
        }
    }
    
    // サムネイル画像タップ処理
    func onTapImage(image: UIImage, index: Int) {
        print("サムネイル写真がタップされました: インデックス \(index)")
        print("savedImages数: \(cameraManager.savedImages.count)")
        print("渡された画像のサイズ: \(image.size)")
        
        // インデックスが有効かチェック
        if index >= 0 && index < cameraManager.savedImages.count {
            DispatchQueue.main.async {
                self.selectedImageData = ImageData(id: UUID(), image: image, index: index)
                self.isImageViewerPresented = true
            }
        } else {
            print("無効なインデックス: \(index)")
        }
    }
    
    // 背景削除処理を行う関数
    func processImageWithBackgroundRemoval(_ image: UIImage) {
        print("背景自動削除処理を開始します: 元画像サイズ \(image.size)")
        print("処理開始時の保存画像数: \(cameraManager.savedImages.count)")
        if let lastImage = cameraManager.savedImages.last {
            print("処理開始時の最後の画像サイズ: \(lastImage.size)")
        }
        
        Task {
            let processedImage = await withCheckedContinuation({ continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    print("背景削除処理を実行中...")
                    
                    // 画像のサイズが大きすぎる場合はリサイズ
                    let maxDimension: CGFloat = 2048.0
                    var imageToProcess = image
                    
                    if image.size.width > maxDimension || image.size.height > maxDimension {
                        print("画像が大きすぎるためリサイズします: 元のサイズ \(image.size)")
                        imageToProcess = self.resizeImage(image, targetSize: CGSize(
                            width: min(image.size.width, maxDimension),
                            height: min(image.size.height, maxDimension)
                        ))
                        print("リサイズ後のサイズ: \(imageToProcess.size)")
                    }
                    
                    let result = removeBackground(from: imageToProcess)
                    print("背景削除処理完了: 結果 \(result != nil ? "成功" : "失敗")")
                    
                    if let result = result {
                        print("処理後画像サイズ: \(result.size)")
                        continuation.resume(returning: result)
                    } else {
                        // 背景削除に失敗した場合は元の画像を返す
                        print("背景削除に失敗したため、元の画像を使用します")
                        continuation.resume(returning: image)
                    }
                }
            })
            
            // 処理済み画像をカメラマネージャーに保存
            DispatchQueue.main.async {
                print("処理済み画像をカメラマネージャーに適用します")
                
                // 現在の保存画像数を記録
                let currentCount = self.cameraManager.savedImages.count
                print("更新前の保存画像数: \(currentCount)")
                
                // 現在の画像配列の状態を確認
                print("--- 更新前の画像配列の状態 ---")
                for (i, img) in self.cameraManager.savedImages.enumerated() {
                    print("インデックス \(i): サイズ \(img.size)")
                }
                print("------------------------------")
                
                // 画像を更新
                self.cameraManager.updateLastCapturedImage(with: processedImage)
                
                // 画面の更新を強制
                self.cameraManager.objectWillChange.send()
                self.objectWillChange.send()
                
                // 更新後の画像配列の状態を確認
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("--- 更新後の画像配列の状態 ---")
                    for (i, img) in self.cameraManager.savedImages.enumerated() {
                        print("インデックス \(i): サイズ \(img.size)")
                    }
                    print("------------------------------")
                    
                    // サムネイルが更新されたことを確認
                    if let lastImage = self.cameraManager.savedImages.last {
                        print("更新後のサムネイル画像サイズ: \(lastImage.size)")
                        print("更新後の保存画像数: \(self.cameraManager.savedImages.count)")
                    }
                    
                    // 再度更新を通知
                    self.cameraManager.objectWillChange.send()
                    self.objectWillChange.send()
                }
                
                // サムネイルギャラリーを強制的に更新
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("サムネイルギャラリー強制更新を実行")
                    self.cameraManager.objectWillChange.send()
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    // 画像をリサイズする関数
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // 縦横比を維持するために小さい方の比率を使用
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