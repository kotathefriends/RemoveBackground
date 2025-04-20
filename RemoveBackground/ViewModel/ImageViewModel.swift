import SwiftUI
import Combine

/// 画像データを管理するViewModel
class ImageViewModel: ObservableObject {
    @ObservedObject var imageData: ImageData
    @Published var isProcessing = false
    // @Published var showOriginal = false // selectedImageIndex で代替

    /// UI バインディング用
    @Published var selectedImageIndex: Int {
        didSet {                 // ← ビューで値が変わったら…
            imageData.selectedImageIndex = selectedImageIndex   // ← 写真側にも保存
        }
    }
    
    /// 初期化
    /// - Parameter imageData: 画像データ
    init(imageData: ImageData) {
        self.imageData = imageData
        self.selectedImageIndex = imageData.selectedImageIndex  // ← 前回値を復元
        // 注意: ここで永続化されたインデックスを読み込む処理を追加することも可能
    }
    
    /// 処理済み画像を更新
    /// - Parameters:
    ///   - image: 処理済み画像
    ///   - mask: シルエットマスク画像
    func updateProcessedImage(_ image: UIImage, mask: CGImage? = nil) {
        imageData.processedImage = image
        imageData.maskCGImage = mask
        // selectedImageIndex は変更しない（ユーザーが最後に見ていたタブを維持）
        // objectWillChange.send() は @ObservedObject が自動的に処理するため不要な場合が多い
    }
    
    // toggleImageDisplay() は不要になったため削除可能
    
    /// 画像を必ず「ピクセルもメタデータも.up」に揃える
    func normalizedUpImage(from src: UIImage) -> UIImage {
        // すでに問題ない
        guard src.imageOrientation != .up else { return src }
        
        // 回転方向に応じてキャンバスサイズを決定
        let canvasSize: CGSize
        switch src.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            canvasSize = CGSize(width: src.size.height, height: src.size.width)
        default:
            canvasSize = src.size
        }
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        
        return renderer.image { ctx in
            // 座標系を回転・平行移動してから描画
            switch src.imageOrientation {
            case .left, .leftMirrored:
                ctx.cgContext.translateBy(x: 0, y: canvasSize.height)
                ctx.cgContext.rotate(by: -.pi / 2)
                
            case .right, .rightMirrored:
                ctx.cgContext.translateBy(x: canvasSize.width, y: 0)
                ctx.cgContext.rotate(by: .pi / 2)
                
            case .down, .downMirrored:
                ctx.cgContext.translateBy(x: canvasSize.width, y: canvasSize.height)
                ctx.cgContext.rotate(by: .pi)
                
            default:
                break
            }
            
            src.draw(in: CGRect(origin: .zero, size: src.size))
        }
    }
    
    /// 非同期で背景削除処理を実行
    func removeBackgroundAsync() {
        guard !isProcessing else { return }
        guard !imageData.hasProcessedImage else { return } // すでに処理済みなら実行しない
        
        isProcessing = true
        
        Task {
            // 1. オリジナルを.upに正規化
            let upImage = normalizedUpImage(from: self.imageData.originalImage)
            
            // 2. 背景削除 & マスク生成
            let (processed, mask) = await BackgroundRemoval.removeBackground(from: upImage)
            
            // UI更新はメインスレッドで
            await MainActor.run {
                isProcessing = false
                updateProcessedImage(processed, mask: mask)
            }
        }
    }
    
    // displayImage プロパティも不要になったため削除可能
    
    /// 処理済み画像があるかどうか
    var hasProcessedImage: Bool {
        return imageData.hasProcessedImage
    }
} 