import SwiftUI
import Combine

/// 画像データを管理するViewModel
class ImageViewModel: ObservableObject {
    @Published var imageData: ImageData
    @Published var isProcessing = false
    @Published var showOriginal = false
    
    /// 初期化
    /// - Parameter imageData: 画像データ
    init(imageData: ImageData) {
        self.imageData = imageData
    }
    
    /// 処理済み画像を更新
    /// - Parameters:
    ///   - image: 処理済み画像
    ///   - mask: シルエットマスク画像
    func updateProcessedImage(_ image: UIImage, mask: CGImage? = nil) {
        imageData.processedImage = image
        imageData.maskCGImage = mask
        showOriginal = false
        objectWillChange.send()
    }
    
    /// 画像表示を切り替え（元画像と処理済み画像）
    func toggleImageDisplay() {
        if hasProcessedImage {
            withAnimation {
                showOriginal.toggle()
            }
        }
    }
    
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
    
    /// 表示する画像を取得（元画像表示のオーバーライド）
    var displayImage: UIImage {
        return showOriginal ? imageData.originalImage : imageData.displayImage
    }
    
    /// 処理済み画像があるかどうか
    var hasProcessedImage: Bool {
        return imageData.hasProcessedImage
    }
} 